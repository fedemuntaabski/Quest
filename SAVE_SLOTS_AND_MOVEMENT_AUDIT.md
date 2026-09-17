# Save Slots & Movement Audit

Date: 2026-09-17
Branch: `feature/save-slots-and-xcom-movement` (created from `refactor/code-audit-cleanup`, clean tree)

---

## 1. Branch confirmation

```
git checkout -b feature/save-slots-and-xcom-movement
```
Confirmed created and checked out before any code changes in this pass.

---

## 2. Save-slot audit + fixes applied

### 2.1 Data schema (before this pass)

`scripts/managers/SaveManager.gd` persists to `user://slot_<id>.cfg` (`ConfigFile`, section `save_data`):

| Field | Type | Notes |
|---|---|---|
| `base_hp`, `base_str`, `base_mag`, `base_dex` | int | Player base stats |
| `active_upgrades` | Array | Active upgrade IDs |
| `first_time_player` | bool | Onboarding flag |
| `gold` | int | Currency, mirrored from `CurrencyManager` |
| `run_cycle` (+ legacy `contracts_completed` alias) | int | Run/contract counter, not a dungeon floor |
| `post_victory_popup_pending` | bool | UI state flag |

Not present before this pass: date/time saved, playtime, dungeon floor/level reached, host/multiplayer mode. Confirmed via full-repo grep — no such fields existed anywhere in the save schema.

### 2.2 Schema extension applied

Added two new persisted fields to `scripts/managers/SaveManager.gd`:

- `saved_at_unix: int` — written every `save_game()` via `Time.get_unix_time_from_system()`.
- `playtime_seconds: float` — accumulated across the session using `Time.get_ticks_msec()` deltas, persisted every save.

Changes:
- New member vars `playtime_seconds` and `_session_start_msec` (near existing `gold`/`run_cycle` declarations).
- `_ready()`: initializes `_session_start_msec`.
- `save_game()`: accumulates elapsed time into `playtime_seconds`, resets the session baseline, writes both new keys to the `.cfg`.
- `load_game()` success branch: reads `playtime_seconds` with a `0.0` default (backward-compatible with old saves lacking the key), resets session baseline.
- `load_game()` fresh/failure branch: resets `playtime_seconds` to `0.0`.

Old save files without these keys read back as `0` / `0.0` — the UI layer treats that as "unknown" rather than displaying a raw zero (see 2.3).

### 2.3 UI fixes applied — `scripts/ui/menus/SaveSlotSelector.gd`

- **Thousands separator**: added `_format_thousands(n: int) -> String` (dot-separated, e.g. `1.500`), applied to the gold figure in the hover summary. Matches the Spanish-language UI convention.
- **New display fields**: hover summary (`_get_slot_summary`) now reads `saved_at_unix` and `playtime_seconds` from the slot's `.cfg` and renders them as:
  - `• Guardado: dd/mm/yyyy HH:MM` (via `Time.get_datetime_dict_from_unix_time`), or `Desconocida` if `saved_at_unix == 0` (old saves).
  - `• Tiempo jugado: Xh YYm`, or `Desconocido` if `playtime_seconds == 0` (old saves).
- **Corrupt-save message**: replaced the generic `"No se pudieron leer los datos de guardado."` with a slot-numbered, still non-technical message (`"No se pudo leer la ranura %d. El archivo de guardado podria estar danado."`), and now logs the real `Error` code via `QuestLogger.error` for diagnosis without exposing it to the player.
- **Empty-slot placeholder**: left untouched — `EMPTY_SLOT_TEXT` was already correct and returned early before any `ConfigFile` access; verified it still short-circuits ahead of the new fields.
- **Button labels** (`refresh()`): left untouched — out of scope, not reported as broken.

### 2.4 Scene fix applied — `scenes/SlotSelection.tscn`

The entire slot-detail summary is rendered through a single `HoverLabel` (autowrap, 350px min width) inside a `RightPanel` `PanelContainer` (400×480), with no overflow guard. Adding two new lines (date, playtime) pushes the block from ~7 to ~9 lines. Fix applied:
- `RightPanel.clip_contents = true` — clips any overflow at the panel edge instead of letting it visually spill outside the card.
- `RightPanel.size_flags_vertical` changed from `4` (SHRINK_CENTER) to `3` (FILL) — panel now fills the full card height instead of centering, giving the top-anchored label more vertical room and making any residual overflow clip predictably at the bottom rather than spilling from a centered block in both directions.

No structural change to a multi-label layout was made (kept in scope per the minimal-safe UI decision) — the single-label + clip approach is sufficient for the two fields added.

---

## 3. ToME vs XCOM movement — technical analysis (no code changes)

This section is analysis/proposal only. **No files under `scripts/core/movement/`, `scripts/core/actions/`, or `scripts/world/rooms/` were modified in this pass.**

### 3.1 Current model (ToME-style, confirmed in code)

- `scripts/core/actions/MoveAction.gd`: `consume_turn = true` unconditionally in `_init` — every move is a full, binary-cost turn. `execute()` derives at most **one** step even when a multi-cell path is available (`next_cell = path[1] if path.size() > 1 else path[0]`) — it never executes a whole path atomically.
- `scripts/core/actions/TurnManager.gd`: flat `actors` array, round-robin by registration order — no initiative/speed sort. `_on_action_finished()` ends the actor's turn purely based on `action.consume_turn` being true; there is no partial-cost/AP concept anywhere.
- `scripts/core/actions/ActionQueue.gd`: pure serial FIFO (`queue_action` → `process_next` recursion), tracks `OccupancyManager` version snapshots only for stale-state detection, not for AP accounting.
- Click-to-move trace: `PlayerActionController._handle_mouse_click` (explicitly commented `"MOUSE CLICK → 1 STEP (ToME style)"`) → `PlayerMovement.request_path_to_cell()` computes a full A* path via `MapNavigationHelper.find_path` and stores it in `current_path` → a per-frame loop pops **one** cell at a time and calls `request_move(dir)` → `PlayerMovementTurnBridge.request_move()` builds a **new single-cell** `MoveAction` (`use_pathfinding = false`) and queues it. So a multi-cell click move today is N sequential, independently turn-consuming actions — not one atomic move.
- Keyboard move: direct single-cell bump via `request_move(dir)`, same underlying action.
- No `AStar2D`/`AStarGrid2D` engine node is used anywhere; pathfinding is a hand-rolled 4-directional, uniform-cost A* in `MapNavigationHelper.find_path()`, wrapped by a `find_path_preferred(mode="auto")` stub already anticipating a future backend swap.
- No AP/energy field exists anywhere in the codebase today (confirmed via grep across `BaseAction`, `MoveAction`, `TurnManager`, `CharacterStats`).

### 3.2 Proposed XCOM-style architecture

**Action Points (AP):**
- Add an `ap` / `action_points` resource to actor turn-state (new — nothing today tracks per-turn "budget"). Suggested baseline: 2 AP/turn (e.g. "move" costs 1 AP per N cells or scales with path length, "attack"/card play costs 1 AP), matching common XCOM-style budgets ("Move + Attack" or "Move + Move").
- Rework `TurnManager`'s end-turn condition (currently: "any `consume_turn` action ends the turn") to: "AP pool reaches 0, or actor voluntarily ends turn." This changes `_on_action_finished()` from a binary check to an AP-deduction step.
- Rework `MoveAction.execute()` to consume the **entire** computed path atomically in one action (paying `path.size()` AP, or a capped/affordable prefix of the path if AP is insufficient) instead of taking one step per queued action. This is the key structural change — today's "N single-step actions" model would become "one path-consuming action that pays proportional AP."

**Movement range & path preview:**
- A path preview **already exists**: `TileHighlighter._update_path_preview()` draws dots + an arrow along the hovered A* path, reusing the same `find_path` used for movement. This can be reused as-is for the XCOM path-preview requirement.
- A range overlay **already exists but is card-scoped**: `TileHighlighterCache.update_range_cache()` computes a Chebyshev-radius candidate set filtered by `find_path` walked-distance (`path.size() - 1 > card.range` excludes cells), currently driven only by `CardData.range` for "dash"-type cards.
- Proposal: generalize `update_range_cache()` to accept an **AP budget** as an alternative/additional input to `card.range`, so the same radius-loop-plus-distance-filter approach renders a reachable-cell (blue/yellow) overlay for the player's remaining movement AP, using the exact same rendering path already used for cards.
- **Gap to flag**: there is no flood-fill/Dijkstra/BFS reachable-set API anywhere in `MapManagerCore`/`OccupancyManager` today. The nearest equivalent is calling `find_path` once per candidate cell in a radius loop — functionally correct but O(cells × A*), which is fine at small AP budgets (2-4 cells) but should be replaced with a proper BFS pass (the existing pathfinding is already 4-directional/uniform-cost, which is ideal for BFS) if AP budgets grow larger or rooms get bigger. Recommend profiling before optimizing — do not preemptively rewrite this.

**Confirmation flow:**
- Proposed flow: hover/select → preview (path + AP cost via the reused `TileHighlighter` overlay) → confirm click executes the atomic multi-cell `MoveAction`. This differs from today's single-click-commits behavior in `PlayerActionController._handle_mouse_click`.
- Exact UX (single click that previews-then-confirms-on-second-click vs. hover-preview + first-click-confirms) is left as an implementation-phase decision — both are compatible with the underlying AP/atomic-move architecture above, and picking one shouldn't require rearchitecting the range/preview or AP systems.

**Multiplayer (Steam/GodotSteam) impact:**
- Confirmed: the entire `scripts/` tree has exactly **one** `@rpc` — `SteamManager.submit_auth_ticket`, used purely for Steam lobby-join authentication. There are zero RPCs, `MultiplayerSynchronizer` nodes, or `is_multiplayer_authority()` checks related to gameplay, movement, or turns. Movement/turn sync for co-op does not exist today and must be designed from scratch, not migrated.
- Proposed model: **host-authoritative**. `TurnManager` and `OccupancyManager` state live and are decided on the host. A client's move/attack request is sent via a new `@rpc("any_peer", ...)` call; the host validates it against `OccupancyManager.get_version()` (the existing optimistic-concurrency version counter already used to detect stale occupancy in `MoveAction`) and against the actor's remaining AP; on success the host executes the move locally and broadcasts the confirmed result (destination cell + new occupancy version + remaining AP) via a `@rpc("authority", "call_local")` to all peers, who apply it directly rather than re-simulating.
- This reuses the existing `occ_version` staleness-detection pattern already present in `MoveAction`/`ActionQueue` instead of inventing a new reconciliation mechanism, and avoids needing per-actor `MultiplayerSynchronizer` nodes (none exist today) — grid-cell movement is discrete, so RPC-broadcasting the resulting cell/AP state is sufficient; continuous position sync is not needed.

### 3.3 Migration plan sketch (not executed in this pass)

1. Add `ap`/`action_points` fields + refill-on-turn-start logic (actor stats layer).
2. Change `MoveAction` to accept/consume a full path and its AP cost; change `TurnManager` end-turn logic to AP-based.
3. Generalize `TileHighlighterCache.update_range_cache()` to take an AP budget parameter.
4. Update `PlayerActionController` click handling for the preview→confirm flow.
5. Only after 1-4 are validated in single-player: design and add the host-authoritative RPC layer for co-op sync, reusing `OccupancyManager.get_version()`.

Each step is independently testable in isolation given the lack of a test suite — recommend manual playtesting after each step rather than attempting the full migration in one pass.

# XCOM Tactical Range UI — Phase 2

**Branch:** `refactor/xcom-range-ui` (from `refactor/ap-turn-engine`)
**Status:** Implemented, not yet manually tested in-editor.

## Goal

Build the tactical UI layer on top of the Phase 1 AP engine
([AP_TURN_ENGINE_REFACTOR.md](AP_TURN_ENGINE_REFACTOR.md)): show the player how far they
can move with their current AP (blue = 1 AP, yellow = dash / 2 AP, computed by BFS
respecting walls/occupancy) and replace the old "click = instant move" flow with an
XCOM-style select → confirm flow, cancelable with right-click.

Before this phase, a single left-click moved the player immediately
(`PlayerActionController._handle_mouse_click` → `PlayerMovement.request_path_to_cell` →
`MoveAction` queued and executed on the spot). No BFS/flood-fill existed anywhere in the
project — only single-target A* (`MapNavigationHelper.find_path`) and a Chebyshev-square
range approximation for card targeting (`CardTargeting.get_range_cells`, no wall check
for enemy-target cards).

## Design decisions (confirmed with user mid-session)

- Clicking a different cell while one is staged **cancels the old stage and re-stages
  the new cell in the same click** (no third click needed).
- While a destination is staged, hovering other cells **does not** recompute the path
  preview — the staged path stays fixed/bold until confirmed or canceled.
- The AP-cost label ("-1 AP" / "-2 AP") is drawn via `draw_string` directly in
  `TileHighlighterRenderer` (`ThemeDB.fallback_font`), no new Control node.

## Key architectural findings that drove the design

1. **No BFS/flood-fill existed.** Added `MapNavigationHelper.get_reachable_cells()`,
   reusing the exact same neighbor filter (`_get_neighbors`) that `find_path` already
   uses, so walls/occupancy/room-lock behave identically between pathing and range
   calculation.
2. **`MoveAction._compute_ap_cost()` was the only AP-cost formula**, private to that
   file. Extracted to a shared `MovementCostUtil.steps_to_ap()` so the UI label and the
   real AP charge can never drift apart.
3. **`TileHighlighter._draw()` early-returned when nothing was hovered**
   (`if hovered_cell == INVALID_CELL: return`). This would have hidden the blue/yellow
   overlay until the mouse first moved over the grid, contradicting the requirement that
   it appear as soon as the player's turn starts. Split the draw path so the movement
   range overlay renders independently of hover state.
4. **No right-click handling existed anywhere** (`InputHandler` only branched on
   `MOUSE_BUTTON_LEFT`), and `PlayerMovement.cancel_movement()` was already a dead
   no-op stub from Phase 1 (multi-cell moves are atomic — nothing to drain/cancel
   mid-flight). The new "cancel a staged destination" concept is unrelated to that stub
   and was **not** revived from it; staging state lives entirely in
   `PlayerActionController`, a UI-routing concern, not `PlayerMovement`.
5. **State-desync risk found during implementation**: `TileHighlighter` independently
   detects a staged cell going stale (e.g. an enemy stepped into it) and was originally
   going to clear its own visual state directly. That would have left
   `PlayerActionController._staged_destination_cell` — the canonical state a click is
   checked against — out of sync: the overlay would look cleared, but a click on that
   cell would still be read as "confirm" instead of "stage". Fixed by adding
   `PlayerActionController.cancel_staged_move()` (public) and having the highlighter's
   staleness check route through it via the new `"player_action_controller"` group,
   instead of mutating its own state unilaterally.

## Changes by file

### 1. `scripts/core/movement/map_navigation_helper.gd`
Added `get_reachable_cells(start, max_steps, allowed_rect, use_allowed_rect) -> Dictionary`
— BFS flood-fill returning `{cell: step_count}`, built on the same `_get_neighbors()`
used by `find_path`.

### 2. `scripts/world/rooms/MapManagerCore.gd` / `MapManager.gd`
Added `get_reachable_cells_for_actor(actor, max_steps) -> Dictionary`, mirroring the
existing `find_path` wrapper chain (resolves the actor's room-lock rect, delegates to
the nav helper).

### 3. `scripts/core/actions/MovementCostUtil.gd` (new)
`static func steps_to_ap(steps, range_per_ap) -> int` — the `ceil(steps/range_per_ap)`
formula, extracted so it has exactly one implementation.

### 4. `scripts/core/actions/MoveAction.gd`
`_compute_ap_cost()` now delegates to `MovementCostUtil.steps_to_ap()`. Pure refactor,
behavior unchanged.

### 5. `scripts/world/rooms/MovementRangeCalculator.gd` (new)
`static func compute_move_buckets(map_manager, actor) -> Dictionary` — runs the BFS out
to `current_ap * move_range_per_ap` steps, then buckets each reachable cell into
`"blue"` (≤1 AP) or `"yellow"` (2 AP, only if `current_ap >= 2`). Capping the BFS at the
actor's actual AP budget already guarantees yellow can't appear with only 1 AP; the
`current_ap >= 2` check documents that invariant explicitly.

### 6. `scripts/core/theme/QuestPalette.gd` / `ThemeManager.gd`
Added `TACTICAL_MOVE_NEAR` (blue) / `TACTICAL_MOVE_DASH` (yellow) constants and
`tactical_move_near_fill_color()` / `_border_color()` / `tactical_move_dash_*()`
accessors, following the existing `tactical_*` pattern.

### 7. `scripts/world/rooms/TileHighlighter.gd`
- New cached state: `_cached_move_blue_cells`, `_cached_move_yellow_cells` (polled via
  `_last_move_ap` / `_last_move_occ_version` / `_last_move_grid_pos`, same style as the
  existing `_last_player_grid_pos` poll — no new signals added).
- New staged-destination state: `_staged_cell`, `_staged_path`,
  `set_staged_destination()`, `clear_staged_destination()`, `_active_preview_path()`.
- `_update_path_preview()` now early-returns while a cell is staged (freezes hover
  preview per the confirmed design decision).
- `_draw()` no longer gates on `hovered_cell` — computes the active path (staged or
  hovered) and AP cost/affordability every call, passes everything to the renderer.
- `_update_move_range_cache_if_needed()`: gates the whole overlay on
  `is_turn_active() and no active card`; recomputes buckets on AP/occupancy/position
  change; detects a staged cell going stale and cancels it through
  `PlayerActionController.cancel_staged_move()` (see finding #5).
- `_on_game_state_changed()` now also clears staged destination and both move-range
  caches when leaving `ACTIVE`.

### 8. `scripts/world/rooms/TileHighlighterRenderer.gd`
`draw()` signature extended with `move_blue`, `move_yellow`, `staged_cell`, `ap_cost`,
`ap_affordable`. Added `_draw_move_range_preview()` (filled+bordered rects per cell,
distinct from the card-targeting ring style), `_draw_staged_destination()` (persistent
gold outline, no pulse — distinct from the transient hover ring), and
`_draw_ap_cost_label()` (`draw_string` via `ThemeDB.fallback_font`, anchored above the
staged/hovered cell, colored `UI_TEXT_BLOCKED` when unaffordable).

### 9. `scripts/core/movement/PlayerActionController.gd`
- New state: `_staged_destination_cell` (`NO_STAGED_CELL` sentinel), `_staged_path`.
- `_handle_mouse_click()` rewritten for the plain-move branch: click on the already
  staged cell → confirm (`request_path_to_cell` + clear stage); click elsewhere valid →
  (re)stage; click on unwalkable/unreachable cell → clear stage.
- Defensive `_clear_staged_move()` calls added at the top of the active-card branch, the
  enemy-attack branch, the self-click branch (before the existing `cancel_movement()`
  no-op), inside `_clear_card_targeting_state()`, in `_select_card()`, and in
  `on_player_turn_started()` — so a leftover stage can never be misread as a confirm
  after the player does something else.
- New `_handle_mouse_right_click()` — cancels a staged move if one exists; does nothing
  otherwise. Does not touch `ui_cancel`/Escape (still pause-menu only).
- New public `cancel_staged_move()` — lets `TileHighlighter` cancel the canonical staged
  state when its own staleness check fires (finding #5).
- `setup()` now joins a new `"player_action_controller"` group so the highlighter can
  find it without a direct reference.

### 10. `scripts/core/movement/InputHandler.gd`
Added a `MOUSE_BUTTON_RIGHT` branch next to the existing left-click one, routing to
`parent_ctrl._handle_mouse_right_click()`. No prior right-click handling existed
anywhere, so this is purely additive.

## Verification performed

- Read every touched file's post-edit diagnostics (Godot's live GDScript analyzer) after
  each change; all errors were expected "not found yet" states from partially-applied
  edits and cleared once the corresponding method was added — no diagnostics remain.
- Confirmed no naming collisions: `MovementCostUtil`/`MovementRangeCalculator` class
  names are unique project-wide; `"player_action_controller"` group name unused before
  this change.
- Traced the full click state machine by hand across all branches (card self/enemy
  target, basic attack, self-click, plain move) to confirm `_clear_staged_move()` is
  reachable from every path that must not leave a stale stage behind.
- Confirmed `MoveAction.can_execute()`'s existing `stale_snapshot`/`path_blocked`/
  `insufficient_ap` checks remain the authoritative correctness backstop regardless of
  what the overlay shows — the staleness auto-cancel in `TileHighlighter` is UX-only.

## Not yet done

- No in-editor manual test run (`godot --path .`). Full 17-point checklist is in the
  approved plan file; key ones to prioritize:
  1. Blue/yellow overlay appears at turn start without needing to hover first (validates
     the `_draw()` guard fix).
  2. First click stages (no movement yet) + AP label; second click on the same cell
     confirms and AP drops by the expected amount.
  3. Right-click cancels a staged move with no side effects.
  4. Overlay hidden while a card is active or during enemy turns.
  5. Staging survives correctly across the enemy-attack / card-activate / pause
     interrupt paths (i.e. never leaves a ghost stage that hijacks a later click).

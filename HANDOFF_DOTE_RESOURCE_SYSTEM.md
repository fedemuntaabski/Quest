# Handoff: DotE-style resource/turn system refactor

**Repo:** QUEST (Godot 4.6, GDScript only, GL Compatibility renderer)
**Branch:** `feature/dote-resource-system` (created from `feature/tactical-grid-ap-controller`, currently uncommitted — all changes below are working-tree changes, not yet committed)
**Status:** Code-complete for the 4 planned phases, one bug found and fixed post-implementation (see "Known issue fixed" below). **Not yet manually verified in the Godot editor** — no Godot binary was available in the environment that did the implementation, so the checklist in "Verification — not yet done" still needs to be run by a human/agent with editor access.

---

## 1. Goal / context

The project is pivoting its combat/movement model away from a classic tactical-RPG AP (Action Points) + STR/MAG/DEX stat system toward a **Dungeon of the Endless (DotE)**-style model:

- No AP, no per-actor turns. Movement inside a revealed room is free (unlimited range).
- The "turn" is global and advances only when a door is opened.
- Progression is driven by 4 resources — **industry, food, science, dust** — instead of combat stats.
- Rooms start hidden (basic fog-of-war); opening a door reveals the next room and ticks resource production.
- Enemy spawning on door-open exists only as a placeholder signal — there is no enemy system in the repo to spawn anything real (see history below).

### Important repo history the implementer had to account for

A prior branch (`refactor/total-gameplay-wipe`) had **already deleted** the game's old card-combat, dungeon-generation, and enemy-AI systems wholesale (not archived — actually gone). So when this task's original spec referenced `RoomManager.gd` / `MapManager.gd` / doors / fog-of-war / dungeon generation as if they existed, investigation confirmed **none of that exists in the repo at all** — it had to be built from scratch as a minimal stub, not "fixed" or "restored."

A separate branch (`feature/tactical-grid-ap-controller`, the parent of this one) had rebuilt movement from scratch as a BFS/AP-costed system (`scripts/core/movement/`, `scripts/core/actions/TurnManager.gd` etc.) — **that** is the AP-era system this refactor removes.

### Scope decisions made with the user before implementation

1. **Fase 3 (doors/turns) = minimal functional stub**, not a full dungeon system. One `DoorTurnSystem.gd` + 2 hand-placed `Door` test nodes in `Main2d.tscn`. Fog-of-war = simple visited/unvisited flag (unrevealed rooms' tiles are just never painted, so they're invisible and non-walkable) — not a full vision/lighting system.
2. **Movement = fully free**, no per-turn range cap. BFS is still used for pathing/reachability against obstacles, just with no step limit.
3. **TurnManager/ActionQueue (per-actor turn sequencing) removed entirely.** DotE has no individual actor turns — the global turn only advances on door-open.
4. **Enemy spawn on door-open = signal/log placeholder only** (`enemy_wave_requested`). No real enemy system exists to consume it (it was deleted in the prior wipe) and building one was explicitly out of scope for this task.

---

## 2. What changed, phase by phase

### Fase 1 — Stats/character selection cleanup

- **`scripts/core/stats/CharacterData.gd`** — removed `base_str`, `base_mag`, `base_dex`, `base_ap`, `move_range_per_ap`. Added `profile_bg: Texture2D` (new, unused by any UI yet — placeholder for future art), `passive_ability_name: String`, `passive_ability_desc: String`, `active_ability_name: String` (deliberately no `active_ability_desc` — matches the literal field list the user asked for).
- **`resources/characters/{warrior,mage,rogue,tank}.tres`** — kept each hero's existing `base_hp` (22/20/20/32), replaced old stat lines with role-flavored ability text:
  - **warrior** — Tanque/Provocador — "Piel de Hierro" (passive) / "Grito de Guerra" (active)
  - **mage** — Especialista en Ciencia/Módulos — "Mente Analítica" / "Sobrecarga de Módulo"
  - **rogue** — Explorador Rápido/Colector de Polvo — "Paso Ligero" / "Golpe Furtivo"
  - **tank** — Defensor de Cristal — "Muro Viviente" / "Interposición"
- **`scripts/core/stats/CharacterStats.gd`** — stripped to HP-only. Removed AP fields/signal/methods (`max_ap`/`current_ap`/`move_range_per_ap`/`ap_changed`/`refill_ap()`/`spend_ap()`/`has_ap()`), removed `strength`/`magic`/`dexterity` + their `ModifierStack`-based total/runtime-modifier machinery.
- **`scripts/core/stats/PlayerStats.gd`** — dropped `base_str/base_mag/base_dex/base_ap/base_move_range_per_ap`; `upgrade_levels` dict now just `{"hp": 0}`.
- **`scripts/core/stats/StatBalance.gd`** — removed dexterity-only dodge/damage-scaling constants and functions (`DEX_DODGE_*`, `get_dexterity_dodge_chance`, `get_scaled_stat_bonus`) — nothing else referenced them.
- **Deleted** `scripts/core/stats/StatTypes.gd` and `scripts/core/stats/ModifierStack.gd` — both were only used by the code just removed, confirmed dead via repo-wide grep before deleting.
- **`scripts/ui/menus/StorePanel.gd`** + **`scenes/StorePanel.tscn`** — the pause-menu stat-upgrade shop now only has an HP upgrade card; the STR/MAG/DEX upgrade cards and their config entries were removed.
- **`scripts/ui/character_select/CharacterCardOption.gd`** + **`scenes/CharacterCardOption.tscn`** (shared by both single-player `CharacterSelection` and multiplayer `WaitingRoom` — confirmed neither reads AP/stat fields directly, so this was safe to change once) — removed the `APBadgeCenter`/`APBadge`/`APLabel` nodes, `StatsLabel` now shows just `"HP %d"`, added a new `AbilityLabel` node showing `passive_ability_name` + `passive_ability_desc`.
- **`scripts/managers/SaveManager.gd`** — `apply_character_selection()`/`save_game()`/`load_game()` no longer read/write the removed stat fields. No save-migration system exists in this project, so old save files simply won't populate fields that no longer exist — not a concern at this prototype stage.
- **`scripts/ui/menus/SaveSlotSelector.gd`** — removed the "Atributo principal" (highest stat) line from the save-slot summary text, since STR/MAG/DEX no longer exist to compare.

### Fase 2 — Free movement, turn-manager removal

- **Deleted** `scripts/core/actions/TurnManager.gd`, `scripts/core/actions/ActionQueue.gd`, `scripts/core/actions/WaitAction.gd` — per-actor turn sequencing no longer exists.
- **`scripts/core/actions/BaseAction.gd`** — removed `consume_turn`, `ap_cost`, `get_execution_state_token()` (that last one existed only for `ActionQueue`'s optimistic checks).
- **`scripts/core/actions/MoveAction.gd`** — no longer takes/spends an AP cost; `_init(owner, path, tilemap)` (3 args, dropped the 4th `ap_cost` param). Still tweens the player cell-by-cell for visual smoothness.
- **`scripts/core/movement/MapNavigationHelper.gd`** — replaced `compute_movement_range(origin, current_ap, move_range_per_ap, is_walkable)` with `compute_reachable_cells(origin, is_walkable)` — plain unlimited BFS flood-fill, no step cap, no blue/yellow AP-cost split. `build_path()` unchanged.
- **`scripts/core/movement/PlayerActionController.gd`** — dropped `ap_label`/`turn_manager` fields and their signal handlers. `setup(player, tilemap, highlight_layer)` (3 args, was 5). Highlight zone is now a single reachable-cell color (`REACHABLE_ATLAS`, tile `(0,0)` of the existing highlight tileset — no new art needed) instead of a blue/yellow split. Input gating (`_can_act()`) now checks `player.can_accept_input()` + `ManagerLocator.get_game_state_manager().is_active()` directly instead of going through `TurnManager`. `_confirm_move()` builds and executes a `MoveAction` directly (no `ActionQueue` to enqueue into anymore). Renamed private `_refresh_zones()` → public `refresh_zones()` so `Main2d`/`DoorTurnSystem` can trigger a re-scan after a room reveal.
- **`scripts/core/player/Player.gd`** — removed `turn_manager` field, `begin_turn()`, `process_turn_end()` (its only job — resetting runtime stat modifiers — no longer applies since those modifiers were removed in Fase 1). `can_accept_input()` is now just `stats != null and stats.is_alive()`.

### Fase 3 — ResourceManager + DoorTurnSystem (new)

- **`scripts/managers/ResourceManager.gd`** (new autoload, registered in `project.godot`) — tracks `industry`/`food`/`science`/`dust` (all `int`, start at 0). `get_resource(key)`, `add_resource(key, delta)` (clamps at 0, emits `resource_changed(key, amount, delta)`), `add_all(industry_d, food_d, science_d, dust_d)`, `reset()`. **No persistence** — resources reset every run; this was an intentional simplification for this stub, not an oversight.
- **`scripts/managers/ManagerLocator.gd`** — added `get_resource_manager() -> ResourceManager`, following the exact pattern of the other typed autoload getters.
- **`scripts/core/utils/Logger.gd`** — added a `DOOR` category to `QuestLogger`'s `Category` enum for door/resource diagnostic logs.
- **`scripts/core/actions/DoorTurnSystem.gd`** (new — a plain `Node`, instantiated once per `Main2d` scene instance, *not* an autoload, the same way `TurnManager` used to be) — tracks `rooms: Dictionary` (`room_id -> {cells, visited}`) and `current_turn: int`. `register_room()`/`register_door()` set it up. `open_room(room_id)` (fired by a door's `door_opened` signal): marks the room visited, increments `current_turn`, emits `turn_advanced`/`room_revealed(room_id, cells)`, calls `ResourceManager.add_all()` with fixed placeholder gains (`industry+2, food+2, science+2, dust+5` per door), and emits `enemy_wave_requested(room_id)` (logged via `QuestLogger`, nothing else listens — this is the explicit "no real enemy system" placeholder).
- **`scripts/world/Door.gd`** (new) + **`scenes/Door.tscn`** (new) — `Door` is a plain `Area2D` with `door_id`/`target_room_id`/`cell` exports. Emits `door_opened(self)` when clicked while the player is orthogonally adjacent to its `cell` (checked via `player.grid_pos`, not tile-based). `mark_opened()` just dims the door's `modulate` — no new art asset, the door is a placeholder brown `Polygon2D` square.
- **`scripts/world/FloorGenerator.gd`** — reworked from "always fill the whole map rectangle in `_ready()`" to on-demand reveal: added `auto_fill_full_map: bool` (default now **false**, was implicitly always-true before), `fill_cells(cells: Array[Vector2i])` (paints just the given cells), `is_cell_filled(cell) -> bool`. This is the actual fog-of-war mechanism — a cell that's never had `fill_cells` called on it stays both invisible and (via `get_cell_source_id() != -1` in `PlayerActionController._is_cell_walkable`) non-walkable.
- **`scripts/managers/Main2d.gd`** — removed `_setup_turn_manager()`/`turn_manager` field/`ap_label`. Added `ROOM_RECTS` (3 hardcoded rooms: `"start"` at x0-4, `"room_b"` at x6-9, `"room_c"` at x11-14, all 15 tall), `door_a`/`door_b` onready refs, `door_turn_system` var. New `_setup_door_turn_system()`: instantiates `DoorTurnSystem`, registers all 3 rooms (only `"start"` pre-visited), fills the start room's floor tiles, positions+registers the 2 doors. `_on_room_revealed(room_id, cells)`: fills the revealed room's cells *and* the triggering door's own cell (so the door tile itself becomes walkable), then calls `player_action_controller.refresh_zones()`.
- **`scenes/Main2d.tscn`** — added `DoorA` (→ `room_b`, cell `(5,7)`) and `DoorB` (→ `room_c`, cell `(10,7)`) as `Door.tscn` instances; removed the old `ApLabel` node.

### Fase 4 — HUD rewrite

- **Deleted** `scripts/ui/hud/TurnButtonController.gd` — the "Pasar Turno" button and its controller no longer exist.
- **`scripts/ui/hud/StatIcon.gd`** — replaced the `strength`/`magic`/`dexterity` icon types (sword/orb/boot vector drawings, now fully dead) with `industry`/`food`/`science`/`dust` (gear/wheat/flask/sparkle vector drawings, same hand-drawn `draw_polygon`/`draw_circle` style as the existing HP heart icon — no image assets, no emoji, since emoji glyph rendering isn't guaranteed under Godot's GL Compatibility renderer/default font).
- **`scripts/ui/hud/StatPanelUI.gd`** — removed `label_ap`/`AP_FORMAT`/`update_ap()`; added `update_resource(key, amount)` and 4 new label refs (industry/food/science/dust), formatted as `"Industria %d"` etc.
- **`scripts/ui/hud/HUDController.gd`** — removed all AP/turn-button wiring; now also binds `ResourceManager.resource_changed` on `_ready()` (with an initial sync pass over all 4 keys) and forwards to `stat_panel.update_resource()`.
- **`scenes/HUD.tscn`** — removed `StatRowAP` (label + End Turn button); added `StatRowIndustry`/`StatRowFood`/`StatRowScience`/`StatRowDust`, each an icon+label row matching the existing `StatRowHP` pattern. Bumped the `StatsHUD` panel's `offset_bottom` (200→300) to fit the extra rows.

### Documentation

- **`CLAUDE.md`** — updated throughout (project overview, autoload list, architecture section, directory layout, "when picking up gameplay work here") to describe the new DotE model instead of the AP/TurnManager model, and to document that `TurnManager.gd`/`ActionQueue.gd`/`WaitAction.gd`/`TurnButtonController.gd`/`ModifierStack.gd`/`StatTypes.gd` no longer exist (mirroring how the doc already documented the earlier `refactor/total-gameplay-wipe`).

---

## 3. Known issue found and fixed after implementation

After the code above was written, the user ran the project and hit:

```
Parser Error: Could not parse singleton "ResourceManager" from "res://scripts/managers/ResourceManager.gd".
```

Root cause: the on-disk copy of `scripts/managers/ResourceManager.gd` had `var next : max(0, current + delta)` in `add_resource()` — a missing `=` after the `:` (should be `:=`), which is a hard GDScript syntax error that prevented the autoload singleton from parsing at all. (This line differed from what was originally written by the implementing agent — something modified the file on disk between the original write and the user's test run; the exact cause wasn't identified, just the resulting corruption.)

**Fix applied:** changed the two type-inferred locals in `add_resource()` to explicit types and used the int-specific `maxi()` builtin instead of the untyped/variant-returning `max()`:

```gdscript
func add_resource(key: String, delta: int) -> void:
	var current: int = get_resource(key)
	var next: int = maxi(0, current + delta)
	...
```

**If anything still fails to parse after this fix:** re-check `scripts/managers/ResourceManager.gd` byte-for-byte against the version in this doc's Fase 3 section — there may be another instance of on-disk drift from an external cause (editor auto-format, a stray save, etc.), not a logic bug in the design.

---

## 4. Full file change list (working tree, uncommitted)

```
Modified:
  CLAUDE.md
  project.godot
  resources/characters/{mage,rogue,tank,warrior}.tres
  scenes/CharacterCardOption.tscn
  scenes/HUD.tscn
  scenes/Main2d.tscn
  scenes/StorePanel.tscn
  scripts/core/actions/BaseAction.gd
  scripts/core/actions/MoveAction.gd
  scripts/core/movement/MapNavigationHelper.gd
  scripts/core/movement/PlayerActionController.gd
  scripts/core/player/Player.gd
  scripts/core/stats/CharacterData.gd
  scripts/core/stats/CharacterStats.gd
  scripts/core/stats/PlayerStats.gd
  scripts/core/stats/StatBalance.gd
  scripts/core/utils/Logger.gd
  scripts/managers/GameStateManager.gd   (comment only)
  scripts/managers/Main2d.gd
  scripts/managers/ManagerLocator.gd
  scripts/managers/SaveManager.gd
  scripts/ui/character_select/CharacterCardOption.gd
  scripts/ui/hud/HUDController.gd
  scripts/ui/hud/StatIcon.gd
  scripts/ui/hud/StatPanelUI.gd
  scripts/ui/menus/SaveSlotSelector.gd
  scripts/ui/menus/StorePanel.gd
  scripts/world/FloorGenerator.gd

Deleted:
  scripts/core/actions/ActionQueue.gd (+ .uid)
  scripts/core/actions/TurnManager.gd (+ .uid)
  scripts/core/actions/WaitAction.gd (+ .uid)
  scripts/core/stats/ModifierStack.gd (+ .uid)
  scripts/core/stats/StatTypes.gd (+ .uid)
  scripts/ui/hud/TurnButtonController.gd (+ .uid)

New:
  scenes/Door.tscn
  scripts/core/actions/DoorTurnSystem.gd (+ .uid)
  scripts/managers/ResourceManager.gd (+ .uid)
  scripts/world/Door.gd (+ .uid)

Unrelated (pre-existing, not touched by this work):
  resources/tileset/highlight_tileset.tres, placeholder_tileset.tres
    — these showed as modified (UID metadata only) before this
    session started; left as-is.
```

---

## 5. Verification — not yet done

The implementing agent had **no Godot binary available** in its environment, so none of this was run in the actual editor/game. A human or an agent with editor access still needs to:

1. **Character select:** run the project (`godot --path .`, F5 via `Main.tscn`) → New Game → Slot → Character Selection. Confirm all 4 cards show only HP + passive ability text, no STR/MAG/DEX/AP. Repeat via multiplayer Waiting Room (Host a lobby) since the card scene is shared.
2. **No parse/runtime errors:** with the Output/Debugger panel open, run through into `Main2d.tscn`. Confirm no errors referencing any of the deleted identifiers (`TurnManager`, `ActionQueue`, `WaitAction`, `has_ap`, `spend_ap`, `refill_ap`, `ap_changed`, `current_ap`, `strength`, `magic`, `dexterity`, `consume_turn`).
3. **HUD + door flow:** confirm the HUD shows HP + 4 resource counters starting at/near 0. Move the player freely within the starting room (and confirm you *can't* walk into `room_b`/`room_c` before their door is opened). Click `DoorA` while adjacent to it (cell `(4,7)` is the closest start-room tile) — confirm `room_b` reveals, the door tile becomes walkable, all 4 resource counters go up, an `enemy_wave_requested` log line appears, and `DoorTurnSystem.current_turn` becomes 1. Repeat with `DoorB`/`room_c` (turn → 2).
4. **Store screen:** open the pause-menu store and confirm only the HP upgrade card shows (no broken/leftover STR/MAG/DEX cards).
5. Re-check `scripts/managers/ResourceManager.gd` parses cleanly given the on-disk-drift issue described in section 3.

---

## 6. Explicitly out of scope / not implemented

- **No real enemy system.** `enemy_wave_requested` is a log-only signal. Building an `EnemyManager`/enemy scenes/AI was out of scope.
- **No real dungeon/room generation.** `ROOM_RECTS` in `Main2d.gd` is 3 hardcoded rectangles for demonstrating the door/reveal flow, not a generator.
- **No resource persistence.** `ResourceManager` resets every run; it's not wired into `SaveManager`.
- **Passive/active ability text is data-only.** `CharacterData.passive_ability_name/desc/active_ability_name` are displayed on the character-select card but have no gameplay hook — there's no ability-activation system to consume `active_ability_name`.
- **Fog-of-war is binary**, not a lighting/vision system — a room's tiles are either fully painted (visited) or fully absent (unvisited). The user's original spec mentioned Dust-gated "lighting" a room; that nuance (dust cost to light vs. free reveal) was not implemented — currently every door-open both reveals *and* grants dust, with no spend step.

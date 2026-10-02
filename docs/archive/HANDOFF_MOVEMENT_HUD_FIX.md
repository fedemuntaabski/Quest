# Handoff: movement freeze fix, room-restricted movement, HUD redesign

Branch: `feature/dote-resource-system`

## 1. Movement freeze after first click

**Root cause** (`scripts/core/movement/PlayerActionController.gd`): the `_action_in_flight` busy flag was only ever reset by `_on_move_completed`, a callback wired to `MoveAction`'s one-shot `completed` signal. `move_action.execute()` was called fire-and-forget (no `await`), so the flag reset depended entirely on that signal round-tripping back into the controller. Any break in that chain left `_action_in_flight` stuck `true` forever, and `_can_act()` then rejected every future click — matching the "moves once, then frozen" symptom.

**Fix**: `_confirm_move()` now `await`s `move_action.execute()` directly and resets the flag + calls `refresh_zones()` immediately after, in the same call stack — no separate signal round-trip needed. Removed the now-unused `move_action.completed.connect(...)` wiring and the dead `_on_move_completed()` method. `MoveAction.gd`/`BaseAction.gd` were left untouched; the `completed` signal is still part of the `BaseAction` contract for any future action.

## 2. Movement restricted to discovered rooms

**Root cause**: `PlayerActionController._is_cell_walkable()` only checked whether a tile was painted on the shared `Floor` TileMapLayer — it had no concept of room boundaries, relying entirely on `FloorGenerator.fill_cells()` never over-painting.

**Fix**: `DoorTurnSystem.gd` gained `get_visited_cells() -> Dictionary`, returning the union of all currently-visited rooms' registered cells. `PlayerActionController.setup()` now takes an optional `DoorTurnSystem` reference (`Main2d._setup_player_action_controller()` passes it through); `refresh_zones()` rebuilds a `_visited_cells` cache from it every time zones are recomputed (i.e. on every move and every room reveal), and `_is_cell_walkable()` now requires both "tile painted" AND "cell belongs to a visited room." Falls back to the old paint-only check if no `DoorTurnSystem` is wired (e.g. isolated testing).

## 3. HUD redesign

`scenes/HUD.tscn` restructured from a top-left vertical name+icon+number list into a bottom-center horizontal bar (`StatBarAnchor` → `StatBarCenter` (CenterContainer) → `StatBarPanel` (renamed from `StatsHUD`) → `StatPanelUI`, now an `HBoxContainer` instead of `VBoxContainer`). Each of the 5 stats (HP, Industria, Comida, Ciencia, Polvo) is now a `Chip*` node with only its `StatIcon` + a bare numeric `Label` (no static name text, no HP progress bar).

`StatPanelUI.gd` format strings simplified to pure numbers (`"%d"` / `"%d/%d"` for HP); `update_hp`/`update_resource` signatures unchanged so `HUDController.gd` call sites needed no changes.

`HUDController.gd` wires `mouse_entered`/`mouse_exited` on each chip to the existing `show_simple_tooltip`/`hide_simple_tooltip` methods (reused as-is, same signatures, same `"hud"` group) with the 5 requested Spanish tooltip strings. `StorePanel.gd`'s existing hover-tooltip calls into HUD are unaffected.

## Files changed

- `scripts/core/movement/PlayerActionController.gd`
- `scripts/core/actions/DoorTurnSystem.gd`
- `scripts/managers/Main2d.gd`
- `scenes/HUD.tscn`
- `scripts/ui/hud/StatPanelUI.gd`
- `scripts/ui/hud/HUDController.gd`

## Verification performed

- All edited `.gd`/`.tscn` files re-read after editing to confirm no leftover stale code paths.
- No automated linter/test suite exists in this repo (per `CLAUDE.md`); recommend opening the project in the Godot editor (`godot --path . --editor`) and checking the Errors panel, then running the game (F5 via `scenes/Main.tscn`) to confirm: move repeatedly across several clicks without freezing, and confirm clicks outside `ROOM_RECTS["start"]` are rejected until a door is opened.

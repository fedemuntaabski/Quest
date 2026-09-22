# Handoff: room-graph movement + HUD tooltip fix

Branch: `feature/dote-resource-system`. This replaces the earlier cell-by-cell BFS movement with room/corridor-graph movement (Dungeon of the Endless style) and fixes the HUD tooltip clipping at the bottom of the screen.

## Why

Old movement was a leftover from the AP-era grid game: hover-preview/click-to-select/click-again-to-confirm over a BFS-reachable set of individual cells, painted via a `Highlight` TileMapLayer. The request was to move to DotE-style navigation: click a revealed room or corridor connected to the hero's current one and glide straight there; click an unrevealed adjacent zone or its closed door to open it (tick `DoorTurnSystem`/`ResourceManager`) and auto-walk in.

**Bug found during investigation, not optional to fix:** `PlayerActionController._unhandled_input` called `get_viewport().set_input_as_handled()` on every left click. In Godot 4, `_unhandled_input` runs *before* Area2D physics-picking, so this silently swallowed every click before `Door._on_input_event` could ever fire — the old doors were effectively unclickable. The new design routes all gameplay input through `Area2D.input_event` signals only, never raw `_unhandled_input`/`_input` polling.

## What changed

**New files**
- `scripts/world/RoomZone.gd` + `scenes/RoomZone.tscn` — clickable/hoverable `Area2D` for one room or corridor. Renders its own hover/selection feedback (`Polygon2D` fill + `Line2D` outline, states NONE/CURRENT/REACHABLE/OPENABLE/BLOCKED). Replaces the old painted-tile `Highlight` overlay.
- `scripts/world/RoomManager.gd` — owns the room/corridor graph: geometry (rects/cells/world centers), adjacency (`neighbors`), and the `RoomZone` nodes. `find_zone_path()` is a BFS restricted to revealed zones — the connectivity gate for direct-click movement. Reveal/visited state is **not** duplicated here; `is_zone_revealed()` delegates to `DoorTurnSystem.is_room_visited()`.

**Rewritten**
- `scripts/core/movement/PlayerActionController.gd` — fully signal-driven (`RoomZone.clicked/hovered/unhovered`, `Door.door_clicked`), no more `_unhandled_input`/BFS/two-click confirmation.
- `scripts/core/actions/MoveAction.gd` — tweens the `Player` through an `Array[Vector2]` of world-space waypoints (room/corridor centers) with a single continuous `Tween`, not per-cell steps.
- `scripts/world/Door.gd` — dropped its own Manhattan-adjacency check (the thing that never actually fired, see bug above); access validation now lives in `PlayerActionController` (`door.from_zone_id == player.current_zone_id`).

**Modified**
- `scripts/core/actions/DoorTurnSystem.gd` — dropped `get_visited_cells()`/`register_door()`/`_on_door_opened()` (no longer needed, doors route through the controller); added `is_room_visited()`/`get_room_cells()`.
- `scripts/core/player/Player.gd` — added `current_zone_id` (authoritative position) + `set_zone()`; `grid_pos` demoted to a derived/debug value.
- `scripts/managers/Main2d.gd` — new `LAYOUT` const: 9 zones (5 rooms + 4 corridors) grouped into 5 `DoorTurnSystem` reveal groups, 4 doors under a `Doors` container. Builds `RoomManager` from it in `_ready()`.
- `scenes/Main2d.tscn` — removed the `Highlight` TileMapLayer + its tileset ext_resource; added the `RoomManager` node and 4 `Door.tscn` instances.
- `scripts/managers/ManagerLocator.gd` — added `get_room_manager()` (group-lookup pattern, mirrors `get_game_state_manager()`).
- `scripts/ui/hud/HUDController.gd` + `scenes/HUD.tscn` — `StatTooltip` now grows upward off the bottom stat bar (`grow_vertical = GROW_DIRECTION_BEGIN`) with viewport clamping on both axes; `show_simple_tooltip()` gained a `grow_up` param (defaults `false`) so `StorePanel.gd`'s existing mid-screen tooltip call is unaffected.

**Deleted**
- `scripts/core/movement/MapNavigationHelper.gd` (+ `.uid`) — the BFS flood-fill, no longer used.

## Bugs found and fixed after the initial implementation

Godot's typed-array (`Array[T]`) runtime checks turned out stricter than assumed — a plain `Array` (e.g. read from a `Dictionary.get()` default, or a literal `[...]` passed directly as a call argument) is **not** auto-converted to `Array[T]` except when it's the literal initializer of a `var x: Array[T] = [...]` declaration. Two runtime errors surfaced from this and were fixed by rebuilding the array through `.assign()` (or a typed local var) before handing it to a strictly-typed consumer:
- `RoomManager.gd`: `build_from_layout()`'s read of `groups_def[group_id]["zones"]`, `get_cells()`, `get_group_zone_ids()`.
- `DoorTurnSystem.gd`: `get_room_cells()`, and `open_room()`'s read of `room["cells"]`.
- `Main2d.gd`: `floor_layer.fill_cells([door.cell])` — a literal passed straight into a call argument — rebuilt as a typed local first.

## Verification

Not run in this session — no `godot` binary available in the environment. Manual verification still needed, via `scenes/Main.tscn` (F5, never F6 on `Main2d.tscn`):
1. Room-to-room click movement (same-zone no-op, connected-zone glide, disconnected-zone red `BLOCKED` flash + log, multi-hop through revealed zones).
2. Door open → turn tick → resource gain → floor paint → auto-walk-in, both by clicking the door and by clicking the unrevealed zone directly; re-clicking an opened door is a no-op.
3. Clicks ignored while a move is in flight, while paused, or after death.
4. HUD tooltip: hover each stat chip at 1920x1080 / 1280x720 / a small windowed resolution — never clipped, horizontally clamped. Regression: Pause → Tienda → hover an upgrade card, tooltip still grows right/down like before.
5. Editor Errors/Warnings panel clean of stale `MapNavigationHelper`/`$Highlight`/old `Door.door_opened` references.

Full design rationale and the static test-map layout table (zone rects/centers/connections/door cells) are in the plan this session produced; see conversation history if needed — not duplicated here.

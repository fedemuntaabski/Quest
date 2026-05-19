# Map And Room System

## Purpose
The map system owns dungeon generation, room metadata, active room tracking, grid conversion, walkability, occupancy, and room adjacency.

## Room Generation And Storage
`DungeonLayoutGenerator.generate()` is the room factory.

It:
- retries layout generation until it gets the expected room count
- chooses random room sizes and positions
- rejects overlaps using padded rectangles
- registers floor cells and room metadata
- writes each room into `DungeonGenerator.room_infos`
- adds room records to `DungeonGraph`
- connects rooms with corridors
- validates graph connectivity before success

`DungeonGenerator.room_infos` is the main runtime room store. Each room record contains at least:
- `id`
- `rect`
- `center_cell`
- `floor_cells`
- `visited`
- references for visual/runtime nodes when present

`DungeonGenerator.active_room_id` is the current active room index.

## MapManagerCore Responsibilities
`MapManagerCore` is the helper layer used by `MapManager` for runtime queries.

It handles:
- world/grid conversion wrappers
- walkability checks
- room lookup for a cell
- actor room repair
- engagement checks between source and target actors
- occupancy passthroughs

This class is important because it is the place where runtime lookups are softened when state is incomplete.

## Occupancy And Grid Ownership
`OccupancyManager` stores:
- `_cell_to_actor`
- `_actor_to_cell`
- `_blocking_actors`

Important behavior:
- A cell can hold one actor or an array of actors if multi-occupancy is enabled.
- `is_cell_blocked()` respects blocking flags and requester identity.
- `register_actor()` and `update_actor_cell()` both emit `occupancy_changed`.

`MapManager` delegates all runtime occupancy updates to this manager, and combat reads from it when grid positions are missing.

## Room Activation Flow
There are two overlapping room activation paths:
1. `RoomSystem._on_body_entered()` reacts to player collision with a room detector.
2. `RoomSystem.update_player_cell()` reacts to the player grid position.

`RoomSystem._set_active_room()` updates both `RoomSystem.active_room_id` and `DungeonGenerator.active_room_id`, then emits `room_changed`.

`DungeonRoomManager.set_active_room()` also updates room visibility and light state, then emits `DungeonGenerator.room_changed`.

That means room activation is distributed across both `RoomSystem` and `DungeonRoomManager`.

## Failure Cases

### Room ID `-1`
This is the unresolved room sentinel.

It can appear when:
- a cell does not fall inside any room rectangle
- actor room repair fails
- the player is between rooms or in an unrecognized corridor state

Observed behavior:
- `MapManagerCore.get_actor_room_id()` may return `-1` and then attempt repair from actor position.
- For the player, it may fall back to `DungeonGenerator.active_room_id` during active gameplay.
- `MapManagerCore.can_actors_engage()` may block engagement if either actor still resolves to `-1`.

### Desync Scenarios
1. `OccupancyManager` knows an actor cell, but the actor’s `grid_pos` field is stale.
2. `DungeonGenerator.active_room_id` and `RoomSystem.active_room_id` diverge.
3. Actor room ID is repaired from a grid cell, but the actor is already outside the room rectangle.
4. A player is considered in the active room because of fallback logic, while the cell is actually unresolved.

### Lookup Fragility
1. `get_room_info(room_id)` assumes the room ID is a direct array index.
2. `get_room_id_for_cell()` scans all rooms linearly.
3. Room adjacency checks depend on `DungeonGraph` having been built successfully.

## Deterministic Redesign Improvements
1. Make room identity explicit and stable. Use the generated `room_infos[id]` as the only authoritative room record and avoid reconstructing room ownership from multiple sources.
2. Make `RoomSystem` the sole active-room writer and have `DungeonRoomManager` read from it rather than also mutating the same state.
3. Replace room repair heuristics with a canonical actor-to-room assignment at movement completion time.
4. Make corridor membership explicit in the graph instead of inferring it only from floor-cell geometry.
5. Expose a single room-state snapshot object for combat and UI consumers so they do not need to query `DungeonGenerator`, `RoomSystem`, and `MapManagerCore` separately.

## Needs Verification In Code
- Whether corridor cells are ever intentionally treated as belonging to a room for engagement purposes.
- Whether any other systems still write `active_room_id` directly besides the room managers and dungeon generator.

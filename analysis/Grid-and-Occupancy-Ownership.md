# Grid and Occupancy Ownership

Status: draft — ownership, APIs and call graphs extracted from static analysis (May 23, 2026).

Purpose
- Precisely document which modules own grid data, who mutates it, who reads it, and the canonical APIs used by gameplay systems for walkability, pathfinding and occupancy.

Primary owners and responsibilities

- `DungeonGenerator.gd` — authoritative grid model
  - Stores: `floor_cells`, `wall_cells`, `grid_width`, `grid_height`, `tile_size`, `grid_origin`, `room_infos`.
  - API: `world_to_grid_coords(world_pos: Vector2) -> Vector2i`, `grid_to_world_coords(grid_pos: Vector2i) -> Vector2`, `is_cell_walkable(grid_pos: Vector2i) -> bool`.
  - Mutations: layout writes (via `DungeonLayoutGenerator`) and wall manager updates.

- `DungeonLayoutGenerator.gd` — layout mutator
  - Writes: directly adds room floor cells and corridor cells to `dungeon.floor_cells` and appends room entries in `dungeon.room_infos`.
  - Key methods: `generate() -> bool`, `_register_room(room_rect: Rect2i)`, `_carve_corridor(from_cell, to_cell)`.

- `DungeonWallManager.gd` — wall derivation and node spawner
  - Derives `wall_cells` from `floor_cells` (4-neighbour test).
  - Spawns physics walls / occluder nodes and exposes `set_wall_at_world()` and `clear_cell_at_world()`.

- `MapNavigationHelper.gd` — navigation and pathfinding
  - Bakes `NavigationPolygon` from `floor_cells` in `bake_navigation_region()`.
  - Path APIs: `find_path_preferred(start, goal)` and wrappers used by `MapManagerCore`.
  - Delegates coordinate conversion to `DungeonGenerator` for grid/world transforms.

- `OccupancyManager.gd` — actor occupancy and blocking
  - Tracks `_cell_to_actor` and `_actor_to_cell` mappings.
  - Public: `register_actor(actor, grid_pos, blocks=true, allow_multi=false)`, `unregister_actor(actor)`, `update_actor_cell(actor, new_cell)`, `is_cell_blocked(grid_pos, requester=null)`.
  - Emits signal: `occupancy_changed` and maintains a `version` integer to detect updates.

- `MapManagerCore.gd` — game-facing facade
  - Combines `DungeonGenerator`, `MapNavigationHelper`, and `OccupancyManager` into canonical APIs:
    - `is_walkable_cell_for_actor(grid_pos, actor)`
    - `find_path(start, goal, actor)`
    - `get_actor_room_id(actor)`
    - `register_actor(actor, grid_pos, blocks)`

Call graphs and canonical flows (who calls whom)

1) Walkability check (game actor wants to move)
   - Actor code -> `MapManager` / `MapManagerCore.is_walkable_cell_for_actor(grid_pos, actor)`
   - `MapManagerCore` calls `DungeonGenerator.is_cell_walkable(grid_pos)` and `OccupancyManager.is_cell_blocked(grid_pos, actor)`; both must return false for walkable.

2) Pathfinding
   - Actor code -> `MapManagerCore.find_path(start, goal, actor)`
   - `MapManagerCore` delegates to `MapNavigationHelper.find_path_preferred(start, goal, ...)` which computes A* over grid or uses `NavigationRegion2D` baked polygon.

3) Occupancy registration (spawn or move)
   - When an enemy/player is created or moves:
     - Spawn sequence: `EnemySpawnLifecycleService` picks world grid cell -> calls `OccupancyManager.register_actor(enemy, grid_cell, blocks=true)`.
     - `OccupancyManager` updates `_cell_to_actor` / `_actor_to_cell` and emits `occupancy_changed`.
     - Consumers (UI, TileHighlighter) subscribe to `occupancy_changed` for visual updates.

Data synchronization and subtle behaviors

- Versioning: `OccupancyManager` uses a version counter on occupancy updates — consumers should read the version atomically to avoid stale queries during multi-step moves.
- Read-after-write semantics: grid data is mutated synchronously during generation. Consumers that build derived data (like navigation polygons) rely on the generation call completing before `bake_navigation_region()` is invoked.
- Mutability of `room_info`: presentation code augments `room_info` with node references; consumers must be aware `room_info` is not pure data.

Tile/grid data formats and performance notes

- `floor_cells` / `wall_cells` are used as primary sources of truth. Their representation is dictionary/set-like — iterating the entire set to build render or navigation is O(N) in floor cell count.
- Large maps: building tilemaps and navigation polygons from large `floor_cells` sets can be CPU intensive. If maps will scale up, consider chunked generation or on-demand baking to reduce single-frame cost.

Edge cases & ownership ambiguities (for follow-up)

- Who owns spawned enemy nodes? `EnemySpawnLifecycleService` instantiates enemies using `manager._enemy_scene.instantiate()` and calls `manager.add_child(enemy)` — enemy parenting goes to `EnemyManager`. The presence of `dungeon.enemies_root` in `DungeonSceneHelper.gd` suggests an alternative intended parent; confirm intended ownership.
- Who is responsible for clearing generated content? `DungeonSceneHelper.clear_generated_content()` clears roots; ensure the runtime flow calls this before re-generation to avoid leftover nodes.

Appendix: key APIs (representative)

- `DungeonGenerator.world_to_grid_coords(world_pos: Vector2) -> Vector2i`
- `DungeonGenerator.grid_to_world_coords(grid_pos: Vector2i) -> Vector2`
- `OccupancyManager.register_actor(actor: Node, grid_pos: Vector2i, blocks: bool = true)`
- `MapNavigationHelper.bake_navigation_region()`

End of file.

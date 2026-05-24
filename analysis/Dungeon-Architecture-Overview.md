# Dungeon Architecture Audit

Status: draft — generated from static analysis of the codebase (May 23, 2026).

Summary
- Focus: the end-to-end dungeon generation pipeline from layout -> graph -> presentation, and the runtime orchestration that wires generation to navigation and gameplay systems.
- Primary orchestrators discovered: `MapManager._ready()` and `DungeonGenerator.generate_dungeon()`.

Primary files referenced
- `scripts/world/dungeon/DungeonGenerator.gd`
- `scripts/world/dungeon/DungeonLayoutGenerator.gd`
- `scripts/world/dungeon/DungeonGraph.gd`
- `scripts/world/dungeon/DungeonRoomFactory.gd`
- `scripts/world/dungeon/DungeonPresentationManager.gd`
- `scripts/world/dungeon/DungeonTileRenderer.gd`
- `scenes/DungeonWorld.tscn`

1) Global architecture overview

- Roles and separation
  - Dungeon model / authoritative data: `DungeonGenerator.gd` (grid metadata, `floor_cells`, `wall_cells`, `room_infos`, coordinate conversions).
  - Layout / algorithm: `DungeonLayoutGenerator.gd` (places rooms, carves corridors, writes into `DungeonGenerator` structures).
  - Logical connectivity: `DungeonGraph.gd` (room nodes, corridor edges, adjacency queries, validation).
  - Presentation / scene creation: `DungeonRoomFactory.gd`, `DungeonPresentationManager.gd`, `DungeonTileRenderer.gd` (convert dungeon model data to TileMap, StaticBody walls, Area2D detectors and room visuals).
  - Runtime orchestration / facades: `MapManager.gd` and `MapManagerCore.gd` (entry at scene startup; provide unified APIs for gameplay code).
  - Runtime helpers: `DungeonRuntimeSetup.gd`, `DungeonSceneHelper.gd` (ensure scene roots and runtime containers exist).

2) Ownership map (high level)

- Dungeon grid authoritative store: `DungeonGenerator.gd` —
  - fields: `floor_cells` (set/dict of Vector2i floor coordinates), `wall_cells`, `tile_size`, `grid_origin`, `room_infos` (room metadata), `active_room_id`.
  - conversions: `world_to_grid_coords()`, `grid_to_world_coords()`.
- Layout mutator: `DungeonLayoutGenerator.gd` — writes room rects, floor/corridor cells and populates `room_infos` directly into `DungeonGenerator` (no interface boundary).
- Wall derivation and world objects: `DungeonWallManager.gd` — derives `wall_cells` from `floor_cells` and spawns StaticBody2D walls/occluders.
- Presentation: `DungeonPresentationManager.gd` and `DungeonRoomFactory.gd` — create node graph (rooms root, corridor nodes, lights, Area2D detectors) and register Area2Ds with `room_system.gd`.
- Navigation: `map_navigation_helper.gd` — bakes a `NavigationRegion2D` using `floor_cells` and exposes pathfinding wrappers.
- Occupancy: `OccupancyManager.gd` — authoritative for actor occupancy and blocking; used by `MapManagerCore.gd` for game queries.

3) Runtime flow (step-by-step)

This is the canonical synchronous startup path as inferred from code flows (call sites referenced):

1. Scene instantiation: `scenes/DungeonWorld.tscn` or `scenes/MapManager.tscn` is instanced in the running scene tree.
2. `MapManager._ready()` executes and calls `dungeon_generator.generate_dungeon(player)` (synchronous call).
3. In `DungeonGenerator.generate_dungeon(player)`:
   - `_ensure_runtime_nodes()` via `DungeonRuntimeSetup.gd` ensures room roots, tilemap layers and manager singletons exist.
   - Call into `DungeonLayoutGenerator.generate()` which places rooms and carves corridors by writing to `dungeon.floor_cells` and `dungeon.room_infos`.
   - `DungeonGraph` is built concurrently/after layout to store room adjacency and corridor cells (`add_room`, `add_edge`).
   - `DungeonWallManager.generate_walls_from_floor()` derives `wall_cells` and (optionally) instantiates wall StaticBody2D nodes.
   - `DungeonPresentationManager.setup()` and `.build()` are invoked to create visuals:
       - `DungeonRoomFactory.create_room_nodes()` for each `room_info` -> creates room visual root, Area2D detectors and registers them with `room_system.gd`.
       - `DungeonTileRenderer.set_data(floor_cells, wall_cells)` then `.build()` paints TileMap layers.
       - Fog-of-war and room lighting layers are created/initialized.
   - `map_navigation_helper.bake_navigation_region()` constructs a `NavigationPolygon` from `floor_cells`.
4. `MapManager` continues startup: `MapTurnSetup.setup_enemy_manager()` is called, which instantiates `EnemyManager`, calls `setup()` and `spawn_enemies()`.
5. Enemy spawning: `EnemySpawnLifecycleService.spawn_enemies()` iterates `room_infos`, selects spawn cells using `EnemySpawnPlanner.get_random_floor_cell_in_room()` and instantiates enemy scenes.
6. Actors register with `OccupancyManager` and `TurnManager` — turn/AI systems begin operation.

Notes about ordering and synchronization
- Generation is synchronous and performed during `_ready()` — presentation and enemy spawning happen in the same callstack. This implies no built-in asynchronous load or streaming of rooms at generation time.
- Because layout writes directly into the generator's internal state, there are no clean transactional boundaries (e.g., generate -> commit), so partial writes during retries could require explicit cleanup.

4) Orchestration responsibilities

- `MapManager.gd` — primary runtime entry point used by scenes. Sets up `DungeonGenerator` and then calls into navigation, enemy and turn systems.
- `DungeonGenerator.gd` — orchestrates layout, wall derivation and presentation build. Also exposes run-time queries and emits `room_changed` / `room_cleared` signals.
- `MapTurnSetup.gd` — orchestrates `TurnManager` and `EnemyManager` creation and triggers the spawn lifecycle.

5) Dependency analysis & system coupling

- Tight coupling: `DungeonLayoutGenerator.gd` directly mutates `DungeonGenerator` internals (`floor_cells`, `room_infos`). There is no generator interface used to apply layout changes. This increases coupling and reduces testability of the layout algorithm in isolation.
- Presentation-model mixing: `DungeonPresentationManager` and `DungeonRoomFactory` assume a `room_info` shape and may augment/mutate it (visual keys, node references). Model and presentation responsibilities are blended.
- Split ensure/bootstrapping: `DungeonRuntimeSetup.gd` and `DungeonGenerator` both contain "ensure manager/runtime node" logic. Responsibilities for runtime wiring are duplicated across files.

6) Scalability concerns

- Grid storage format: `floor_cells` and `wall_cells` appear to be dictionary/set-like structures keyed by `Vector2i` strings. For very large dungeons this can grow memory usage quickly and affect iteration times; consider sparse storage or chunking if scaling beyond current dims.
- Synchronous generation + synchronous spawning: large generation and immediate instantiation of enemy nodes can cause frame hitches on startup.
- Navigation bake cost: `map_navigation_helper.bake_navigation_region()` reconstructs navigation polygons from floor cells; if called on very large floor sets frequently this could be expensive.

7) Observed risks & immediate follow-ups

- Single-call startup: generation, presentation construction and enemy spawning all occur synchronously. Risk: startup hitches and limited ability to stream or lazily instantiate room content.
- God-object candidates: `DungeonGenerator` holds most authoritative state and also orchestrates presentation; it risks becoming a monolith. `MapManager` is also a multi-responsibility entry point handling wiring for occupancy, navigation and enemy creation.
- Data/presentation coupling: `room_info` is used both as model and as a mutable holder for presentation references (nodes), which may complicate serialization, testing and reuse.

Appendix: quick file call examples (representative snippets)

- `MapManager._ready()` -> `dungeon_generator.generate_dungeon(player)`
- `DungeonGenerator.generate_dungeon()` -> `DungeonLayoutGenerator.generate()` -> writes `dungeon.floor_cells` and `dungeon.room_infos`
- `DungeonPresentationManager.build()` -> `DungeonRoomFactory.create_room_nodes(room_info, rooms_root, room_lights_root, room_detectors_root)`
- `EnemySpawnLifecycleService.spawn_enemies(manager, room_infos, wall_cells)` -> `EnemySpawnPlanner.get_random_floor_cell_in_room(...)` -> instantiate enemy scene

End of file.

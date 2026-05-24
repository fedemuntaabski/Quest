# Spawning and Pacing Analysis

Status: draft — enemy spawn lifecycle, planner rules and turn integration extracted from static analysis (May 23, 2026).

Purpose
- Document how enemies are selected, placed into the world, registered with turn/pacing systems, and how reward/boss flows are managed. Highlight pacing risks and design implications for tactical gameplay.

Primary components and responsibilities

- `MapTurnSetup.gd` — bootstraps `TurnManager` and `EnemyManager` during `MapManager` startup; calls `setup_enemy_manager()` which instantiates `EnemyManager` and triggers `spawn_enemies()`.

- `EnemyManager.gd` — high-level lifecycle manager for enemies on the map.
  - `setup(dungeon_ref, player_ref, turn_manager)` binds the manager to dungeon and gameplay systems.
  - `spawn_enemies(room_infos, wall_cells)` delegates to `EnemySpawnLifecycleService.spawn_enemies()`.
  - Tracks `_room_enemy_counts` and emits `room_cleared` and `boss_defeated` signals.

- `EnemySpawnLifecycleService.gd` — actual instantiation and lifecycle wiring
  - `spawn_enemies(manager, room_infos, wall_cells)` iterates `room_infos`, computes candidate spawn cells and instantiates enemy scenes.
  - `_spawn_enemy_for_room(manager, room_info, wall_cells, map_manager, player_cell, occupied_spawn_cells)` chooses cells via `EnemySpawnPlanner` and registers enemies with `OccupancyManager` and `TurnManager`.

- `EnemySpawnPlanner.gd` — cell selection policy
  - `get_random_floor_cell_in_room(room_info, wall_cells, avoid_center, player_cell, occupied_spawn_cells, dungeon)` produces a random floor cell filtered to avoid walls, entrance tiles, player cell and previously reserved cells. It optionally avoids room center when `avoid_center` is true.

- `EnemyDataSelector.gd` and resources `resources/enemies/*.tres` — choose enemy types including boss classification for final rooms.

Spawn sequencing and registration (detailed)

1. After `DungeonGenerator.generate_dungeon()` completes, `MapTurnSetup.setup_enemy_manager()` is executed.
2. `EnemyManager.setup()` is called with references to `DungeonGenerator`, the player, and the `TurnManager` instance.
3. `EnemyManager.spawn_enemies(room_infos, wall_cells)` calls `EnemySpawnLifecycleService.spawn_enemies()`.
4. For each room:
   - `EnemySpawnPlanner.get_random_floor_cell_in_room()` returns a candidate spawn cell respecting avoidance rules (entrances, center, player cell, already used cells).
   - Enemy scene is instantiated (`manager._enemy_scene.instantiate()`), then parented to `EnemyManager` (`manager.add_child(enemy)`), and `enemy.setup(...)` is called.
   - `OccupancyManager.register_actor(enemy, grid_cell, blocks=true)` registers the enemy's grid occupancy.
   - `TurnManager.register_actor(enemy)` is invoked so the enemy participates in the turn loop.

Pacing and tactical implications

- Synchronous spawn timing: all enemies are spawned immediately during startup. This produces a fixed pacing envelope where all room encounters exist simultaneously; it reduces options for staggered encounter pacing (waves, delayed spawns) without further runtime logic.
- Spawn density: `EnemySpawnPlanner` uses room floor cells and simple filters; it does not appear to use room difficulty scaling, line-of-sight analysis, or tactical choke-point evaluation. Encounters may cluster near room centers unless `avoid_center` is enabled.
- Room-based counting: `EnemyManager` tracks counts per-room in `_room_enemy_counts`, enabling per-room victory conditions and `room_cleared` events; this supports room-based pacing but not intra-room waves.

Boss and final room handling

- `EnemyDataSelector` can mark selected enemy data as `is_boss`, and `EnemyManager` treats final-room selection specially by selecting boss-type EnemyData resources.
- `EnemyRewardService.process_enemy_defeat()` accumulates rewards and emits `boss_defeated` vs normal enemy defeat pathways; final payout flows through `CurrencyManager` at run end.

Risks and suggested validations (no code changes)

- Memory & performance: spawning all enemies as actual scene instances at generation time increases memory and startup CPU cost especially for large dungeons with many rooms.
- Tactical placement limitations: planner selects cells randomly from filtered lists; lacks heuristics for sight-lines, cover placement, and difficulty distribution across rooms. This may reduce tactical variety.
- Coupling: `EnemySpawnLifecycleService` assumes `OccupancyManager` and `TurnManager` are already available and correctly wired. Verify the exact ordering in `MapManager._ready()` to ensure registration happens before `TurnManager.start()`.

Questions for follow-up (verification)

1. Should enemy nodes be parented to `EnemyManager` or `dungeon.enemies_root`? The presence of both suggests ambiguity in node ownership.
2. Is staggered spawning (waves) desired later? If so, early refactor options should expose spawn plans instead of immediate instantiation.

Appendix: representative call snippets

- `MapTurnSetup.setup_enemy_manager(map_manager)` -> `enemy_manager.setup(dungeon_ref, player_ref, turn_manager)` -> `enemy_manager.spawn_enemies(room_infos, wall_cells)`
- `EnemySpawnLifecycleService._spawn_enemy_for_room(...)` -> `manager._enemy_scene.instantiate()` -> `manager.add_child(enemy)` -> `enemy.setup(...)` -> `occupancy.register_actor(enemy, grid_cell, blocks=true)` -> `turn_manager.register_actor(enemy)`

End of file.

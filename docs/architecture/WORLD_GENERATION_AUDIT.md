# World Generation Audit

## Scope
This document audits the live dungeon/world generation path in the current Godot 4 project. It describes how the system actually works today, where state is owned, which parts are reusable, and which parts conflict with a future modular grammar-based architecture.

Live entry path observed in the workspace:
- `scenes/Main2d.tscn` -> `scripts/managers/Main2d.gd`
- `scenes/MapManager.tscn` -> `scripts/world/rooms/MapManager.gd`
- `scripts/world/dungeon/DungeonGenerator.gd`

The important boundary is that the live runtime path is not the legacy `DungeonWorld.tscn` scene. The active gameplay path is `Main2d -> MapManager -> DungeonGenerator`.

## Current Architecture

### High-level ownership split
- `DungeonLayoutGenerator` produces a pure candidate layout.
- `DungeonGenerator` owns runtime dungeon state after the layout is committed.
- `DungeonPresentationManager` builds runtime presentation nodes.
- `RoomSystem` controls active-room switching and connectivity enforcement.
- `MapTurnSetup` and `EnemySpawnLifecycleService` handle post-generation spawn setup.
- `OccupancyManager` is the canonical occupancy store for actors.
- `MapNavigationHelper` bakes navigation and provides pathfinding helpers.

This is already more modular than a single monolithic generator, but the boundaries are not clean enough for a grammar-driven room assembly system yet.

## Generation Pipeline

### 1. Scene boot and orchestration
`Main2d.gd` loads the map scene and wires the top-level gameplay flow. `MapManager.gd` then owns the dungeon boot for the map scene and calls `dungeon_generator.generate_dungeon(player)` during `_ready()`.

### 2. Runtime setup
`DungeonGenerator` lazily creates helper objects through `DungeonRuntimeSetup`. That setup ensures the following runtime components exist:
- `DungeonLayoutGenerator`
- `DungeonRoomManager`
- `DungeonWallManager`
- `RoomSystem`
- `RoomCameraController`
- `DungeonRoomFactory`
- scene roots such as `Corridors`, `Rooms`, `Walls`, `RoomDetectors`, `RoomLights`, and `Enemies`

This means the generator is not just a data builder; it is also a scene bootstrapper.

### 3. Layout generation
`DungeonLayoutGenerator.generate()` is the core procedural algorithm. It:
1. Creates working buffers for floor cells, corridor cells, room records, and graph topology.
2. Repeatedly rolls room sizes and positions until it has the requested room count or exhausts attempts.
3. Rejects rooms that overlap existing rooms after padding expansion.
4. Registers each room into the working graph and working floor-cell set.
5. Connects rooms by carving corridors between room centers.
6. Validates the graph.
7. Returns `DungeonLayoutData` as a handoff object.

The algorithm is fundamentally room-rectangle based, not connector-grammar based.

### 4. Layout commit
`DungeonGenerator._apply_layout_data()` copies layout data into runtime ownership:
- `floor_cells`
- `corridor_cells`
- `room_infos`
- `dungeon_graph`

It then initializes room runtime/presentation stores. This commit step is the current runtime authority boundary.

### 5. Wall derivation
`DungeonWallManager.generate_walls_from_floor()` iterates floor-cell neighbors and creates walls around the floor perimeter. Walls are derived after layout commit and are not part of the layout model itself.

### 6. Presentation build
`DungeonPresentationManager.build()` creates visual nodes for each room and corridor edge, then builds the tile presentation and fog-of-war presentation.

Important: the live path does not instantiate authored room or corridor scenes. It creates generic runtime nodes instead.

### 7. Player placement
If a player is provided, `DungeonGenerator.place_player_in_start_room()` moves the player to the center cell of room 0 and syncs grid state when supported.

### 8. Active-room state
`RoomSystem` enforces room connectivity and updates `DungeonGenerator.active_room_id`. `DungeonRoomManager` then updates visibility and lighting from the canonical active room state.

### 9. Enemy spawn setup
`MapTurnSetup` creates the `EnemyManager`, passes in dungeon state, spawns enemies from room infos and wall cells, registers the player, and starts the turn manager.

## Detailed Findings

### Room placement order
Room placement is procedural and random. The generator:
- rolls room sizes within `room_min_size` / `room_max_size`
- rolls room positions inside the grid with `room_padding`
- rejects overlaps via rectangle intersection against padded existing rooms
- registers rooms in the order they are accepted

This means room order is tied to generation order, not semantic room roles. Room 0 is only the first accepted room.

### Corridor generation
Corridors are tile-cell carved directly into the floor-cell set. They are not scene-generated corridors.

The corridor algorithm:
- chooses the nearest unvisited room by center distance
- walks either horizontal-first or vertical-first at random
- adds corridor cells while respecting grid bounds and existing floor cells
- records corridor cells in both the layout dictionary and the graph edge record

The corridor system is topological and cell-based, not connector-based.

### TileMap usage
TileMap presentation is built by `DungeonTileRenderer`. It paints a `TileMapLayer` from the generated floor cells and wall adjacency. `MapNavigationHelper` also bakes a `NavigationPolygon` from floor cells and uses that as the navigation region source.

### Grid alignment rules
- Grid size is controlled by `grid_width` and `grid_height`.
- `tile_size` is `16.0` in the inspected generator.
- `grid_origin` is centered by subtracting half the grid size in world space.
- `world_to_grid_coords()` uses floor division from local position into grid cells.
- `grid_to_world_coords()` places entities at cell centers.

The coordinate system is consistent and simple, but it is also strongly coupled to a rectangular grid footprint.

### Randomization flow
Randomization is global and direct:
- `generate_dungeon()` calls `randomize()`.
- layout generation uses `randi_range()` and `randf()`.
- corridor orientation and tile variation are randomized.
- enemy data selection also uses direct random picks.

No explicit seed management was found in the live generation path.

### Runtime instancing flow
The runtime instancing flow is split across presentation and spawning:
- rooms create generic `Node2D`, `PointLight2D`, and `Area2D` nodes
- corridors create generic `Node2D` placeholders with metadata
- walls are spawned as `StaticBody2D`
- enemies are spawned from `PackedScene` resources selected by enemy data

That means `PackedScene` is used correctly for enemies, but not for dungeon rooms or corridors.

## Feature Support Matrix

| Capability | Status | Notes |
|---|---|---|
| Modular room scenes | No in live path | Current runtime creates generic nodes instead of instancing room scenes. |
| Rotation | Partial / legacy only | Rotated room assets exist, but runtime generation does not apply arbitrary rotation. |
| Directional connectors | Weak | Current layout uses centers and rectangles, not connector metadata. |
| Procedural assembly | Yes | Room rectangles and corridors are procedurally assembled. |
| Occupancy/grid validation | Yes | `OccupancyManager` and `MapManagerCore` enforce occupancy and walkability. |
| Collision validation | Partial | Walls and nav are derived, but the generator does not validate authored room scene collision because it does not instantiate those scenes. |
| Room metadata | Yes | `room_infos`, `DungeonGraph`, and `DungeonLayoutData` carry room metadata. |
| Boss room integration | Partial | Final room is flagged as boss in graph/layout, and enemy selection uses `final_room_id`. |
| Spawn markers | Not in live path | Tutorial scene has markers, but normal enemy spawning uses room floor cells. |

## Problems Detected

### 1. Room data mixes layout and runtime concerns
`room_infos` starts as procedural data but is later merged with runtime state and presentation objects through compatibility shims in `DungeonGenerator`.

Why this matters:
- It makes the layout record both a model and an object registry.
- It complicates any future grammar compiler that needs a stable, immutable layout contract.

### 2. Duplicate bootstrap responsibility
`DungeonGenerator` and `DungeonRuntimeSetup` both ensure managers and scene roots exist. `MapManager` also bootstraps turn and enemy setup.

Why this matters:
- Initialization behavior is split across several layers.
- A future compiler/runtime split will need one authoritative bootstrap boundary.

### 3. Layout validation is topology-only
`DungeonLayoutData.is_valid()` only checks graph presence, room count, and non-empty floor cells. `DungeonGraph.validate()` checks graph connectivity and edge integrity, but not semantic room grammar or connector rules.

Why this matters:
- The current system can guarantee connectivity, but not modular room semantics.

### 4. Corridor and room scene assets are disconnected from runtime
The workspace contains authored room/corridor scenes such as `sala_*.tscn` and `pasillo_*.tscn`, but the live generator does not instantiate them.

Why this matters:
- These assets are not a live source of truth.
- They look like legacy or experimental content rather than reusable modular pieces.

### 5. No seed persistence was found
The generator randomizes without an explicit seed contract in the inspected path.

Why this matters:
- Reproducibility is weak.
- Grammar debugging and replayable generation will be harder later.

## Reusable Systems

These systems are worth preserving in a future rewrite:
- `DungeonLayoutGenerator` for graph-based room assembly and connectivity validation
- `DungeonGraph` as a topology model
- `OccupancyManager` as the canonical actor occupancy store
- `MapNavigationHelper` for grid/pathfinding abstraction
- `RoomSystem` for active-room ownership
- `EnemySpawnLifecycleService` and `EnemyDataSelector` for spawn lifecycle and data selection
- `DungeonWallManager` for deriving runtime walls from floor cells

## Dangerous Systems

These are the highest-risk pieces for a grammar-based migration:
- Compatibility shims that merge runtime/presentation fields back into `room_infos`
- `DungeonRuntimeSetup`, because it duplicates initialization work already performed by `DungeonGenerator`
- `DungeonRoomFactory`, because it currently creates runtime placeholders instead of instanced room prefabs
- `DungeonMapRenderer`, because it is a stub base that can be mistaken for the active implementation
- `DungeonWorld.tscn`, because it appears to be a parallel/legacy scene path

## Technical Debt Summary

- The system is still rectangle-first rather than connector-first.
- Runtime state and generated layout state are partially interleaved.
- Scene assets for rooms and corridors are not wired into live generation.
- Seed control is not formalized.
- Bootstrap responsibilities overlap across multiple layers.

## Bottom Line
The current world generation system is serviceable and reasonably modular for a tile-based rogue-lite, but it is not yet a modular room grammar system. The strongest reusable foundation is the layout graph + occupancy + navigation stack. The main rewrite pressure is around room/corridor instancing, metadata contracts, and the removal of compatibility shims that blur layout with runtime state.
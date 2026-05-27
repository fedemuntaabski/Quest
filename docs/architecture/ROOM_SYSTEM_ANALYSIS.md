# Room System Analysis

## Scope
This document focuses on how rooms, connectors, activation, presentation, and room-related scene assets currently behave in the live project.

## Current Room Model

### Procedural room record
The live generator stores rooms as dictionaries in `room_infos`. The procedural room record contains:
- `id`
- `rect`
- `center_cell`
- `floor_cells`
- `template`
- sometimes `is_main_path`

The topology layer also stores room records in `DungeonGraph`, which keeps a lighter version of the room metadata.

### Runtime room state
`DungeonGenerator` maintains separate runtime dictionaries:
- `room_runtime` for visited state
- `room_presentation` for `visual_root`, `light`, and `area`

This separation exists, but the public accessors still merge runtime/presentation data back into `room_infos` for compatibility.

## Room Representation Findings

### What rooms are today
Rooms are rectangle footprints on a grid, not reusable prefab instances. The layout generator carves cells into the floor grid, then the presentation layer creates generic runtime nodes for room visuals and room detection.

### What rooms are not today
Rooms are not currently instantiated from the authored room scenes in `scenes/`.

That means the current system does not yet support true modular room scenes in the live path.

## Door and Connector Analysis

### Current connector model
The live room/corridor system does not expose a connector grammar. Instead it uses:
- room rectangles
- room centers
- corridor cell lists
- generic room-area overlap detection

`RoomSystem` uses `Area2D.body_entered` to infer room entry, and `DungeonRoomFactory.create_room_area()` expands room detection by one tile in all directions to reduce transition stickiness.

### Door logic
There is no live door-node system in the inspected runtime path.

Observed facts:
- Normal room scenes and corridor scenes contain `Entrada` and `Salida` markers in the authored assets.
- The live generator does not read those markers.
- The live runtime uses generic `Area2D` room detectors instead of door connectors.

This is the biggest mismatch with a modular connector grammar.

## Rotation Compatibility Analysis

### Runtime rotation
No runtime room-rotation pipeline was found in the live generator.

### Scene rotation assets
There are rotated authored scenes such as `sala_1_rotada.tscn`, `sala_2_rotada.tscn`, and similar variants. Those assets swap marker positions, which suggests manual authoring support for rotated layouts.

### Compatibility assessment
Current support is only legacy/asset-level, not procedural.

Implications:
- The system does not generalize rotation from a connector grammar.
- Any future modular room architecture will need explicit rotation metadata and connector remapping.

## Scene Consistency Report

The authored room/corridor scenes are not used as live room prefabs, but they are still useful as evidence of the intended content structure.

### Normal room scenes
Examples sampled:
- `sala_1.tscn`
- `sala_2.tscn`
- `sala_3.tscn`
- `sala_4.tscn`
- rotated counterparts

Observed pattern:
- `Node2D` root
- `TileMapLayer`
- `Entrada` marker
- `Salida` marker

### Corridor scenes
Examples sampled:
- `pasillo_1.tscn`
- `pasillo_2.tscn`
- `pasillo_3.tscn`

Observed pattern:
- `Node2D` root
- `TileMapLayer`
- `Entrada` marker
- `Salida` marker

### Boss room
`sala_boss.tscn` appears to have a `Node2D` root and a `TileMapLayer`, and in the sampled excerpt it exposed `Entrada` but no confirmed `Salida`.

### Tutorial room
`sala_tutorial.tscn` is structurally different from the normal rooms. In the sampled excerpt it exposed:
- `TileMapLayer`
- `Salida`
- `Spawn_jugador`
- `Spawn_tutorial`

This room contains explicit spawn markers, but the live spawn system does not consume them.

### Consistency conclusion
The scene library is not fully standardized around the user’s expected structure:

Expected shape from the requested audit:
- `Node2D`
- `TileMapLayer`
- `Puertas`
  - `Marker2D`
- `SpawnEnemigos`

Observed live-authored assets:
- `Entrada` / `Salida` markers instead of a `Puertas` container
- no live evidence of a standardized `SpawnEnemigos` container
- tutorial-only special spawn markers

## Room Activation and Camera Behavior

### Activation owner
`RoomSystem` is the canonical active-room authority. It rejects non-connected room switches when `enforce_connectivity` is enabled and keeps `DungeonGenerator.active_room_id` in sync.

### Presentation owner
`DungeonRoomManager` updates room visibility, visited tint, and room light energy.

### Camera behavior
`RoomCameraController` switches between room and corridor modes by checking whether the player is inside any room rectangle, not by reading door markers or connector metadata.

This means camera mode is also rectangle-centric rather than connector-centric.

## Boss and Tutorial Integration

### Boss room
The boss room is only semantically special in topology and spawn selection:
- `DungeonLayoutGenerator` tags the last room as `boss_room`
- `EnemyManager.final_room_id` is derived from the highest room id
- `EnemyDataSelector` chooses boss enemy data when `room_id == final_room_id`

The room scene itself is not currently a special modular boss prefab in the live generation path.

### Tutorial room
Room id 0 is treated specially by enemy data selection, forcing tutorial enemy data. The tutorial scene also contains explicit spawn markers, but the live runtime spawns enemies from room floor cells instead of marker nodes.

## Compatibility Summary

| Area | Status | Notes |
|---|---|---|
| Modular room scenes | Not supported in live path | Runtime creates generic nodes instead of instancing room prefabs. |
| Door connectors | Not supported | No live connector grammar or door-node system was found. |
| Rotation | Asset-level only | Rotated scene variants exist, but runtime does not rotate rooms procedurally. |
| Spawn markers | Partial / legacy | Tutorial room has markers, but spawn system uses floor-cell selection. |
| Boss room semantics | Partial | Topology and enemy selection are boss-aware; scene instancing is not. |

## Bottom Line
The room system is currently a grid-rectangle system with runtime room areas, not a modular room prefab system. For a grammar-based architecture, the main missing pieces are:
- explicit door/connector ownership
- room prefab instancing
- runtime rotation metadata
- spawn marker integration
- a stable scene contract that all rooms follow
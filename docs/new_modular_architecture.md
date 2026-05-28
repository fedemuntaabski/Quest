# New Modular Architecture

This document describes the second migration slice: a prefab-native dungeon assembly path that uses authored scenes as the source of truth while keeping the legacy rectangle pipeline only as a compatibility bridge.

## Runtime Ownership

- `DungeonGenerator` remains the scene boot shell and the compatibility owner for `room_infos`, `floor_cells`, `dungeon_graph`, and active-room state.
- `DungeonAssembler` is the new assembly authority for prefab-native room and corridor instancing.
- `DungeonPresentationManager` consumes assembled room records and still owns fog/runtime presentation wiring.
- `DungeonRoomFactory` remains a transitional bridge for room lights, detector areas, and any fallback presentation data.
- `RoomSystem`, `RoomCameraController`, `MapManagerCore`, `EnemyManager`, and `EnemySpawnLifecycleService` remain downstream consumers of the assembled dungeon state.

## Prefab Assembly Flow

The initial prefab-native slice is intentionally hard-coded:

1. instantiate `sala_tutorial.tscn`
2. instantiate `pasillo_1.tscn`
3. instantiate `sala_1.tscn`

The assembler aligns scenes using authored marker positions instead of corridor carving or room-center routing. The tutorial room is the spawn authority for the opening flow, and the resulting layout data is committed back into the legacy compatibility containers so existing systems can continue to read room, grid, and graph state.

## Scene Contracts

The target modular scene shape is:

- `Node2D`
  - `TileMapLayer`
  - `Puertas`
    - `Marker2D`
  - `SpawnEnemigos`
  - `SpawnJugador` for tutorial flow only

Current authored scenes still use the legacy root-level marker layout, so the new assembler and adapters accept those names while the scene audit tracks the normalization work.

Canonical marker names used by the runtime bridge:

- `Entrada`
- `Salida`
- `Spawn_Jugador`
- `Spawn_Tutorial`
- `SpawnEnemigos`

Accepted legacy variants during the bridge:

- `Spawn_jugador`
- `Spawn_tutorial`
- `spawn_jugador`
- `spawn_tutorial`
- `Spawn_Enemigos`
- `spawnenemigos`

## Connector Expectations

- Connectors are room-local metadata, not procedural corridor endpoints.
- Connector direction should come from authored marker orientation when present.
- Connector position should be derived from the scene instance, not from the legacy rectangle center.
- `RoomPrefabAdapter` and `RoomConnectorAdapter` remain the inspection layer for connector discovery, spawn marker lookup, and local floor-cell extraction.
- Future authored scenes should place connectors under `Puertas` so the runtime can stop relying on root-level fallback searches.

## Spawning Rules

- Tutorial player spawn should resolve from `Spawn_Jugador` in `sala_tutorial.tscn`.
- Tutorial enemy spawn should resolve from `Spawn_Tutorial` in `sala_tutorial.tscn`.
- Non-tutorial enemy spawning still uses the legacy enemy lifecycle bridge for now, but the long-term goal is marker-based room spawning rather than floor-cell sampling.
- Rectangle-center placement remains only as a temporary fallback when a marker is missing.

## Temporary Compatibility Bridges

The following bridges remain intentionally alive for this phase:

- `room_infos` still exists so room consumers can keep reading room metadata.
- `floor_cells` still exists so navigation, occupancy, and fog can continue to work.
- `dungeon_graph` still exists so room connectivity and enemy lifecycle code stay stable.
- `DungeonRoomFactory` still attaches room lights and detector areas and can still provide fallback room visuals if needed.
- `RoomSystem` and `RoomCameraController` still operate on room rectangles until connector-aware transitions are validated.
- `MapManagerCore` still reasons about room rectangles for walkability and actor-room compatibility.

## Remaining Legacy Dependencies

- `DungeonLayoutGenerator` is still present but is no longer the target authority for the first prefab-native slice.
- `DungeonGraph` still exists as the compatibility connectivity model and still carries corridor edge records.
- `Rect2i` room bounds are still needed by room activation, camera framing, and map compatibility helpers.
- Corridor routing is still represented by a single hard-coded prefab path instead of a general connector graph.
- The live runtime still supports legacy marker names and root-level marker placement while the authored scenes are normalized.

## Future Migration Steps

- Normalize all modular scenes to the `Puertas` marker container contract.
- Add explicit connector metadata for each room and corridor prefab.
- Expand the hard-coded slice into a template registry for more rooms and corridors.
- Replace room-center corridor assumptions with connector-to-connector routing.
- Reduce `Rect2i`-based runtime checks once room activation, camera framing, and occupancy are connector-aware.
- Remove the compatibility bridge only after the prefab-native path proves stable end to end.
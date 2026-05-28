# World Generation Cleanup

This document tracks the first cleanup slice of the legacy rectangle-based dungeon pipeline. The goal is to isolate the old procedural systems without rewriting the prefab-based replacement yet.

## Removed Systems

- Procedural wall derivation from `floor_cells` via `DungeonWallManager.generate_walls_from_floor()`.
- Procedural tile painting in `DungeonTileRenderer`.

## Disabled Systems

- The runtime pass that derived walls from the generated floor grid is now inert.
- The legacy tile renderer no longer paints rectangle-driven floor/wall tiles.

## Preserved Systems

- `DungeonGenerator.generate_dungeon()` still exists as the scene boot shell.
- `DungeonPresentationManager` still instantiates room prefabs and maintains fog/runtime state.
- `RoomSystem`, `RoomCameraController`, player placement, enemy wiring, turn flow, status effects, save data, UI, and occupancy flow remain untouched.
- `DungeonRoomFactory` still creates room visuals and corridor entities during the migration window.

## Remaining Dependencies

- `DungeonLayoutGenerator` still produces transitional room layout records.
- `room_infos`, `floor_cells`, and `dungeon_graph` still exist as compatibility data for the current migration bridge.
- `DungeonRoomFactory` still receives rectangle-derived room metadata until the new prefab-native layout flow is introduced.

## Potential Risks

- Any caller still expecting runtime-generated wall cells from the old procedural pass may now receive empty wall derivation unless its geometry comes from prefabs.
- Scene authors that relied on `DungeonTileRenderer` for visible dungeon tiles will now depend on prefab room scenes instead.
- The old rectangle layout data is still present as a bridge, so downstream code must not treat it as the final architecture.

## Temporary Compatibility Shims

- `DungeonGenerator` keeps legacy room layout accessors while room state continues to be split across layout/runtime/presentation stores.
- `DungeonRoomFactory` still accepts `room_info` records with rectangle metadata.
- `DungeonWallManager` remains available for explicit manual wall edits, but not for procedural wall generation.
- `DungeonTileRenderer` still exists as a scene-compatible node, but its procedural painting path is disabled.

## Next Migration Slice

- Reduce the rectangle-first behavior in `DungeonLayoutGenerator` and `DungeonGraph`.
- Remove any remaining live dependency on corridor carving and room-center connectivity once a prefab-native layout source is ready.
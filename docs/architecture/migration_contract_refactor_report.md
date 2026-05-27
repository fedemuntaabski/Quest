# Migration Contract Refactor Report

## What Changed

This pass split the dungeon room contract into three explicit ownership layers and kept the current gameplay path intact.

### New room state objects
- `DungeonRoomLayoutState` now carries pure compile-time room data.
- `DungeonRoomRuntimeState` now owns mutable gameplay state such as `visited`.
- `DungeonRoomPresentationState` now owns presentation/view references such as `visual_root`, `light`, and `area`.

### Dungeon contract changes
- `DungeonLayoutData` now carries `room_layouts` alongside the legacy `room_infos` layout dictionaries.
- `DungeonLayoutGenerator` now builds explicit room layout state objects and corridor adjacency metadata.
- `DungeonGenerator` now owns separate layout, runtime, and presentation stores.
- `DungeonGenerator` now exposes explicit getters for:
  - layout info
  - layout state
  - runtime state
  - presentation state
- `DungeonGenerator.get_room_info()` and `DungeonGenerator.get_room_infos_with_runtime()` remain as legacy compatibility shims.

### Consumer updates
- `DungeonRoomManager` now reads layout data plus explicit runtime/presentation state instead of depending on merged room dictionaries.
- `DungeonPresentationManager` now consumes layout info and runtime state separately.
- `FogOfWarManager` now receives layout data and runtime state as separate inputs.
- Room camera consumers now use layout-only accessors instead of merged room data.
- `MapManagerCore` and `RoomSystem` now query layout data through explicit layout accessors.
- `MapTurnSetup` now passes layout-only room data into enemy spawning.

## Legacy Compatibility That Still Exists

These surfaces remain intentionally available so the live path stays stable during the refactor:
- `DungeonGenerator.room_infos` still exists as the layout dictionary array.
- `DungeonGenerator.get_room_info()` still returns a merged legacy view.
- `DungeonGenerator.get_room_infos_with_runtime()` still exists for older callers.
- `DungeonGenerator.room_runtime` and `DungeonGenerator.room_presentation` are still dictionary-backed internal stores.
- `DungeonRoomFactory` still creates runtime placeholder room nodes, lights, and detectors.
- `DungeonRuntimeSetup` still performs the current bootstrap wiring boundary.

## Remaining Architectural Risks

- The layout/runtime split is now explicit, but several systems still rely on `Rect2i` room bounds as the primary geometric contract.
- Room activation, camera framing, fog, and enemy spawning are still bound to rectangular room extents rather than connector semantics.
- Runtime room presentation still depends on generated placeholder nodes, which is acceptable for this phase but still couples presentation to the legacy room shell.
- `DungeonGenerator` still acts as the central runtime hub, so future work will need to reduce its coordination load further.

## Systems Still Coupled To `Rect2i`

These systems still assume rectangular room bounds directly or indirectly:
- `MapManagerCore`
- `RoomSystem`
- `RoomCameraController`
- `CameraMode_Room`
- `CameraMode_Corridor`
- `DungeonRoomManager`
- `EnemySpawnLifecycleService`
- `MapTurnSetup`
- `FogOfWarManager`

That coupling is preserved on purpose for this stabilization phase because it keeps the current gameplay behavior unchanged.

## Notes On Layout vs Runtime vs Presentation

- Layout data is now the compile-time contract and should remain immutable by convention.
- Runtime state is the only place where gameplay-visible room flags should live.
- Presentation state is the only place where room node references should live.
- No runtime or presentation data should be written back into layout records.

## Recommended Next Steps

1. Replace remaining direct `room_infos` reads with the explicit layout accessors wherever they are still used.
2. Consider turning the room state objects into `Resource` types only if editor serialization becomes necessary.
3. Reduce the `Rect2i` dependency by introducing connector metadata and explicit room anchors in a later phase.
4. Move corridor attachment and room activation logic away from room-center assumptions once prefab room instancing is introduced.
5. After the next phase, remove or quarantine the legacy merged getters once all callers have migrated.

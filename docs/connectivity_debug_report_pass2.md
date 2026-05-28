# Connectivity Debug Report (Pass 2)

Date: 2026-05-27
Scope: Prefab-native stabilization follow-up focused on traversal, seam connectivity, room/corridor alignment, occupancy correctness, and spawn restrictions.

## Summary

This pass continues from the existing prefab-native migration state. It does not reintroduce rectangle generation or procedural repainting. The implementation focuses on three concrete blockers:

1. doorway seam alignment drift between `sala_tutorial` and `pasillo_1`
2. traversal rejection without explicit reason visibility
3. enemy spawn leakage into corridor/seam cells

## Implemented Changes

### 1. Room/Corridor Alignment and TileMap-to-Grid Conversion

- Updated world floor-cell extraction to use `TileMapLayer` transforms directly (`map_to_local` + `to_global`) before converting to grid.
- This replaces the previous room-root-only conversion path that could ignore layer offsets and cause off-by-one doorway seams.
- Preserved connector seam lock authority during corridor placement:
  - marker snap remains authoritative (`Salida` -> `Entrada`)
  - post-snap translation nudge is skipped to avoid breaking seam alignment
- Overlap reconciliation diagnostics now include overlap counts and a sample of exact overlap cells.

Files:
- `scripts/world/dungeon/RoomPrefabAdapter.gd`
- `scripts/world/dungeon/DungeonAssembler.gd`

### 2. Traversal Diagnostics and Connectivity Authority

- Added explicit movement rejection diagnostics with reason codes:
  - `not_walkable_floor`
  - `occupied_blocked`
  - `room_lock_restriction`
- Player move request path now logs detailed seam/move rejection state.
- Queued move action path now logs the same rejection diagnostics.
- Seam probes now log richer state per connector marker cell:
  - seam cell grid coordinate
  - owner room id
  - walkable/blocked
  - occupying actor
  - floor/wall membership
- Room activation now logs accepted transitions as well as rejects.
- Connectivity checks now use assembled `dungeon_graph` when available in prefab-native runs, avoiding mismatch with procedural layout connectivity.

Files:
- `scripts/world/rooms/MapManagerCore.gd`
- `scripts/core/movement/PlayerMovementTurnBridge.gd`
- `scripts/core/actions/MoveAction.gd`
- `scripts/world/rooms/MapManager.gd`
- `scripts/world/rooms/room_system.gd`
- `scripts/world/dungeon/DungeonGenerator.gd`

### 3. Corridor/Seam Spawn Restrictions

- Hardened corridor room classification in spawn lifecycle:
  - detects `corridor`, `pasillo`, and scene path `/pasillo_`
- Added explicit forbidden-cell guard in spawn lifecycle to reject candidate cells that are corridor or seam markers.
- Spawn planner now excludes:
  - global corridor cell set (`dungeon.corridor_cells`)
  - connector marker cells (`Entrada`, `Salida`)
  - existing room forbidden spawn set

Files:
- `scripts/core/enemy/EnemySpawnLifecycleService.gd`
- `scripts/core/enemy/EnemySpawnPlanner.gd`

## Why Traversal Was Failing (Root-Cause Notes)

Likely multi-cause failure chain:

1. `TileMapLayer` offset mismatch could project floor cells to shifted grid cells (geometry looked connected but logical walkable cells were misregistered).
2. Corridor post-snap nudge could desynchronize the exact connector seam after marker alignment.
3. Transition gating could rely on non-prefab adjacency source in some runs, causing connected transitions to be rejected.
4. Without detailed movement diagnostics, failures appeared as generic "cannot enter corridor" with no subsystem attribution.

## Exact Seam-Cell Diagnostics Added

Runtime now emits seam diagnostics containing:

- seam marker (`Entrada`/`Salida`)
- marker-derived seam cell (`Vector2i`)
- owner room id
- walkability status
- occupancy blocked state
- occupying actor name
- floor/wall membership
- movement rejection reason and room-lock state (when move fails)

Key log sources:
- `MapManager: seam probe ...`
- `PlayerMovementTurnBridge: move rejected ...`
- `MoveAction: rejected ...`
- `RoomSystem: rejected activation ...` / `RoomSystem: activation accepted ...`
- `DungeonAssembler: connectivity trace tutorial->corridor->sala_1 ...`

## Occupancy Fix Notes

- Existing dead-enemy unregister behavior remains in place (`MapManager.unregister_actor(enemy)` in defeat flow).
- This pass adds stronger diagnostics to confirm seam cells are not blocked by stale occupancy during traversal.

## Corridor Spawn Filtering Notes

Corridors should never spawn enemies. This pass enforces that at two layers:

1. room classification skip (`corridor`/`pasillo`)
2. candidate-cell rejection for corridor/seam marker cells

This prevents corridor spawn even if room floor sets overlap due to authored geometry edges.

## Full Connectivity Trace (Target Path)

Temporary trace now covers:

- instantiated room and corridor identity
- world origins
- connector pair resolution
- seam cells
- corridor/room overlap reconciliation
- seam walkability + occupancy state after nav bake
- room activation acceptance/rejection logs

Target path:

`sala_tutorial -> pasillo_1 -> sala_1`

## Remaining Blockers Before Removing Rectangle Compatibility

1. Validate runtime seam logs in an actual debug playthrough to confirm final seam cells are walkable and unblocked before/after tutorial enemy death.
2. Verify that no map variant requires authored marker rotation cleanup to keep connector direction consistent.
3. Confirm camera and room activation edge behavior in corridor transitions still behaves correctly with mixed compatibility systems.
4. After successful validation, trim debug verbosity behind a dedicated debug flag.

## Validation Checklist (Pass 2)

1. Start debug run and capture seam probe logs for tutorial/corridor and corridor/sala_1 markers.
2. Kill tutorial enemy; verify seam cells remain `blocked=false` and movement crosses into `pasillo_1`.
3. Continue to `sala_1`; verify no persistent transition rejection for connected rooms.
4. Confirm no spawn log places enemies in corridor or seam cells.
5. Confirm overlap logs show seam-preserving cleanup (non-seam overlap removed).

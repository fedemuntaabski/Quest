# Connectivity Stabilization Report

Date: 2026-05-28
Scope: Prefab-native traversal stabilization for `sala_tutorial -> pasillo_1 -> sala_1`.

## Summary

This slice keeps the prefab-native dungeon path intact and focuses on connector alignment, seam stability, corridor classification, and traversal unlock behavior. It does not reintroduce rectangle-first room generation.

## Marker Alignment Fixes

- Corridor placement continues to snap from authored `Salida` to authored `Entrada` using marker global positions.
- Corridor seam checks now retain marker-derived seam cells during overlap reconciliation so connector cells are not stripped during cleanup.
- Corridor debug output now includes marker rotation delta so the seam can be inspected against authored facing data during migration.

Files:
- `scripts/world/dungeon/DungeonAssembler.gd`
- `scripts/world/dungeon/RoomConnectorAdapter.gd`
- `scripts/world/dungeon/RoomPrefabAdapter.gd`

## Temporary `pasillo_1` Offset Compensation

- A corridor-only downward shim of 2 tiles was added for `pasillo_1` inside corridor assembly only.
- This is a temporary migration compensation to stabilize the seam while the authored connector layout is being finalized.
- The offset is not spread across the runtime; it is isolated to the corridor assembly path.

Files:
- `scripts/world/dungeon/DungeonAssembler.gd`

## Seam-Cell Fixes

- Seam cells are still treated as authoritative connector cells during overlap trimming.
- Corridor floor cells continue to be reconciled against both adjacent rooms so corridor clipping into room interiors is minimized.
- Debug diagnostics now show the resolved seam cells alongside marker alignment output.

Files:
- `scripts/world/dungeon/DungeonAssembler.gd`
- `scripts/world/rooms/MapManager.gd`

## Traversal Unlocking

- The runtime already uses room-clear flow through enemy defeat cleanup, room-clear emission, and room activation gating.
- Defeated enemies are removed from turn ownership and occupancy before `room_cleared` is emitted.
- `RoomSystem` still accepts connected transitions once the player is no longer blocked by the active room's enemy count.
- The seam remains traversal-friendly as long as the corridor cells are not occupied by stale actors.

Files:
- `scripts/core/enemy/EnemyRewardService.gd`
- `scripts/world/rooms/OccupancyManager.gd`
- `scripts/world/rooms/MapManagerCore.gd`
- `scripts/world/rooms/RoomSystem.gd`
- `scripts/managers/Main2d.gd`

## Corridor Spawn Restrictions

- Corridor runtime metadata is now stamped explicitly as `room_role = corridor` and `room_type = corridor`.
- Corridor room classification in the enemy spawn lifecycle now recognizes corridor metadata directly.
- Enemy spawn planning now short-circuits for corridor rooms before selecting a spawn cell.
- Existing forbidden-cell checks still exclude corridor cells and connector seam cells.

Files:
- `scripts/world/dungeon/DungeonAssembler.gd`
- `scripts/world/dungeon/DungeonRoomFactory.gd`
- `scripts/core/enemy/EnemySpawnLifecycleService.gd`
- `scripts/core/enemy/EnemySpawnPlanner.gd`

## Remaining Blockers Before More Room Templates

- Live playtesting still needs to confirm the `pasillo_1` downward shim can be removed once the authored seam is finalized.
- Marker rotation/facing is logged, but the current stabilization slice still relies on position snap as the actual placement authority.
- Additional room templates should wait until the current tutorial corridor seam is walkable, occupancy-free, and free of combat spawning.

## Validation Performed

- GDScript diagnostics passed for the touched runtime files.
- The new corridor metadata and corridor spawn gating changes compile cleanly in the current slice.

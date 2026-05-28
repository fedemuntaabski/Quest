# Connectivity Debug Report

Date: 2026-05-27
Scope: Prefab-native stabilization only (connector alignment, room connectivity, traversal flow, occupancy/navigation, and boss-room spawn restrictions).

## Corridor Alignment Fixes

- Updated marker-based corridor placement in DungeonAssembler to keep marker snap authority while reducing room-border clipping.
- Added post-snap corridor nudge logic that moves corridor away from the anchor room when floor-cell overlap is greater than one seam tile.
- Added seam-cell tracking from connector markers (`Entrada`, `Salida`) using DungeonGenerator world-to-grid conversion.
- Added debug logs for connector resolution, marker world positions, corridor origin, and seam cell coordinates.

## Room Overlap Fixes

- Added overlap reconciliation between corridor and attached rooms after final room placement.
- Corridor floor/corridor cell registration now removes room-overlap cells except explicit seam cells.
- Added overlap diagnostics that print cell counts before and after reconciliation.
- This keeps corridor connected at doorway seams while preventing duplicate blocked geometry ownership.

## Traversal Fixes

- Corrected room-id resolution path used by MapManagerCore:
  - `MapManagerCore.get_room_id_for_cell()` now delegates to `DungeonGenerator.get_room_id_for_cell()`.
  - This uses floor-aware room containment rather than rectangle-only scanning.
- Added RoomSystem diagnostics for rejected/accepted transitions with player cell context.
- Added post-navigation-bake seam probes in MapManager to print walkable/blocked status at connector marker cells.

## Occupancy / Navigation Fixes

- Fixed enemy defeat cleanup so defeated enemies are explicitly unregistered from occupancy:
  - `EnemyRewardService` now calls `MapManager.unregister_actor(enemy)` after turn unregister.
- This prevents dead enemies from continuing to block traversal cells.
- Navigation diagnostics now include connector seam walkability probes immediately after bake.

## Boss Room Restriction Fixes

- Removed max-room-id boss fallback behavior from spawn selection.
- Added room classification (`tutorial`, `standard`, `boss`, `corridor`) in spawn lifecycle.
- Boss designation now resolves from room metadata/scene identity (`room_role`, `template`, `prefab_scene_path` containing `sala_boss`).
- Boss selection is allowed only when:
  - `room_type == boss`, or
  - room id matches explicit designated boss room id.
- Added runtime validation log to block boss profile use in non-boss rooms.
- Corridor rooms are explicitly excluded from spawn loop.

## Temporary Debug Instrumentation Added

- DungeonAssembler
  - room/corridor instancing details
  - connector pair resolution and seam cells
  - nudge offsets and overlap counts
  - final placement summaries
- RoomSystem
  - transition rejection/acceptance details with player cell
- MapManager
  - seam walkability probes after navigation bake
- DungeonRoomManager
  - room visibility status (active/visited/visible) to distinguish hidden vs missing room nodes
- EnemySpawnLifecycleService
  - room type, selected enemy, boss-allowed status, designated boss room

## Remaining Migration Blockers

- Current hardcoded prefab slice does not include an authored boss room in this path, so no boss room may be designated in that layout.
- Marker orientation conventions in authored scenes are not yet fully normalized; some maps may still need marker rotation cleanup to avoid manual seam nudges.
- Room and camera systems still depend partly on rectangle compatibility behavior; full connector-native activation/camera logic remains future migration work.
- Debug logs are intentionally verbose for validation and should be gated/trimmed after stabilization is verified.

## Validation Checklist

1. Run a debug session and confirm logs show connector seam resolution for tutorial -> corridor -> sala_1.
2. Kill tutorial enemy and verify player can traverse out of tutorial into corridor and into sala_1.
3. Confirm no persistent RoomSystem rejection for connected transitions.
4. Confirm no dead enemy occupancy blockers remain.
5. Confirm boss enemies only appear in designated boss room conditions.

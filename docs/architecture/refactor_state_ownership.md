# Refactor: State Ownership and Write Graph Changes

Summary of the design changes applied in code to enforce single-writer ownership and explicit repair:

1) Active room ownership
- Canonical writer: `RoomSystem` (`RoomSystem._set_active_room()`).
- Changes: `DungeonRoomManager.set_active_room()` now delegates to `RoomSystem._set_active_room()` and only updates visuals based on `dungeon.active_room_id` (no longer mutates `dungeon.active_room_id` directly).
- Files: `scripts/world/dungeon/DungeonRoomManager.gd`.

2) Occupancy canonical writer
- Canonical writer: `OccupancyManager`.
- Changes: `OccupancyManager._update_actor_cell()` now updates `actor.grid_pos` and increments a `_version` counter. Movement and effect code now call `map_manager.update_actor_cell()` rather than writing `actor.grid_pos` directly.
- Files: `scripts/world/rooms/OccupancyManager.gd`, `scripts/core/movement/PlayerMovement.gd`.

3) Explicit repair API
- `MapManagerCore.get_actor_room_id()` no longer performs repair. `MapManagerCore.repair_actor_room(actor)` is the only repair writer and must be called explicitly by spawn, sync, or turn-start paths.
- Files: `scripts/world/rooms/MapManagerCore.gd`.

4) Snapshot-based card execution
- `CombatCardSystem.queue_card_action()` captures a `TargetSnapshot` (target reference, cell, room_id, occ_version) and `CardAction` executes using that snapshot.
- `CombatCardSystem.execute_card_snapshot()` validates `occ_version` and returns `stale_snapshot` when versions differ.
- Files: `scripts/core/combat/CombatCardSystem.gd`, `scripts/core/combat/CardAction.gd`.

5) Action/turn hardening
- Actions now return structured results and the `ActionQueue` emits `action_finished(action, result)`.
- `TurnManager` uses `result["consumes_turn"]` to decide turn consumption.
- `ActionQueue` provides `cancel_action()` for canceling queued or running actions.
- Files: `scripts/core/actions/BaseAction.gd`, `scripts/core/actions/ActionQueue.gd`, `scripts/core/actions/TurnManager.gd`.

Rationale and incremental approach
- All changes were kept incremental and backwards-compatible: explicit repair calls were added at movement completion, spawn, and enemy turn-start so behavior remains stable while removing implicit repairs.
- Snapshotting was applied only to card actions initially to limit scope; other action types remain unchanged for now.

If you want to strictly enforce snapshots across all action types next, we can extend the snapshot pattern to movement and attack actions.

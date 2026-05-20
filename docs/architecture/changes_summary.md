# Refactor Changes Summary

This document lists the code changes performed to make room/occupancy state deterministic, add snapshot-based card execution, and harden the action queue and turn manager.

High-level goals:
- Centralize room activation writes to `RoomSystem`.
- Make `OccupancyManager` the canonical writer for actor grid positions and provide a monotonic version counter.
- Remove implicit "repair on read" behavior and require explicit repair calls.
- Snapshot targets at queue time for deterministic execution.
- Add structured action results and cancellation APIs.

Files changed (major):
- `scripts/world/dungeon/DungeonRoomManager.gd`
  - Delegates active-room writes to `RoomSystem._set_active_room()` and updates visuals from canonical `dungeon.active_room_id`.

- `scripts/world/rooms/OccupancyManager.gd`
  - Now assigns `actor.grid_pos` in `_update_actor_cell()` and emits `occupancy_changed`.
  - Adds `_version` counter and `get_version()` to support snapshot staleness detection.

- `scripts/world/rooms/MapManagerCore.gd`
  - Removed implicit repair in `get_actor_room_id()` and `_resolve_actor_cell()`.
  - Added `repair_actor_room(actor)` for explicit reconciliation which also sets `Enemy.my_room_id`.

- `scripts/core/movement/PlayerMovement.gd`
  - Calls `map_manager.core.repair_actor_room(self)` after movement completion and during `sync_to_grid()`.

- `scripts/core/enemy/EnemyManager.gd`
  - After spawning and calling `enemy.setup()`, registers occupancy and calls `map_manager.core.repair_actor_room(enemy)`.

- `scripts/core/enemy/Enemy.gd`
  - Calls `map_manager.core.repair_actor_room(self)` at `begin_turn()` to stabilize decision-making.

- `scripts/core/combat/CombatCardSystem.gd`
  - `queue_card_action()` now builds a `TargetSnapshot` (target, cell, room_id, occ_version) and queues actions with that snapshot.
  - Added `execute_card_snapshot()` which validates occupancy version and executes using snapshot without implicit repairs.

- `scripts/core/combat/CardAction.gd`
  - Now accepts a snapshot as `target` and extracts the real `Node` for validation/logging.
  - Uses `execute_card_snapshot()` and finishes with a structured result.

- `scripts/core/actions/BaseAction.gd`
  - Actions now carry a `result: Dictionary` and `finish(result)` emits `completed(action, result)`.

- `scripts/core/actions/ActionQueue.gd`
  - Emits `action_finished(action, result)` with structured results.
  - Tracks `_current_action` and provides `cancel_action(action, reason)` for queued/running cancellation.

- `scripts/core/actions/TurnManager.gd`
  - `_on_action_finished(action, result)` now respects `result["consumes_turn"]` when deciding whether to end the actor's turn.

- Tests added:
  - `tests/test_snapshot_staleness.gd`
  - `tests/test_action_cancellation.gd`

See `docs/tests.md` for instructions to run tests.

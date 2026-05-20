Runtime State Model — Actual Runtime Behavior

Summary
- This document describes the live runtime state models observed in the repo (May 19, 2026). It documents where state is written, where it's read, and how the live and snapshot models interact.

Key sources of truth (observed in code)
- `RoomSystem.active_room_id` is the canonical active-room value; `RoomSystem._set_active_room()` assigns `active_room_id` and propagates it to `DungeonGenerator.active_room_id`.
  - See [scripts/world/rooms/room_system.gd](scripts/world/rooms/room_system.gd#L50-L63).
- `OccupancyManager` is the canonical owner of actor grid occupancy and exposes a monotonic `_version` for staleness checks.
  - See [scripts/world/rooms/OccupancyManager.gd](scripts/world/rooms/OccupancyManager.gd#L1-L20) and its `_version`/`occupancy_changed` emitters at [scripts/world/rooms/OccupancyManager.gd](scripts/world/rooms/OccupancyManager.gd#L121-L131).
- `TurnManager` + `ActionQueue` are the runtime authorities for turn progression: `TurnManager` starts actor turns and consumes turns based on `ActionQueue` results.
  - See [scripts/core/actions/TurnManager.gd](scripts/core/actions/TurnManager.gd#L1-L20) and [scripts/core/actions/ActionQueue.gd](scripts/core/actions/ActionQueue.gd#L1-L30).
- Snapshot model exists (partial): `CombatCardSystem.queue_card_action()` captures a `TargetSnapshot` and `CombatCardSystem.execute_card_snapshot()` validates `occ_version` before applying effects; `CardAction` awaits `execute_card_snapshot()`.
  - See [scripts/core/combat/CardAction.gd](scripts/core/combat/CardAction.gd#L40-L47) and docs in [docs/refactor_state_ownership.md](docs/refactor_state_ownership.md#L20-L22).

Write paths and read paths (traced)
- Room activation
  - Writers: `RoomSystem._set_active_room(room_id)` (canonical writer) -> writes `RoomSystem.active_room_id` and `DungeonGenerator.active_room_id` (propagation). [scripts/world/rooms/room_system.gd#L50-L63]
  - Delegating writer: `DungeonRoomManager.set_active_room()` delegates to `dungeon.room_system._set_active_room(room_id)` instead of mutating dungeon directly. [scripts/world/dungeon/DungeonRoomManager.gd#L11-L19]
  - Readers: camera, UI, renderers, and room controllers read `DungeonGenerator.active_room_id` (e.g., camera modes at [scripts/world/camera/CameraMode_Room.gd#L39-L43]).

- Actor position / occupancy
  - Canonical writer: `OccupancyManager._update_actor_cell()` updates `_actor_to_cell`, `_cell_to_actor`, increments `_version`, and emits `occupancy_changed` (single canonical source). [scripts/world/rooms/OccupancyManager.gd#L121-L131]
  - Movement writers: `map_manager.update_actor_cell()` and movement controllers call into the occupancy layer rather than mutating `actor.grid_pos` directly (but some legacy code still assigns `global_position` or `actor.grid_pos` then calls repair). See `PlayerMovement.begin_turn()` and movement completion logic at [scripts/core/movement/PlayerMovement.gd#L150-L180].
  - Readers: AI decision code, combat targeting, and UI query `OccupancyManager.get_actor_at(cell)` and `get_version()` to validate snapshots.

- Turn progression
  - Writers: `TurnManager` schedules/rotates `current_actor` and calls `current_actor.begin_turn(self)`; `ActionQueue` runs actions and emits `action_finished(action, result)` used by `TurnManager` to decide consumption. [scripts/core/actions/TurnManager.gd#L83-L121]
  - Readers: actor code (`begin_turn`), movement controllers, and enemy AI read `turn_manager.current_actor` or rely on `begin_turn` invocation.

- Combat targeting & snapshots
  - Queue-time capture: `CombatCardSystem.queue_card_action()` builds a `TargetSnapshot` (target reference, cell, room_id, occ_version) and enqueues a `CardAction` with that snapshot. [docs/refactor_state_ownership.md#L20-L21]
  - Execution path: `CardAction.execute()` extracts the real target from the snapshot and `await`s `CombatCardSystem.execute_card_snapshot(card_data, target_snapshot)`; that function validates `occ_version` and returns `stale_snapshot` if versions differ. [scripts/core/combat/CardAction.gd#L40-L47]
  - Readers: card effects use the snapshot-provided room/cell/occ_version to make decisions; some effect code may still query live occupancy or actor properties.

Observed inferred state and fallback logic
- `RoomSystem._set_active_room()` has connectivity enforcement logic and accepts non-adjacent syncs when `enforce_connectivity` is false — printed as "accepting non-adjacent room sync" — an explicit fallback during syncs. [scripts/world/rooms/room_system.gd#L54-L61]
- `OccupancyManager` logs warnings when replacing existing occupancy and performs "repair" style updates only when explicitly invoked (spawn/setup/turn-start call explicit repair). [docs/refactor_state_ownership.md#L28-L31]
- `CombatCardSystem.execute_card_snapshot()` returns a `stale_snapshot` codepath instead of attempting implicit repair (documented in repo docs). [docs/refactor_state_ownership.md#L20-L22]

Stale reads and async boundary observations
- `CardAction.execute()` awaits `CombatCardSystem.execute_card_snapshot(...)` — this async hop is used to detect staleness and avoid implicit repair, but any code that reads live state before awaiting may operate on stale values. [scripts/core/combat/CardAction.gd#L40-L47]
- `ActionQueue` awaits `action.execute()` and then waits for an `action.completed` signal; concurrently emitting `action_finished` and awaiting signals creates windows for state changes between start and finish. See `godot_debug_output.txt` which shows ActionQueue awaiting `action.execute()` and `action.completed`. [godot_debug_output.txt]

Live vs Snapshot co-existence
- Snapshot model: applied for card actions only. Snapshots include `occ_version` and are validated at execute-time. [docs/refactor_state_ownership.md#L20-L22]
- Live model: movement, enemy decisions, and many action types still read live state and sometimes call `repair` at turn-start. The two models coexist and are only partially integrated.

Remaining inconsistencies (high level)
- Dual-model divergence: snapshot-based card execution is enforced for cards, but other actions still mutate and read live state; callers that mix snapshots with live reads risk mismatch.
- Multiple writers: while `OccupancyManager` is the canonical writer, many code paths still write `global_position` or `actor.grid_pos` (EnemyManager spawn, some movement code) and then call repair; these are potential write conflicts.
- Async stale reads: `await` calls in `CardAction`, `PlayerMovement` (timers) and `ActionQueue` create windows where live state changes can invalidate earlier reads.

Architectural risks introduced by current implementation
- Partial snapshot enforcement: Only card actions are deterministic-snapshotted. Movement/attacks are not yet snapshotted, enabling surprising non-determinism during combat.
- Version mismatch handling: returning `stale_snapshot` makes execution safe but can silently alter game outcomes if callers do not handle `stale_snapshot` properly.
- Broken invariants (see validation section below) can lead to edge-case behavior such as actions executing on removed or relocated targets.

Validation of invariants (summary)
- Is room state truly single-writer? Mostly yes — `RoomSystem._set_active_room()` is canonical, but some older code may still write `dungeon.active_room_id` directly; the current codebase delegates `DungeonRoomManager` calls to `RoomSystem` so room state is largely single-writer in practice. Evidence: [scripts/world/dungeon/DungeonRoomManager.gd#L16-L19] and [scripts/world/rooms/room_system.gd#L61-L63].
- Is occupancy fully centralized? Partially: `OccupancyManager` is the canonical writer and exposes `_version`. However, components sometimes write `global_position` or `actor.grid_pos` and rely on explicit `repair` calls, so occupancy is only centralized if repair paths are correctly invoked. See [docs/refactor_state_ownership.md#L28-L31].
- Is snapshot system fully enforced or partial? Partial — only card actions are snapshotted. See [docs/refactor_state_ownership.md#L32-L34].
- Is turn progression single-authority? Yes — `TurnManager` + `ActionQueue` are the runtime authorities for turn sequencing; actors receive `begin_turn()` calls from `TurnManager`. See [scripts/core/actions/TurnManager.gd#L83-L121].
- Is combat deterministic across all entry points? No — determinism is enforced for card actions that use snapshots, but movement and attack actions still rely on live state; mixed flows are non-deterministic.

Next steps
- Produce a state ownership matrix showing writers/readers per state item and classify inconsistencies. Then produce the async boundaries and combat determinism reports.




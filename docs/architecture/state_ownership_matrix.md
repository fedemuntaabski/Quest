State Ownership Matrix — Actual Runtime Truth

Summary
- This matrix maps important runtime state items to their observed writers, primary readers, any secondary writers, and notes about staleness or inferred/fallback logic.

Columns: State | Canonical Writer(s) | Other Writers | Primary Readers | Staleness / Fallback Notes

- Active room (`active_room_id`)
  - Canonical Writer: `RoomSystem._set_active_room()` — writes `RoomSystem.active_room_id` and copies to `DungeonGenerator.active_room_id`.
    - See [scripts/world/rooms/room_system.gd](scripts/world/rooms/room_system.gd#L50-L63).
  - Other Writers: historically `DungeonRoomManager` could write directly; current code delegates to `RoomSystem` (delegation in [scripts/world/dungeon/DungeonRoomManager.gd](scripts/world/dungeon/DungeonRoomManager.gd#L11-L19)).
  - Primary Readers: camera controllers, room visuals, UI code, map managers.
  - Notes: connectivity enforcement path in `RoomSystem` can reject or accept non-adjacent syncs; explicit fallback behavior is logged rather than repaired automatically.

- Actor occupancy / grid cell
  - Canonical Writer: `OccupancyManager._update_actor_cell()` (mutates internal maps, increments `_version`, emits `occupancy_changed`). [scripts/world/rooms/OccupancyManager.gd#L121-L131]
  - Other Writers: `EnemyManager` and spawn/setup code set `enemy.global_position` then register occupancy via `map_manager` or call `repair_actor_room()`; some movement code still assigns `actor.grid_pos` directly before repair.
  - Primary Readers: AI (targeting), combat systems, UI, pathfinding.
  - Notes: snapshots capture `occ_version` at queue time; `CombatCardSystem.execute_card_snapshot()` validates versions and returns `stale_snapshot` on mismatch. See [docs/refactor_state_ownership.md#L20-L22].

- Actor `global_position` / `grid_pos` property
  - Canonical Writer: `OccupancyManager` (via `update_actor_cell`) for the logical grid representation; scene `global_position` is written by spawn/movement code.
  - Other Writers: movement tweens, spawn placements, enemy setup code.
  - Primary Readers: rendering and physics; some gameplay logic uses `global_position` directly.
  - Notes: divergence between `global_position` and occupancy can exist until explicit repair is called.

- Turn progression (`current_actor`, actor turn lifecycle)
  - Canonical Writer: `TurnManager` (assigns `current_actor`, calls `begin_turn`). [scripts/core/actions/TurnManager.gd#L83-L121]
  - Other Writers: actions can cause `TurnManager.end_turn()` indirectly through results; but sequencing authority remains `TurnManager`.
  - Primary Readers: actor code (`begin_turn` implementations), ActionQueue.
  - Notes: `ActionQueue` emits `action_finished(action, result)` and `TurnManager` decides consumption via `result["consumes_turn"]`.

- ActionQueue queue state
  - Canonical Writer: `ActionQueue.queue_action()` and action completion handlers.
  - Other Writers: callers (player controllers, AI) enqueue actions.
  - Primary Readers: `ActionQueue.process_next()` and `TurnManager` (via signals).
  - Notes: `ActionQueue` awaits `action.execute()` (async) and then waits for `action.completed` — this async handoff is a source of timing windows.

- Combat target snapshot (TargetSnapshot)
  - Canonical Writer: `CombatCardSystem.queue_card_action()` (captures `target`, `cell`, `room_id`, `occ_version`). [docs/refactor_state_ownership.md#L20-L21]
  - Other Writers: none for the snapshot itself; the live target can move or be removed after snapshot creation.
  - Primary Readers: `CardAction` and `CombatCardSystem.execute_card_snapshot()`.
  - Notes: snapshot validation prevents implicit repairs in `execute_card_snapshot()` and returns `stale_snapshot` when occupancy versions mismatch.

Inconsistency classifications (examples)
- Dual-model divergence (LIVE vs SNAPSHOT mismatch)
  - Example: Card queued with `occ_version=V1`, target moves; at execute-time, `execute_card_snapshot()` sees `occ_version=V2` and returns `stale_snapshot`. Source: [docs/refactor_state_ownership.md#L20-L22].
  - Classification: dual-model divergence and deliberate handling via `stale_snapshot` return.

- Write conflict (possible)
  - Example: `EnemyManager` sets `enemy.global_position` and then calls registration routines; if another system calls `OccupancyManager._update_actor_cell()` concurrently (rare but possible across deferred calls), there can be short windows of inconsistent mappings.
  - Classification: write conflict (timing-sensitive), mitigated by explicit repair in spawn/setup code. See `scripts/core/enemy/EnemyManager.gd` registration / repair notes.

- Stale read (observed)
  - Example: `CardAction` logs `card_data.display_name` and `real_target.name` before awaiting `execute_card_snapshot()`; UI/logic that used `real_target` before await may be reading state that changes by the time the awaited call runs. See [scripts/core/combat/CardAction.gd#L20-L47].
  - Classification: stale read due to async boundary.

- Implicit fallback
  - Example: `RoomSystem._set_active_room()` accepts non-adjacent room syncs when `enforce_connectivity` is false; this is an explicit fallback path logged by `RoomSystem`. [scripts/world/rooms/room_system.gd#L54-L61]

Per-state quick recommendations (for engineering priorities)
- Enforce occupancy writes: audit and minimize direct `global_position`/`grid_pos` writes; route all changes via `OccupancyManager`.
- Expand snapshot model: either extend snapshot capture/validation to movement/attack actions, or explicitly mark non-deterministic actions and ensure callers handle `stale_snapshot` outcomes.
- Harden async boundaries: ensure `ActionQueue` and `CardAction` signal/result handling includes explicit checks for target validity after async awaits.


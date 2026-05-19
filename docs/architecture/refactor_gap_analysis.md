Refactor Gap Analysis — Where runtime differs from intended refactor and remaining risks

Scope
- Compare observed runtime behavior against the refactor intent described in repository docs (e.g., `docs/refactor_state_ownership.md`) and list remaining gaps, partial implementations, and risks.

What the refactor intended (short)
- Centralize active-room writes in `RoomSystem`.
- Make `OccupancyManager` the canonical occupancy writer with monotonic versioning.
- Add snapshot-based execution for deterministic card actions and harden `ActionQueue` / `TurnManager` around action results.
- Reduce implicit repair and make repair explicit at spawn/setup/turn-start.

What is actually implemented (observed)
- Room activation: implemented — `DungeonRoomManager` delegates to `RoomSystem._set_active_room()`; `RoomSystem` writes `active_room_id` and propagates to `dungeon.active_room_id`. [scripts/world/dungeon/DungeonRoomManager.gd#L16-L19] and [scripts/world/rooms/room_system.gd#L50-L63].
- Occupancy canonicalization: largely implemented — `OccupancyManager` holds canonical occupancy and exposes `_version`. However, many code paths still write `global_position` or `actor.grid_pos` before invoking explicit repair. This means the centralized model exists but is not yet enforced by call-site discipline. [scripts/world/rooms/OccupancyManager.gd#L121-L131] and [docs/refactor_state_ownership.md#L28-L31].
- Snapshotting: partially implemented — only `CardAction` / `CombatCardSystem` use the snapshot model (queue-time capture and execute-time validation). Movement and other actions are not snapshotted. [docs/refactor_state_ownership.md#L32-L35].
- ActionQueue/TurnManager hardening: partially implemented — `ActionQueue` provides `cancel_action()` and `TurnManager` inspects `result["consumes_turn"]`, but `ActionQueue` still uses an async pattern (`await action.execute()` then wait for `action.completed`) that leaves timing windows.

Gaps and practical risk items
1. Snapshot coverage gap
  - Risk: Mixed snapshot/live actions cause dual-model divergence and unpredictable `stale_snapshot` frequency.
  - Files: `docs/refactor_state_ownership.md`, `scripts/core/combat/CombatCardSystem.gd`, `scripts/core/combat/CardAction.gd`.

2. Occupancy write discipline
  - Risk: Frequent direct writes to `global_position` / `grid_pos` create temporary divergence; if repair calls are missed, gameplay logic may act on wrong occupancy.
  - Evidence: `EnemyManager` sets `enemy.global_position` then registers occupancy; movement tweens write `global_position` per-frame. See [scripts/core/enemy/EnemyManager.gd] and [scripts/core/movement/PlayerMovement.gd].

3. Async windows remain large
  - Risk: `ActionQueue`'s execute/completed split and deferred syncs (call_deferred) allow other systems to mutate core state mid-action, producing hard-to-reproduce bugs.
  - Evidence: `godot_debug_output.txt` shows `ActionQueue` awaiting `action.execute()` and then `action.completed`. [godot_debug_output.txt]

4. Inconsistent handling of `stale_snapshot`
  - Risk: Callers may ignore or mishandle `stale_snapshot`, leading to silent failures or UI desync.
  - Evidence: `CardAction` logs but does not show universal handling of stale return codes; UI code and higher-level gameplay flows need to handle this explicitly.

5. Partial repair strategy
  - Risk: Repair is explicit and thus must be called from many code paths (spawn, setup, begin_turn). If a path forgets repair, occupancy or room membership may be incorrect.
  - Evidence: `MapManagerCore.repair_actor_room(actor)` documented as the only remaining repair writer; calls are present in `EnemyManager` spawn/setup and `PlayerMovement.begin_turn()` but may be missing in other ad-hoc spawns.

Suggested next engineering tasks (prioritized)
- Short-term (low friction)
  1. Surface and standardize `stale_snapshot` handling: return an enum and add UI hooks to show "target moved" or offer retry.
  2. Add debug logging for snapshot occ_version capture vs execute-time to quantify mismatch rates.

- Medium-term
  1. Audit codebase for direct `global_position` / `grid_pos` writes; refactor to a single helper that performs write+occupancy update atomically.
  2. Reduce ActionQueue async window by encouraging `execute()` to return a final result instead of splitting across `action.completed` where possible.

- Long-term
  1. Expand snapshot model to movement and attack actions or create a clear boundary where non-snapshotted actions are accepted and documented.
  2. Add unit/integration tests that simulate concurrent moves and card plays to assert `stale_snapshot` behavior and expected UX outcomes.



Async Execution Boundaries — Observed Runtime Points

Purpose
- Document all observed async boundaries, where reads may become stale, and the concrete places in code to inspect when debugging race conditions.

Async boundary types observed
- `await` (cooperative yield) — Godot 4 `await` on signals and timers
- `call_deferred()` — defers execution to the next idle frame
- signals (emitted and awaited by other nodes) — event-driven hops
- `get_tree().create_timer(...).timeout` — timers used with `await` create scheduling windows

Concrete sites (examples + why they matter)
- `CardAction.execute()`
  - Code: `res = await card_system.execute_card_snapshot(card_data, target)`
  - Files: [scripts/core/combat/CardAction.gd](scripts/core/combat/CardAction.gd#L40-L47)
  - Why: awaiting a snapshot-execution hop is deliberate: it validates `occ_version` at execution-time. However, any local reads performed before this `await` may be stale; if callers don't handle `stale_snapshot`, the gameplay flow can diverge.

- `ActionQueue.process_next()` (via logs in `godot_debug_output.txt`)
  - Files: [scripts/core/actions/ActionQueue.gd](scripts/core/actions/ActionQueue.gd) and debug trace [godot_debug_output.txt].
  - Observed behavior: ActionQueue `await`s `action.execute()`, then waits for `action.completed` signal, then calls `action.finish()` and emits `action_finished(action, result)`.
  - Why: two async handoffs (`execute()` await + `completed` signal) create windows where other systems can mutate state while the action runs. Examples: an action starting then a different event mutating occupancy before `action.finish()` runs.

- Movement and timers in `PlayerMovement` and tweening
  - Files: [scripts/core/movement/PlayerMovement.gd](scripts/core/movement/PlayerMovement.gd#L150-L180) and timer awaits at [scripts/core/movement/PlayerMovement.gd#L270-L270].
  - Why: movement interpolation uses timers/awaits and tweens. `global_position` changes are written across frames; occupancy updates rely on explicit calls to `OccupancyManager` after movement completes — a missed call or deferred timing can create temporary divergence between `global_position` and occupancy.

- Deferred connect/syncs in room camera and tile highlighter
  - Files: [scripts/world/rooms/room_camera_controller.gd](scripts/world/rooms/room_camera_controller.gd#L52-L70), [scripts/world/rooms/TileHighlighter.gd](scripts/world/rooms/TileHighlighter.gd#L84-L103)
  - Why: `call_deferred("_sync_to_current_room")` is used to align visuals with canonical `active_room_id`; deferred calls mean visuals may read `dungeon.active_room_id` after a frame, possibly after it has changed again.

Signal-based boundaries
- `OccupancyManager.occupancy_changed` (emitted at occupancy mutation) — many listeners re-sync state or UI; listeners may run later or in different object contexts, causing ordering dependencies. [scripts/world/rooms/OccupancyManager.gd#L129-L131]

Where stale reads are most likely (explicit examples)
- Reading `real_target.name` before awaiting `execute_card_snapshot()` in `CardAction.execute()` — the name/identity may change (target removed) after the await. [scripts/core/combat/CardAction.gd#L20-L47]. Classification: stale read.
- `ActionQueue` awaiting `action.execute()` (start) and waiting for `action.completed` (end). Any global state changes between start/end can make results inconsistent relative to the actor's intentions. Classification: async race condition / stale read window.
- Movement interpolation writing `global_position` over many frames while occupancy is only updated on completion — classification: implicit temporal divergence, mitigated by explicit `repair` but still a race if others read occupancy mid-move.

Concrete examples of risk and how they manifest at runtime
- Example 1: Card targets Actor A; `occ_version` captured V1; before execute, player pushes Actor A to another cell (OccupancyManager increments to V2); `execute_card_snapshot()` returns `stale_snapshot` and the action resolves as stale. If the UI or caller ignores stale result and assumes success, game state diverges.
- Example 2: An action `execute()` starts and triggers animation; mid-animation, another system kills target; `action.completed` fires later and `ActionQueue` finishes the action assuming success — inconsistent side-effects may occur.

Debug checklist (where to add instrumentation)
- Log `occ_version` at snapshot capture and at execute-time in `CombatCardSystem`.
- Log `OccupancyManager._version` increments and list of emitters for `occupancy_changed`.
- Add assertion checks in `ActionQueue` to detect when `action.execute()` start and `action.finish()` observe different occupancy or active room values.

Short mitigation suggestions (practical)
- Normalize snapshots: ensure callers of snapshot-based APIs handle `stale_snapshot` explicitly (retry, fail, or resync UI).
- Reduce surface area of deferred writes: route `global_position` -> `OccupancyManager` update in one atomic code path where possible.
- Harden `ActionQueue`: minimize the gap between `execute()` and `completed` by encouraging `execute()` to return final results instead of splitting start/complete across signals unless necessary.



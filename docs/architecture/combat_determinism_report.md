Combat Determinism Report — Snapshot vs Live Execution

Executive summary
- Combat determinism is partially implemented: card actions use a snapshot model (captures `occ_version` and other context at queue time) and are validated at execution. Other action types (movement, direct attacks) use live state. Mixed usage results in deterministic behavior for many card executions, but overall combat determinism is not guaranteed.

Snapshot flow (what actually happens)
1. `CombatCardSystem.queue_card_action()` creates a `TargetSnapshot` containing: the `target` reference, `cell`, `room_id`, and `occ_version` (monotonic occupancy version at snapshot time). [docs/refactor_state_ownership.md#L20-L21]
2. A `CardAction` instance is enqueued and later executed by `ActionQueue`.
3. `CardAction.execute()` awaits `CombatCardSystem.execute_card_snapshot(card_data, target_snapshot)` which validates `occ_version` and either executes deterministically or returns `stale_snapshot`. [scripts/core/combat/CardAction.gd#L40-L47]

Validation behavior
- When `execute_card_snapshot()` sees the `occ_version` mismatch, it returns `stale_snapshot` rather than implicitly repairing. This preserves deterministic expectation (an old snapshot does not silently mutate live state) but pushes complexity to callers.
- `CardAction` currently awaits and logs `stale_snapshot` results, but callers in some UI flows may not surface `stale_snapshot` robustly.

Determinism guarantees (observed)
- Guaranteed: If no intervening writes to occupancy/room/target occur between snapshot capture and execute-time, card execution is deterministic given the snapshot.
- Not guaranteed: Concurrency windows exist where other systems may mutate occupancy, room, or actor state (movement tweens, enemy spawn, external repair calls). If mutations happen, `stale_snapshot` is returned and different outcomes occur at runtime depending on how callers handle this.

Entry points and coverage
- Player card plays: use `CombatCardSystem.queue_card_action()` and thus use snapshot enforcement.
- Enemy abilities: repository evidence is sparse that enemy abilities currently use the same snapshot flow; many enemy decisions call `begin_turn()` and read live occupancy after explicit `repair`. If enemies do not use snapshot capture, enemy-driven effects remain non-deterministic relative to player cards.

Mismatch scenarios and classification
- Dual-model divergence: Player card (snapshot) vs enemy movement (live) — if enemy moves after the player queued a card, player sees `stale_snapshot`. Classification: dual-model divergence.
- Stale reads: logs show `CardAction` prints `real_target.name` before awaiting snapshot execution — UI strings or pre-effect logic may therefore be stale. Classification: stale read.
- Async race condition: `ActionQueue`'s split `await execute()` + `await action.completed` window allows other systems to mutate state while action runs. Classification: async race condition.

Concrete code pointers to inspect
- Snapshot capture: `CombatCardSystem.queue_card_action()` documented in [docs/refactor_state_ownership.md#L20-L21].
- Snapshot execution: `CombatCardSystem.execute_card_snapshot()` referenced by [scripts/core/combat/CardAction.gd#L40-L47].
- Action orchestration: [scripts/core/actions/ActionQueue.gd] and `godot_debug_output.txt` for observed start/complete traces.

Operational impacts
- Visible player experience: sometimes cards appear to "fail" (stale) because the target moved; the game does not attempt a transparent retry — instead it returns a `stale_snapshot` outcome which may be superficially presented as a failed cast.
- Testing: unit/integration tests need to either freeze external writers during snapshot tests or use controlled repair/resync flows to reproduce deterministic outcomes.

Recommendations (minimal, tactical)
- Make `stale_snapshot` surface to calling UI code with a clear enum and reason (moved/removed/occ_version_mismatch) so UX can show "Target moved" and optionally prompt for retry.
- Consider aligning enemy action decision paths to capture snapshots when queueing destructive effects, or convert more action types to snapshot flows.
- Add instrumentation: log snapshot capture `occ_version` and execution `occ_version` in debug builds to quantify stale rates.



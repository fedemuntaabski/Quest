# Action Queue System

## Purpose
`ActionQueue` is the runtime serialization point for turn actions. It ensures only one action is actively executing at a time.

## Lifecycle
1. A caller creates a `BaseAction` subclass such as `MoveAction`, `AttackAction`, `WaitAction`, or `CardAction`.
2. The caller submits the action to `ActionQueue.queue_action()`.
3. If the queue is idle, `process_next()` starts immediately.
4. `ActionQueue` pops the oldest action from the queue.
5. `can_execute()` is checked.
6. `execute()` is called.
7. If the action is asynchronous, `ActionQueue` waits for `action.completed`.
8. `finish()` is called.
9. `action_finished` is emitted.
10. The queue advances to the next action.

## Queue Ownership
`TurnManager` owns the queue as `turn_manager.action_queue`.

It uses the queue to:
- process the current actor’s actions
- detect when actions consume a turn
- move to the next actor after the queue completes a turn-consuming action

## Action Contract
`BaseAction` defines the minimum contract:
- `owner`
- `target`
- `consume_turn`
- `is_complete`
- `can_execute()`
- `execute()`
- `finish()`

Subclasses currently used by the project:
- `MoveAction`
- `AttackAction`
- `WaitAction`
- `CardAction`

## Concurrency Model
There is no parallel execution model.

The queue is strictly sequential:
- one action executes at a time
- the queue blocks on async completion when needed
- the current actor is not advanced until the turn-ending action completes

This makes the queue easy to reason about, but it also means one stuck action can stall the whole turn loop.

## Re-Entrancy And Mutation Risks
1. `ActionQueue.process_next()` is recursively called after each action finishes. That is acceptable for a small queue, but it makes the control flow harder to reason about when actions enqueue more actions during execution.
2. `TurnManager._on_action_finished()` can call `end_turn()` while an action resolution path is still cleaning up.
3. `CardAction.execute()` awaits `CombatCardSystem.execute_card()`, which itself may await runtime effects. That creates nested async boundaries.
4. `Enemy.begin_turn()` can enqueue a wait, attack, or move action during its own turn method, which means actor logic mutates the same queue that is driving it.

## Current Weak Points
- No dedicated cancellation API exists.
- No transaction or atomic rollback exists for the action queue itself.
- `ActionQueue.queue_action()` does not deduplicate or reorder actions.
- `ActionQueue.clear()` drops queued actions immediately without emitting per-action cancellation events.
- If an action begins execution with stale references, the queue will only discover the problem inside that action’s `can_execute()` or `execute()` path.

## Improvement Suggestions
1. Add explicit action cancellation and cancellation reasons.
2. Introduce a stable action ID and sequence number so logs and debugging can trace ordering deterministically.
3. Make queue execution a loop-based state machine instead of recursive re-entry.
4. Add a single atomic completion hook that distinguishes between `executed`, `skipped`, `failed`, and `cancelled`.
5. Make actions immutable after queueing. Their owner, target, and execution parameters should not change while waiting.
6. Move queue clearing into a controlled shutdown path that informs the current actor and logs dropped actions.

## Needs Verification In Code
- Whether any action subclass still mutates turn state outside `finish()`.
- Whether any caller queues actions from outside the owning actor’s turn and expects them to execute immediately.

# Determinism Hardening Status

## Completed This Session
- Added action execution-state tokens to `BaseAction` and surfaced queue-level drift detection in `ActionQueue`.
- Standardized combat validation through shared helpers in `CombatComponent` and `CombatCardSystem`.
- Made `CardAction` and `MoveAction` report structured failure reasons.
- Added snapshot-aware enemy attack queueing in `Enemy` and snapshot-aware movement queueing in `PlayerMovement` and `Enemy`.
- Removed the remaining hot-path repair call from `CombatCardSystem.queue_card_action()`.

## Behavioral Changes
- `ActionQueue` now annotates results when state changes during an action run.
- Card failures now return consistent reasons through shared validation.
- Enemy attacks and movement now carry queue-time snapshots so stale occupancy can be detected before execution.
- Card queueing no longer performs implicit target repair before snapshot capture.

## Notes
- Gameplay flow remains intact.
- The current work only adds observation, validation unification, and narrower snapshot discipline.
- Explicit repair remains in setup/turn-start paths.

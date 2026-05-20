# Determinism Hardening Files

## Files Updated
- `scripts/core/actions/BaseAction.gd` - added execution-state token hook.
- `scripts/core/actions/ActionQueue.gd` - added token capture/comparison and drift annotations.
- `scripts/core/combat/CardAction.gd` - added structured failure reasons and execution-state token data.
- `scripts/core/actions/MoveAction.gd` - added snapshot-aware movement validation.
- `scripts/core/combat/AttackAction.gd` - added snapshot-aware validation support.
- `scripts/core/combat/CombatComponent.gd` - added shared attack validation helper.
- `scripts/core/combat/CombatCardSystem.gd` - added shared card validation helper and removed hot-path repair before snapshotting.
- `scripts/core/movement/PlayerMovement.gd` - queue-time snapshot capture for move actions.
- `scripts/core/enemy/Enemy.gd` - queue-time snapshot capture for attack and move actions.

## Files Read For Context
- `docs/architecture/async_execution_boundaries.md`
- `docs/architecture/combat_determinism_report.md`
- `docs/architecture/refactor_gap_analysis.md`
- `docs/architecture/runtime_state_model.md`
- `docs/architecture/state_ownership_matrix.md`
- `scripts/world/rooms/MapManagerCore.gd`
- `scripts/world/rooms/room_system.gd`
- `scripts/core/effects/EffectApplier.gd`

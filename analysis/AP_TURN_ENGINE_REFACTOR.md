# AP Turn Engine Refactor — Phase 1

**Branch:** `refactor/ap-turn-engine` (from `feature/save-slots-and-xcom-movement`)
**Status:** Implemented, not yet manually tested in-editor.

## Goal

Replace the ToME-style cell-by-cell movement/turn system with an XCOM/Star Wars-style
Action Point (AP) engine. Before this refactor, every queued action (one cell of
movement, one attack, one card) ended the actor's turn immediately
(`BaseAction.consume_turn = true` unconditionally → `TurnManager._on_action_finished()`
always called `end_turn()`). Walking 5 cells cost 5 full turn-cycles, with enemies
acting between every single step.

## Design decisions (confirmed with user mid-session)

- **Move cost is distance-scaled**, not flat: `CharacterStats.move_range_per_ap`
  (default `3`) converts path length into AP cost via
  `ap_cost = ceil(steps / move_range_per_ap)`.
- **Enemies get real `max_ap = 2`** (same as the player), not capped at 1. This
  required splitting the enemy AI's single-decision-per-turn function into a
  re-enterable loop so an enemy can chain two actions in one turn (e.g. move then
  attack) without double-ticking turn-start status effects (poison, buffs).
- Attacks and card plays cost a flat **1 AP** each.
- A turn ends when `current_ap == 0` **or** the actor explicitly passes via a new
  "Pasar Turno" HUD button.

## Key architectural findings that drove the design

1. **Turn-end choke point**: `TurnManager._on_action_finished()`
   (`scripts/core/actions/TurnManager.gd`) is the single place that decides whether a
   turn ends. It became AP-aware instead of unconditionally ending on any action.
2. **No AP infrastructure existed** — added from scratch to `CharacterStats.gd`,
   mirroring the existing `max_hp`/`current_hp`/`hp_changed` pattern.
3. **Occupancy/animation conflict**: `OccupancyManager._update_actor_cell()` bumps its
   internal `_version` and snaps `actor.grid_pos` on *every* call. The old
   `PlayerMovement._force_step_complete()` called `map_manager.update_actor_cell()` on
   every single step (unlike `Enemy`, which never did). Reusing the old per-step
   machinery naively for a multi-cell atomic move would have double/triple-bumped
   occupancy mid-path instead of reserving the destination once, atomically, up front.
   Fixed by stripping that call from `PlayerMovement` (bringing it in line with
   `Enemy`) and adding a new visual-only multi-step animator that never touches
   occupancy mid-path.
4. **No End Turn / "Pasar Turno" control existed anywhere** in the UI — added, with a
   manual `.tscn` scene edit (no placeholder node existed).
5. **Enemy AI was single-decision-per-turn by construction**:
   `EnemyTurnPolicy.decide()` bundled a once-per-turn status tick
   (`status_component.process_turn_start`, must run exactly once) together with the
   repeatable move/attack decision logic in one function. Split into
   `begin_turn_setup()` (once per turn) + `decide_action()` (repeatable) so an enemy
   can safely act more than once per turn.
6. **Path-preview highlighting (`TileHighlighter`)** was confirmed fully independent —
   it computes its own preview path from hover events and never reads
   `PlayerMovement.current_path`. Safe to delete the drain loop without touching it.

## Changes by file

### 1. `scripts/core/stats/CharacterStats.gd`
Added `ap_changed` signal, `max_ap`/`current_ap` (default 2), `move_range_per_ap`
(default 3), and `refill_ap()` / `spend_ap(amount)` / `has_ap(amount)` methods
mirroring the HP pattern. Same defaults apply to player and enemies — no per-actor
override.

### 2. `scripts/core/actions/BaseAction.gd`
Added `ap_cost: int = 1`. **Repurposed `consume_turn`**: previously meant "this action
ends the turn"; now means "force-end the turn unconditionally regardless of remaining
AP" — used only by `WaitAction` and the `ActionQueue` failure branch (blocked/stale
actions still cost no AP and don't end the turn). Normal AP-costing actions
(`MoveAction`, `AttackAction`, `CardAction`) set it `false`.

### 3. `scripts/core/actions/MoveAction.gd` (full redesign)
Constructor now takes a full `path: Array[Vector2i]` instead of a single target cell.
`ap_cost` is computed internally from path length and the owner's
`move_range_per_ap`. `can_execute()` re-validates the whole path (not just the final
cell) for atomicity against races, plus an AP-sufficiency check. `execute()`:
1. Reserves the final cell atomically via one `OccupancyManager.update_actor_cell()`
   call (one `_version` bump) *before* any animation frame plays.
2. Spends the computed AP cost.
3. Animates through the whole path via the new visual-only stepper.

### 4. `scripts/core/movement/MovementStepService.gd`
Added `animate_actor_through_path(actor, path, map_manager)` — walks all path cells
using the existing `begin_step_move`/`wait_for_step` per-cell animation contract, but
deliberately never calls `map_manager.update_actor_cell()` mid-path (occupancy was
already reserved once, up front, by `MoveAction`). The original single-step
`move_actor_one_step()` was left untouched (still used by `EffectApplier`'s
dash/knockback effects, out of scope here).

### 5. `scripts/core/movement/PlayerMovement.gd`
- Deleted the per-frame path-drain loop in `_physics_process()`.
- Deleted `current_path` field and `set_path()` method entirely.
- `request_path_to_cell()` / `request_path_to_adjacent()` now compute the path once
  and hand it straight to `turn_bridge.request_move_path()`.
- `request_move(dir)` (keyboard arrow keys) now builds a trivial 2-cell path through
  the same pipeline — same feel as before, 1 keypress = 1 cell, 1 AP.
- `cancel_movement()` became a no-op (multi-cell moves are atomic/uninterruptible once
  queued — kept only so its existing call sites don't need touching).
- Removed the per-step `map_manager.update_actor_cell()` call from
  `_force_step_complete()` (see finding #3 above).

### 6. `scripts/core/movement/PlayerMovementTurnBridge.gd`
Replaced single-cell `request_move(dir)` with `request_move_path(path)`, which builds
one `MoveAction` for the whole path and queues it once.

### 7. `scripts/core/enemy/EnemyTurnPolicy.gd`
Split `decide()` into:
- `begin_turn_setup(enemy)` — room repair + turn-start status tick, runs exactly once
  per turn.
- `decide_action(enemy)` — the repeatable move/attack/wait decision, safe to call
  multiple times per turn as AP allows.

### 8. `scripts/core/enemy/Enemy.gd`
`begin_turn()` now calls `EnemyTurnPolicy.begin_turn_setup()` once, then
`_take_next_action()`. Added `request_next_action(tm)` — called by `TurnManager` when
the enemy still has AP after an action resolves, re-invoking only the repeatable
decision step (not the once-per-turn setup). `_queue_move_action()` updated for the
new `MoveAction(owner, map_manager, path, snapshot)` constructor.

### 9. `scripts/core/actions/TurnManager.gd`
- Added `_get_actor_stats(actor)` — duck-typed accessor for an actor's
  `CharacterStats` (via `.stats` or `.get_combat_component().stats`).
- `_begin_actor_turn()` now calls `stats.refill_ap()` before `begin_turn()`.
- Rewrote `_on_action_finished()`: force-end (via `consume_turn`) still ends
  immediately; otherwise checks `current_ap` — ends the turn at 0, otherwise calls
  `current_actor.request_next_action(self)` if the actor supports it (enemies), or
  does nothing for player-like actors (the existing input-driven pipeline already
  permits the next click/attack/card once AP remains).
- Added `request_pass_turn(requesting_actor)` — explicit "Pasar Turno" entry point,
  only usable by the actor whose turn is currently active while the queue is idle.

### 10–11. `scripts/core/combat/AttackAction.gd`, `CardAction.gd`
Both set `consume_turn = false`. `AttackAction` validates AP in `can_execute()` and
spends it in `execute()` after the attack resolves.

### 12. `scripts/core/combat/CombatCardSystem.gd`
AP validated in `_compute_card_validation()` right after the existing cooldown gate;
AP spent in `_finalize_card_execution()` alongside `card_manager.start_cooldown()`.

### 13. `scripts/core/cards/CardSystemController.gd`
Added `"insufficient_ap" → "Sin puntos de acción"` to the hotbar's human-readable
playability-reason mapping.

### 14–16. HUD (`scripts/ui/hud/`)
- `StatPanelUI.gd`: added `update_ap(current, max)`, wired into `update_stats()`.
- `HUDController.gd`: binds `CharacterStats.ap_changed`, initializes the new turn
  button controller.
- `TurnButtonController.gd` (new file): mirrors `PotionController`'s pattern — wires
  the End Turn button's `pressed` signal to
  `TurnManager.request_pass_turn(player)`, and disables the button when it isn't the
  player's turn.

### 17. `scenes/HUD.tscn`
Manual scene edit — added `StatRowAP` (HBoxContainer) with `LabelAP` and
`EndTurnButton` as a sibling of the existing `StatRowPotion`, under
`Control/StatsHUD/MarginContainer/StatPanelUI`. No new icon (`StatIcon.gd`'s icon-type
enum is hardcoded with no generic fallback — adding one was judged out of scope for a
cosmetic-only addition).

## Verification performed

- Grepped for leftover references to removed APIs (`current_path`, `.set_path(`,
  old single-arg `MoveAction.new(`, old `EnemyTurnPolicy.decide(`, old single-cell
  `request_move(dir)` on the bridge) — all clean, only the expected updated call
  sites remain.
- Grepped `consume_turn = true/false` across `scripts/core` — matches the plan
  exactly (`MoveAction`/`AttackAction`/`CardAction` → `false`, `WaitAction` →
  `true`, nothing else touched).
- Confirmed `CombatComponent.stats` field name used in the new AP hooks matches its
  actual declaration.
- Fixed several GDScript strict-typing errors surfaced live by the editor's
  diagnostics during editing (`max()`/`.back()` returning untyped `Variant` — replaced
  with `maxi()` and explicit `Vector2i` typing).

## Not yet done

- No in-editor manual test run (`godot --path .`) — should verify:
  1. A distant click walks the whole path in one animation and the HUD AP counter
     drops by the computed cost (not to 0).
  2. An adjacent enemy with 2 AP can move+attack or attack twice in one turn without
     visibly double-ticking status effect durations.
  3. The "Pasar Turno" button correctly ends the turn early and is disabled outside
     the player's turn.

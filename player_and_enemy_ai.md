# Player And Enemy AI

## Scope
This document covers player input-to-action behavior and enemy decision flow. There is no separate enemy AI script in the current tree; enemy behavior is implemented directly on `Enemy.gd`.

## PlayerActionController Responsibilities
`PlayerActionController` is the player-side decision layer.

It owns:
- keyboard hotbar selection
- mouse click handling
- mouse hover targeting
- basic attack fallback
- movement path selection
- hover cleanup and targeting reset

It does not own:
- card data
- turn sequencing
- room generation
- enemy spawning

## Player Input Flow
1. `InputHandler` forwards the event.
2. `PlayerActionController` checks whether input is allowed.
3. The controller resolves the current mouse cell.
4. If an active card exists, it tries to queue a card action.
5. If no active card exists, it may attack, move, or cancel movement.
6. On successful play, it clears targeting and resets the hotbar selection.

Important detail:
- Card click flow now returns early after card handling. That prevents silent fallback to basic attack or movement in the selected-card path.

## Differences Between Player And Enemy Initialization

### Player
`PlayerMovement._ready()` registers the player with the map, creates or finds a combat component, and sets up `PlayerActionController`.

The player also:
- connects to `GameStateManager` for movement cancellation
- registers with the global player stats system
- begins turn participation through `begin_turn()`

### Enemy
`EnemyManager.spawn_enemies()` instantiates enemy scenes, assigns room IDs, applies enemy data, and calls `enemy.setup()` only after the node is in the tree.

Each enemy then:
- registers with `TurnManager`
- captures player references for delayed use
- listens for its own defeat signal

## Enemy Turn Logic And Decision Flow
`Enemy.begin_turn()` is the current AI implementation.

Decision order:
1. Apply turn-start stat modifiers.
2. Apply statuses through `StatusRuntime.process_turn_start()`.
3. If a status blocks action, queue a wait action or skip.
4. If map/player/combat references are missing, queue a wait action.
5. If the enemy is not in the active dungeon room, skip the turn.
6. Sync grid state.
7. Attack the player if in range and room engagement permits it.
8. Pathfind toward the player if attack is not available.
9. Queue wait if nothing else is possible.

## Inconsistencies And Failure Modes

### Off-Room Skips
Enemies no longer just wait when they are outside the active room. They call `_skip_turn("off_room")`, which defers `TurnManager.end_turn()`.

Risk:
- If room state and enemy room assignment desync, the enemy can be skipped even though it should still be active.

### Targeting Mismatches
1. Player card targeting uses `MapManager.get_actor_at_cell()` and room engagement checks.
2. Enemy targeting uses `map_manager.can_actors_engage()` in `CombatComponent.can_attack()`.
3. `MapManagerCore` can repair room IDs from grid cells, so a target may appear valid in one path and invalid in another if room state is incomplete.

### Initialization Drift
1. The player registers occupancy before all downstream systems are guaranteed to be ready.
2. Enemy setup happens after instantiation, which is correct, but it depends on the `TurnManager` and `MapManager` being initialized first.
3. `GameStateManager` and `HUDController` are bound through deferred setup paths, so any early turn or input call can hit a partially initialized graph.

## Concrete Improvement Opportunities
1. Move both player and enemy decision outputs to explicit intent objects before queueing actions.
2. Make room assignment final at spawn/movement completion and avoid repairing it during combat unless recovery is required.
3. Standardize target validation so player cards, basic attacks, and enemy attacks all consult the same helper and return the same failure reason structure.
4. Separate “cannot act because state is paused” from “cannot act because this actor is not active” in logs and diagnostics.
5. Cache stable references for HUD and combat components rather than re-looking them up in each turn.

## Needs Verification In Code
- Whether any player action path still falls back to non-card behavior after a selected-card failure in corner cases.
- Whether any enemy variant overrides `begin_turn()` or adds additional target logic elsewhere.

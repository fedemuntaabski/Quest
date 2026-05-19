# Combat System

## Scope
This document covers the current combat pipeline from player input to action execution, including target selection, card resolution, action queue flow, and enemy turn logic.

## Combat Pipeline

### 1. Input Handling
`InputHandler` forwards mouse and keyboard events to `PlayerActionController`. The controller first checks `GameStateManager.can_process_input()` and `PlayerMovement.can_accept_input()`.

Key runtime rule:
- If the game is not active, input is ignored.
- If the player does not own the turn, input is ignored.
- If the action queue is busy, the player cannot issue new movement or selection changes.

### 2. Target Selection
`PlayerActionController._handle_mouse_click()` converts the current mouse position into a grid cell using `MapManager`. It then resolves an actor with `map_manager.get_actor_at_cell()`.

Target cases:
- Self-target card: click must be on the player cell.
- Enemy-target card: click must resolve to an enemy combat target.
- No active card: the controller falls back to movement, attack, or cancellation.

`CardTargeting` and `CombatComponent` both use grid cell resolution. `CardTargeting.is_valid_target()` also checks room engagement through `MapManager.can_actors_engage()`.

### 3. Card System Execution
`CardSystemController` creates and initializes `CardManager` and `CombatCardSystem` for the player.

`CardManager` owns:
- equipped cards
- active slot index
- cooldowns
- deck, draw pile, and discard pile

`CombatCardSystem` owns:
- card play validation
- queueing card actions
- resolving card effects
- starting cooldowns
- emitting play/failure events

### 4. Action Queue Flow
When a card is accepted, `CombatCardSystem.queue_card_action()` creates a `CardAction` and sends it to `TurnManager.action_queue`.

Queue behavior:
- `ActionQueue.queue_action()` appends to a FIFO list.
- `ActionQueue.process_next()` executes only one action at a time.
- If the action is not complete after `execute()`, the queue waits for `completed`.
- After completion, `finish()` is called and `action_finished` is emitted.
- `TurnManager._on_action_finished()` ends the current actor turn if the action consumes a turn.

### 5. Resolution
`CardAction.execute()` awaits `CombatCardSystem.execute_card()`.

`CombatCardSystem.execute_card()` then:
- validates the card and target again
- resolves effects with `CardResolver.resolve_card()`
- shows player roll feedback in the HUD when applicable
- applies damage or miss feedback
- applies runtime movement/status effects through `EffectApplier`
- starts card cooldown
- emits `card_played`

`CardResolver` aggregates effect output into a single summary dictionary. If a card has no effects, it falls back to a damage effect.

### 6. Enemy Turn Logic
Enemy combat decisions are implemented in `Enemy.begin_turn()` rather than a separate AI file.

Current enemy turn sequence:
1. Apply runtime stat modifiers.
2. Process status start-of-turn effects through `StatusRuntime.process_turn_start()`.
3. If a status prevents acting, enqueue a wait or skip.
4. If map, player, or combat state is missing, wait.
5. If the enemy is not in its assigned room, skip the turn.
6. Sync grid state.
7. Attack if in range and room engagement permits it.
8. Otherwise pathfind toward an adjacent cell near the player.
9. Otherwise queue a wait action.

## Weak Points

### NULL And Missing Dependency Risks
1. `CombatCardSystem.queue_card_action()` rejects if `turn_manager`, `action_queue`, or `card` is null.
2. `CombatCardSystem.execute_card()` rejects if target resolution fails or the target actor is invalid.
3. `CombatComponent.setup()` can create a fallback `CharacterStats` node if stats are missing. That prevents a crash, but it can mask a scene wiring error.
4. `MapManagerCore` may repair room IDs from grid cells. If that repair fails, a valid target can be rejected as if it were out of room.

### Lookup Risks
1. `PlayerActionController` relies on `map_manager.get_actor_at_cell()` and `card_manager.get_active_card()` at click time.
2. `Enemy.begin_turn()` relies on `map_manager`, `player`, `combat_component`, and `dungeon_generator` all being ready.
3. `CombatComponent._resolve_target_component()` uses method checks and child lookups that can fail silently if the scene structure changes.

### Timing Risks
1. `EffectApplier` awaits movement effects during card resolution.
2. `ActionQueue` also awaits completion for async actions.
3. `TurnManager` relies on these waits to finish before it advances the actor loop.

This means the combat pipeline is sequential, but its implementation is split across several async boundaries.

## Determinism And Scalability Improvements
1. Give every card action a single canonical validation step before queueing and a single canonical execution step inside the queue. Right now validation is duplicated across input, card system, and component layers.
2. Replace ad hoc target lookup with a dedicated target snapshot passed into the queue action. That would reduce lookup drift between click time and execution time.
3. Move runtime effect application into an explicit transaction boundary with success/failure reporting. `EffectContext` already moves in this direction, but the contract is not yet uniform across all effect types.
4. Make enemy decision output deterministic by recording the chosen turn intent before queueing actions. This matters if room or occupancy state changes mid-resolution.
5. Reduce direct scene-path lookups for `HUDController`, `CombatComponent`, and `StatusComponent` by using stable registration or cached references.
6. Make turn progression independent of incidental queue busy checks. Busy state should be a result of the queue, not a second rule source.

## Needs Verification In Code
- Whether any card effects still bypass `EffectApplier` and mutate state directly.
- Whether any enemy scene variants add extra combat state not visible in `Enemy.gd`.
- Whether the card target selection path can still fall back to basic attack after a selected-card rejection in all cases.

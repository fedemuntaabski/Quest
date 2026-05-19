# Architecture Overview

## Purpose
This project is a single-player, turn-based dungeon crawler built around a small set of runtime owners:
- `Main2d` orchestrates run state, rewards, victory, and death.
- `GameStateManager` gates input, turns, and pause/reward/victory/death transitions.
- `MapManager` and the dungeon runtime own grid, rooms, occupancy, and pathfinding helpers.
- `TurnManager` and `ActionQueue` serialize turn actions.
- `PlayerActionController`, `CombatCardSystem`, `Enemy`, and `EnemyManager` own combat behavior.
- `HUDController` reflects the current runtime state back to the player.

## High-Level Runtime Flow
1. `Main2d._ready()` bootstraps managers, binds signals, and sets up the run.
2. `MapManager._ready()` generates the dungeon, constructs helper nodes, and starts enemy/turn setup.
3. `DungeonGenerator.generate_dungeon()` builds rooms, corridors, and room metadata.
4. `TurnManager.start()` begins the actor loop and drives `begin_turn()` on each actor.
5. `PlayerActionController` consumes player input and routes it into movement, attack, or card actions.
6. `CombatCardSystem` validates, queues, and resolves card actions.
7. `Enemy.begin_turn()` decides whether an enemy waits, moves, attacks, or skips because of state/status/room rules.
8. `HUDController` listens to card, room, and reward signals and updates the visible UI.

## Subsystems And Responsibilities

### Run Orchestration
`Main2d` is the top-level run coordinator. It tracks visited rooms, counters for enemies and rooms cleared, reward state, death state, and victory state. It also decides when to request rewards and when to transition to victory or death overlays.

### Global State Gate
`GameStateManager` owns the authoritative state machine: `ACTIVE`, `PAUSED`, `DEAD`, `VICTORY`, and `REWARD`. It also controls `get_tree().paused`. The practical effect is that input and turn processing are only valid while the game is `ACTIVE`.

### Dungeon And Room Ownership
`DungeonGenerator` stores `room_infos`, `floor_cells`, `wall_cells`, and `active_room_id`. `DungeonLayoutGenerator` creates the room graph, while `DungeonGraph` stores adjacency and validates connectivity. `RoomSystem` mirrors active room changes from player position and can intentionally accept a non-adjacent sync when correcting room state from the grid.

### Grid And Occupancy
`MapManagerCore` wraps grid conversion, walkability, room lookup, and actor-room repair logic. `OccupancyManager` stores cell ownership and blocking semantics. Runtime movement and combat both depend on these two layers for consistent target lookup.

### Turn And Action Ownership
`TurnManager` serializes actors. Each actor’s `begin_turn()` may enqueue actions into `ActionQueue`. `ActionQueue` executes those actions sequentially and emits `action_finished` after each one. There is no parallel action model.

### Combat Ownership
`PlayerActionController` is the player-facing entry point for mouse and keyboard actions. It delegates card handling to `CardSystemController` and `CombatCardSystem`. `EnemyManager` spawns enemies and registers them with the turn system. Each `Enemy` implements its own turn logic in `begin_turn()`.

### UI Ownership
`HUDController` is the central UI hub for the hotbar, reward overlay, tooltip, room label, enemy count, and potion control. It binds to `CardManager`, `GameStateManager`, and reward signals rather than reading game state directly from scattered nodes.

## Data Flow

### Input -> Gameplay
`InputHandler` forwards mouse and keyboard events to `PlayerActionController`. The controller first checks that the game is active and that the player currently owns the turn. It then converts the current mouse position into a grid cell, resolves the target actor, and decides between card play, basic attack, movement, or cancellation.

### Gameplay -> Combat
If a card is selected, `PlayerActionController` sends the action to `CombatCardSystem`. The system checks card cooldowns, target validity, target health, and room engagement rules before queueing a `CardAction` into `TurnManager.action_queue`.

### Combat -> Map
Combat and movement both consult `MapManagerCore` and `OccupancyManager`. Card effects can apply movement or status changes through `EffectApplier`, which may update actor grid cells and status state. Movement actions also update occupancy after step completion.

### Map -> UI
`RoomSystem` and `DungeonGenerator` emit room changes that `Main2d` and `HUDController` reflect in the room label and enemy counter. `CardManager` emits UI payload updates that refresh the hotbar and card panel. Reward state opens and closes through `GameStateManager` signals.

## Key Dependencies
- `Main2d` depends on `MapManager`, `HUDController`, `EnemyManager`, `GameStateManager`, and `CardRewardManager`.
- `MapManager` depends on `DungeonGenerator`, `MapManagerCore`, `OccupancyManager`, `EnemyManager`, `TurnManager`, and `MapNavigationHelper`.
- `PlayerActionController` depends on `CardSystemController`, `CardManager`, `CombatCardSystem`, `TurnManager`, and `GameStateManager`.
- `CombatCardSystem` depends on `CardManager`, `CombatComponent`, `MapManager`, and `TurnManager`.
- `EnemyManager` depends on `DungeonGenerator`, `TurnManager`, and enemy resources.

## Coupling Risks
1. `Main2d`, `HUDController`, and `GameStateManager` are tightly coupled through signal chains and pause semantics. A mismatch in state transitions can leave UI visible while gameplay is locked, or vice versa.
2. `MapManagerCore` repairs missing room data on demand. That reduces hard failures, but it also hides invalid state by inferring room ownership from grid cells.
3. `TurnManager` assumes actors stay registered in a stable order. If an actor is removed or added mid-turn, sequencing can become hard to reason about.
4. `CombatCardSystem`, `EffectApplier`, and `StatusRuntime` all touch runtime state. That gives flexibility, but it increases the chance of hidden side effects during card resolution.
5. Room ownership exists in multiple places: `DungeonGenerator.active_room_id`, `RoomSystem.active_room_id`, actor `my_room_id`, and occupancy/grid lookup. That is a coupling risk because the source of truth is not singular.

## What A New Developer Should Remember
- Input is only valid while `GameStateManager` is active and the player owns the turn.
- Room state is derived from generated room rectangles and can be repaired from the player grid when needed.
- Combat is serialized, not concurrent.
- UI is mostly event-driven, not polled.
- Any refactor toward determinism should reduce the number of places that can independently mutate room, turn, or action state.

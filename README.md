# QUEST

2D grid-based roguelike in Godot 4.6. Focus: tactical movement and melee combat.

## Current Status
- Turn-based loop with action queue
- Grid movement + pathfinding
- Occupancy grid for blocking and positions
- Card-driven actions (strength/agility/magic decks) alongside melee combat with hit/dodge/crit and stat scaling
- Dungeon generation + enemy spawning
- Save slots, persistent upgrades, and a run-reward flow (card picks between runs)

## Controls
- Move: WASD / Arrow keys
- Click: move or attack (melee if in range)

## Core Systems (Scripts)
- Turn manager + queue: `scripts/core/actions/TurnManager.gd`, `scripts/core/actions/ActionQueue.gd`
- Actions: `scripts/core/actions/BaseAction.gd`, `scripts/core/actions/MoveAction.gd`, `scripts/core/actions/WaitAction.gd`, `scripts/core/combat/AttackAction.gd`, `scripts/core/combat/CardAction.gd`
- Combat: `scripts/core/combat/CombatResolver.gd`, `scripts/core/combat/CombatCardSystem.gd`, `scripts/core/cards/CardManager.gd`
- Occupancy/map: `scripts/world/rooms/OccupancyManager.gd`, `scripts/world/rooms/MapManager.gd`
- Managers (autoload + locator): `scripts/managers/ManagerLocator.gd`, `scripts/managers/SaveManager.gd`, `scripts/managers/CurrencyManager.gd`, `scripts/managers/SettingsManager.gd`, `scripts/managers/GameStateManager.gd`

See `CLAUDE.md` for full architecture notes.

## Build & Run
Editor:
```bash
godot --path . --editor
```

Play:
```bash
godot --path .
```

## Next
- Ranged/spells, AoE, status effects
- Combat UI feedback
- AI improvements
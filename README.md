# QUEST

2D grid-based roguelike in Godot 4.6. Focus: tactical movement and melee combat.

## Current Status
- Turn-based loop with action queue
- Grid movement + pathfinding
- Occupancy grid for blocking and positions
- Melee combat with hit/dodge/crit and stat scaling
- Dungeon generation + enemy spawning

## Controls
- Move: WASD / Arrow keys
- Click: move or attack (melee if in range)

## Core Systems (Scripts)
- Turn manager: `scripts/TurnManager.gd`
- Actions: `scripts/BaseAction.gd`, `scripts/MoveAction.gd`, `scripts/AttackAction.gd`
- Combat: `scripts/CombatResolver.gd`, `scripts/CombatComponent.gd`
- Occupancy: `scripts/OccupancyManager.gd`
- Map/pathfinding: `scripts/MapManager.gd`, `scripts/map_navigation_helper.gd`

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
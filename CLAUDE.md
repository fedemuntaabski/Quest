# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

QUEST: 2D grid-based tactical roguelike built in Godot 4.6, GDScript only (no C#/.NET), GL Compatibility renderer. Turn-based movement + melee combat with card-driven actions and procedural dungeon generation.

## Commands

No build system, linter, test suite, CI, or export presets exist in this repo. Only real dev commands:

```bash
godot --path . --editor   # open in editor
godot --path .             # run the game
```

If asked to add tests/lint/CI, there is nothing existing to hook into — treat it as new infrastructure, not "run the existing suite."

## Architecture

**Autoloads** (project.godot `[autoload]`):
- `PlayerStats` (scripts/core/stats/PlayerStats.gd) — persistent player base stats (HP/STR/MAG/DEX), active upgrades, runtime `CharacterStats`; emits `stats_changed`/`player_died`.
- `SaveManager` (scripts/managers/SaveManager.gd) — persists progression/upgrades/run cycle/slots to `user://slot_<id>.cfg`.
- `CurrencyManager` (scripts/managers/CurrencyManager.gd) — facade over `SaveManager.gold`, debounced persistence, emits `gold_changed`.
- `ThemeManager` (scripts/core/theme/ThemeManager.gd) — builds reusable `StyleBoxFlat`s for card UI/menus.
- `SettingsManager` (scripts/managers/SettingsManager.gd) — persists audio/display settings to `user://settings.cfg`, emits `settings_changed`/`volume_changed`.

**`ManagerLocator`** (scripts/managers/ManagerLocator.gd) is the central indirection point: wraps autoload access (`get_save_manager`, `get_currency_manager`, `get_player_stats`, `get_settings_manager`) and group-based lookup for singletons that are *not* autoloads (`get_game_state_manager()` via `game_state_manager` group, `get_floating_text_manager()` via group, lazily instantiating if absent). Fetch managers through this rather than raw autoload names or ad-hoc `get_tree().get_first_node_in_group()` calls.

**`GameStateManager`** (scripts/managers/GameStateManager.gd) — scene-instantiated (not an autoload) gameplay state machine: `State` enum ACTIVE/PAUSED/DEAD/VICTORY/REWARD. Other systems call its `can_process_*` helpers to gate logic, and it emits `state_changed`/`pause_requested`/`death_entered`/`victory_entered`/`reward_entered`.

**`MapManager`** (scripts/world/rooms/MapManager.gd) — scene-level owner of the dungeon grid. Owns `OccupancyManager`, `MapManagerCore`, `EnemyManager`; wires a per-scene `TurnManager` in `_ready()` (also triggers dungeon generation). Delegates generation/layout to `scripts/world/dungeon/*` and grid/vision concerns to `scripts/world/rooms/{OccupancyManager,FogOfWarManager,TileHighlighter*}.gd`.

**`TurnManager`** (scripts/core/actions/TurnManager.gd) + **`ActionQueue`** (scripts/core/actions/ActionQueue.gd) — TurnManager registers/unregisters actors and drives turn sequencing; ActionQueue serially executes queued `BaseAction` instances (`MoveAction`, `WaitAction` in core/actions; `AttackAction`, `CardAction` in core/combat), emitting `action_finished(action, result)`.

**`CombatCardSystem`** (scripts/core/combat/CombatCardSystem.gd) — per-actor card validate/queue/execute/finalize (`get_card_validation`, `queue_card_action`; playability itself is `CardManager.can_play_card` in scripts/core/cards/CardManager.gd). Executes via a snapshot (`execute_card_snapshot`) that checks `occ_version` to avoid stale-occupancy races, then resolves through `EffectApplier`/`EffectContext`. Emits `card_played`/`card_failed`.

**`CombatResolver`** (scripts/core/combat/CombatResolver.gd) — stateless static `resolve_attack(...)` wrapping `CombatFormula`, producing a result dict consumed by `CombatComponent` and HUD presentation.

**`Logger`** (scripts/core/utils/Logger.gd) — categorized/leveled logging (`Category`: GENERAL/COMBAT/CARDS/MAP/STATE/ACTIONS/SAVE; `Level`: DEBUG/INFO/WARN/ERROR), replacing raw `print()` calls project-wide. Use it for new diagnostics instead of `print()`.

**Data flow**: `MapManager` wires a per-scene `TurnManager`, which drives actor turns and pushes `BaseAction`s (Move/Wait/Attack/Card) through `ActionQueue` for serial execution. Combat/card actions route through `CombatCardSystem` → `EffectApplier`/`EffectContext` → `CombatResolver`/`CombatFormula` for resolution — all gated by `GameStateManager.can_process_*`.

## Directory layout

- `scripts/core/` — actions, cards, combat, effects, enemy, movement, stats, theme, utils
- `scripts/managers/` — SaveManager, CurrencyManager, SettingsManager, GameStateManager, ManagerLocator
- `scripts/ui/` — card_reward, hud, menus, overlays, visual
- `scripts/world/` — camera, dungeon, rooms
- `resources/` — `.tres` data: `cards/{agility,magic,strength}/*.tres`, `card_library.tres`, `enemies/*.tres`
- `docs/architecture/` and `analysis/` — internal design/refactor notes worth checking for context on in-progress cleanup (`docs/architecture/CAMERA_AND_UI_OVERHAUL.md`; `analysis/Dungeon-Architecture-Overview.md`, `Grid-and-Occupancy-Ownership.md`, `MAP_GENERATION_AUDIT.md`, `MAP_GENERATION_REFACTOR.md`, `Spawning-and-Pacing.md`)


# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

QUEST: 2D grid-based tactical roguelike built in Godot 4.6, GDScript only (no C#/.NET), GL Compatibility renderer. Turn-based movement + melee combat with card-driven actions and procedural dungeon generation. Supports Steam multiplayer (Host/Join via GodotSteam lobbies with auth-ticket validation) alongside the original offline single-player flow.

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
- `SettingsManager` (scripts/managers/SettingsManager.gd) — persists UI SFX volume (click/hover), audio bus volumes (Master/Music/SFX/UI via `AudioServer`), video settings (window mode/resolution/vsync/FPS limit via `DisplayServer`/`Engine.max_fps`, applied automatically in `_ready()`) and gameplay screen-shake intensity to `user://settings.cfg`, emits `settings_changed`/`volume_changed`.
- `SteamManager` (scripts/network/SteamManager.gd) — Steam API init (AppID 480), Steam auth-ticket issuance/validation, `connected_clients`/`pending_clients` peer↔steam_id bookkeeping; owns a child `SteamLobbyManager` (scripts/network/SteamLobbyManager.gd, not an autoload) that handles lobby create/join/leave and `SteamMultiplayerPeer` wiring.
- `FPSOverlay` (scripts/ui/overlays/FPSOverlay.gd) — toggleable FPS counter overlay, driven by `SettingsManager.show_fps_overlay` (Video tab).

**`ManagerLocator`** (scripts/managers/ManagerLocator.gd) is the central indirection point: wraps autoload access (`get_save_manager`, `get_currency_manager`, `get_player_stats`, `get_settings_manager`, `get_steam_manager`) and group-based lookup for singletons that are *not* autoloads (`get_game_state_manager()` via `game_state_manager` group, `get_floating_text_manager()` via group, lazily instantiating if absent). Fetch managers through this rather than raw autoload names or ad-hoc `get_tree().get_first_node_in_group()` calls.

**`GameStateManager`** (scripts/managers/GameStateManager.gd) — scene-instantiated (not an autoload) gameplay state machine: `State` enum ACTIVE/PAUSED/DEAD/VICTORY/REWARD. Other systems call its `can_process_*` helpers to gate logic, and it emits `state_changed`/`pause_requested`/`death_entered`/`victory_entered`/`reward_entered`.

**`MapManager`** (scripts/world/rooms/MapManager.gd) — scene-level owner of the dungeon grid. Owns `OccupancyManager`, `MapManagerCore`, `EnemyManager`; wires a per-scene `TurnManager` in `_ready()` (also triggers dungeon generation). Delegates generation/layout to `scripts/world/dungeon/*` and grid/vision concerns to `scripts/world/rooms/{OccupancyManager,FogOfWarManager,TileHighlighter*}.gd`. Dungeon layout is a **branching graph**, not a strict linear chain: `DungeonGraph` supports treasure/shop/event room templates off the main path (`MAX_CONNECTIONS_PER_ROOM` = 3), room-internal obstacles are placed by `DungeonRoomObstaclePlacer`, and generation is seeded (`dungeon.rng`, propagated to `DungeonTileRenderer`/`EnemySpawnPlanner`/`EnemyDataSelector`) with a retry-on-empty-map fallback. `EnemyDataSelector` skips enemy spawn for treasure/shop room templates. Camera logic (fit-to-room auto-zoom + manual mouse-wheel zoom) lives in `scripts/world/rooms/room_camera_controller.gd`, not a separate `camera/` module (that directory exists but is empty).

**`TurnManager`** (scripts/core/actions/TurnManager.gd) + **`ActionQueue`** (scripts/core/actions/ActionQueue.gd) — TurnManager registers/unregisters actors and drives turn sequencing; ActionQueue serially executes queued `BaseAction` instances (`MoveAction`, `WaitAction` in core/actions; `AttackAction`, `CardAction` in core/combat), emitting `action_finished(action, result)`.

**`CombatCardSystem`** (scripts/core/combat/CombatCardSystem.gd) — per-actor card validate/queue/execute/finalize (`get_card_validation`, `queue_card_action`; playability itself is `CardManager.can_play_card` in scripts/core/cards/CardManager.gd). Executes via a snapshot (`execute_card_snapshot`) that checks `occ_version` to avoid stale-occupancy races, then resolves through `EffectApplier`/`EffectContext`. Emits `card_played`/`card_failed`.

**`CombatResolver`** (scripts/core/combat/CombatResolver.gd) — stateless static `resolve_attack(...)` wrapping `CombatFormula`, producing a result dict consumed by `CombatComponent` and HUD presentation.

**`EffectApplier`/`EffectContext`** (scripts/core/effects/) — transactional executor for a resolved card/attack result's side-effects. `EffectContext` (RefCounted) is a rollback transaction: `begin()` / `register_rollback(callable, args)` / `commit()` / `rollback()` (runs registered undo closures in reverse). `EffectApplier` (Node) applies `result.movement[]` (via `MovementStepService`, directional push or pathed move to a `destination_cell`) then `result.statuses[]` (via `StatusComponent.apply_status`), registering a rollback step per mutation, then commits or rolls back the whole batch atomically. Damage itself is resolved earlier by `CombatResolver`/`CombatFormula`; `EffectApplier` only handles movement + status side-effects.

**`scripts/core/enemy/`** — enemy AI/spawn is decomposed into single-purpose helpers rather than one god-class: `EnemySpawnPlanner` (cell selection with avoidance rules), `EnemySpawnLifecycleService` (spawn/despawn orchestration), `EnemyDataSelector` (picks `resources/enemies/*.tres`, skips treasure/shop rooms), `EnemyProfileApplier` (applies data to instance), `EnemyRewardService` (death rewards), `EnemyTurnPolicy` (simple AI decision: `Decision` enum WAIT/ATTACK/...). `EnemyManager` (owned by `MapManager`) coordinates these.

**`Logger`** (scripts/core/utils/Logger.gd) — categorized/leveled logging (`Category`: GENERAL/COMBAT/CARDS/MAP/STATE/ACTIONS/SAVE/UI/CAMERA/NETWORK; `Level`: DEBUG/INFO/WARN/ERROR), replacing raw `print()` calls project-wide. Use it for new diagnostics instead of `print()`.

**Data flow**: `MapManager` wires a per-scene `TurnManager`, which drives actor turns and pushes `BaseAction`s (Move/Wait/Attack/Card) through `ActionQueue` for serial execution. Combat/card actions route through `CombatCardSystem` → `EffectApplier`/`EffectContext` → `CombatResolver`/`CombatFormula` for resolution — all gated by `GameStateManager.can_process_*`.

**Multiplayer flow**: Main menu "Iniciar Partida" opens `NetworkModeSelect` (scenes/NetworkModeSelect.tscn) with Host/Join/Offline. Host creates a Steam lobby (`SteamLobbyManager.create_lobby`, Friends Only) then picks a save slot via `SaveSlotSelector` (script on `scenes/SlotSelection.tscn`, not its own scene); Join opens the Steam friends overlay and joins via `join_requested`/`lobby_joined`. Joining clients must pass Steam auth-ticket validation (mandatory-blocking, 15s timeout) before `SteamManager.connected_clients` counts them as real players. Both paths land in `scenes/WaitingRoom.tscn` before the host starts `Main2d.tscn`; Offline is unchanged from the original single-player flow (`SlotSelection.tscn` → `Main2d.tscn` directly, no networking).

**`Main2d.tscn` gameplay scene** (scripts/managers/): `Main2d.gd` instantiates/wires `GameStateManager`, `CardRewardManager`, HUD/overlay connections, and exposes its own `MatchState` enum (INIT_MATCH/PLAYER_TURN/ENEMY_TURN/ROOM_CLEARED/VICTORY/DEFEAT) as a turn-aware observer layer over `GameStateManager`/`TurnManager` signals — not a replacement of either. `Main2dDeathHandler.gd` presents the death overlay/run summary. Combat crit is deterministic: `CombatFormula.resolve_damage_multiplier()` grants a guaranteed critical hit when the attacker spends their last AP on the attack (no dice roll).

## Directory layout

- `scripts/core/` — actions, cards, combat, effects, enemy, movement, stats, theme, utils
- `scripts/managers/` — SaveManager, CurrencyManager, SettingsManager, GameStateManager, ManagerLocator, Main2d/Main2dDeathHandler
- `scripts/network/` — SteamManager (autoload), SteamLobbyManager (Steam lobby/matchmaking)
- `scripts/ui/` — card_reward, hud, menus (incl. `MenuTransitionFX.gd` shared fade/scale tween helper used by `BaseMenu`/`BaseSubPanel`), overlays (incl. `FPSOverlay.gd`), visual
- `scripts/world/` — dungeon, rooms (camera logic lives in `rooms/room_camera_controller.gd`; `world/camera/` dir exists but is empty)
- `resources/` — `.tres` data: `cards/{agility,magic,strength}/*.tres`, `card_library.tres`, `enemies/*.tres`, `dungeon/DungeonGenerationConfig_Default.tres`
- `docs/architecture/` and `analysis/` — internal design/refactor notes worth checking for context on in-progress cleanup (`docs/architecture/CAMERA_AND_UI_OVERHAUL.md`; `analysis/Dungeon-Architecture-Overview.md`, `Grid-and-Occupancy-Ownership.md`, `MAP_GENERATION_AUDIT.md`, `MAP_GENERATION_REFACTOR.md`, `DUNGEON_BRANCHING_REFACTOR.md`, `Spawning-and-Pacing.md`, `SETTINGS_MENU_CURRENT_STATE.md`). `analysis/SETTINGS_MENU_REVIEW.md` is stale/superseded by `SETTINGS_MENU_CURRENT_STATE.md` — don't trust it.


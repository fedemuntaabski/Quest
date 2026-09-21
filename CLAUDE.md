# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

QUEST: 2D tactical game built in Godot 4.6, GDScript only (no C#/.NET), GL Compatibility renderer. Currently a menu/character-select/save-slot shell around a minimal AP-turn gameplay scaffold (`Main2d.tscn`): pick a hero, spawn into an empty test grid with real HP/AP stats and a working turn loop. Supports Steam multiplayer (Host/Join via GodotSteam lobbies with auth-ticket validation) alongside the offline single-player flow.

**Removed in `refactor/total-gameplay-wipe`:** the previous card-driven combat, procedural dungeon generation, and enemy AI systems were fully deleted (not archived). If you go looking for `MapManager`, `CombatCardSystem`, `EnemyManager`, `CardData`, dungeon generation, or anything under `scripts/core/{enemy,movement,combat,cards,effects}` / `scripts/world/{rooms,dungeon}`, it no longer exists — don't try to "fix" references to it, and don't assume any design notes about it still apply. Gameplay is being rebuilt from the minimal scaffold up.

## Commands

No build system, linter, test suite, CI, or export presets exist in this repo. Only real dev commands:

```bash
godot --path . --editor   # open in editor
godot --path .             # run the game
```

If asked to add tests/lint/CI, there is nothing existing to hook into — treat it as new infrastructure, not "run the existing suite."

## Architecture

**Autoloads** (project.godot `[autoload]`):
- `PlayerStats` (scripts/core/stats/PlayerStats.gd) — persistent player base stats (HP/STR/MAG/DEX/AP), active upgrades, runtime `CharacterStats`; emits `stats_changed`/`player_died`. `register(stats)` binds a live `CharacterStats` node and re-applies base stats + upgrades onto it via `refresh_stats()`.
- `SaveManager` (scripts/managers/SaveManager.gd) — persists progression/upgrades/run cycle/slots/`selected_character_id` to `user://slot_<id>.cfg`. `apply_character_selection(id)` looks up `CharacterDatabase`, pushes base stats onto `PlayerStats`, and saves.
- `CurrencyManager` (scripts/managers/CurrencyManager.gd) — facade over `SaveManager.gold`, debounced persistence, emits `gold_changed`.
- `ThemeManager` (scripts/core/theme/ThemeManager.gd) — builds reusable `StyleBoxFlat`s for UI/menus.
- `SettingsManager` (scripts/managers/SettingsManager.gd) — persists UI SFX volume (click/hover), audio bus volumes (Master/Music/SFX/UI via `AudioServer`), video settings (window mode/resolution/vsync/FPS limit via `DisplayServer`/`Engine.max_fps`, applied automatically in `_ready()`) and gameplay screen-shake intensity to `user://settings.cfg`, emits `settings_changed`/`volume_changed`.
- `SteamManager` (scripts/network/SteamManager.gd) — Steam API init (AppID 480), Steam auth-ticket issuance/validation, `connected_clients`/`pending_clients` peer↔steam_id bookkeeping; owns a child `SteamLobbyManager` (scripts/network/SteamLobbyManager.gd, not an autoload) that handles lobby create/join/leave and `SteamMultiplayerPeer` wiring.
- `FPSOverlay` (scripts/ui/overlays/FPSOverlay.gd) — toggleable FPS counter overlay, driven by `SettingsManager.show_fps_overlay` (Video tab).

**`ManagerLocator`** (scripts/managers/ManagerLocator.gd) is the central indirection point: wraps autoload access (`get_save_manager`, `get_currency_manager`, `get_player_stats`, `get_settings_manager`, `get_steam_manager`) and group-based lookup for singletons that are *not* autoloads (`get_game_state_manager()` via `game_state_manager` group, `get_floating_text_manager()` via group, lazily instantiating on the scene root if absent). Fetch managers through this rather than raw autoload names or ad-hoc `get_tree().get_first_node_in_group()` calls.

**`GameStateManager`** (scripts/managers/GameStateManager.gd) — scene-instantiated (not an autoload) gameplay state machine: `State` enum ACTIVE/PAUSED/DEAD. Other systems call its `can_process_*` helpers to gate logic, and it emits `state_changed`/`pause_requested`/`resume_requested`/`death_entered`.

**`TurnManager`** (scripts/core/actions/TurnManager.gd) + **`ActionQueue`** (scripts/core/actions/ActionQueue.gd) — TurnManager registers/unregisters actors and drives turn sequencing (`begin_turn`/`process_turn_end` duck-typed on actors), refilling AP via the actor's `CharacterStats` each turn; ActionQueue serially executes queued `BaseAction`/`WaitAction` instances, emitting `action_finished(action, result)`. `request_pass_turn(actor)` is the entry point for the HUD's "Pasar Turno" button.

**`Player`** (scripts/core/player/Player.gd) — minimal `Node2D` actor: owns a `CharacterStats` child, registers with `PlayerStats` on `_ready()`, and implements the `begin_turn`/`process_turn_end`/`can_accept_input` contract `TurnManager` and `TurnButtonController` expect. No movement or combat logic yet.

**`Logger`** (scripts/core/utils/Logger.gd, `class_name QuestLogger`) — categorized/leveled logging (`Category`: GENERAL/COMBAT/CARDS/MAP/STATE/ACTIONS/SAVE/UI/CAMERA/NETWORK; `Level`: DEBUG/INFO/WARN/ERROR), replacing raw `print()` calls project-wide. Use it for new diagnostics instead of `print()`.

**Multiplayer flow**: Main menu "Iniciar Partida" opens `NetworkModeSelect` (scenes/NetworkModeSelect.tscn) with Host/Join/Offline. Host creates a Steam lobby (`SteamLobbyManager.create_lobby`, Friends Only) then picks a save slot via `SaveSlotSelector` (script on `scenes/SlotSelection.tscn`, not its own scene); Join opens the Steam friends overlay and joins via `join_requested`/`lobby_joined`. Joining clients must pass Steam auth-ticket validation (mandatory-blocking, 15s timeout) before `SteamManager.connected_clients` counts them as real players. Both paths land in `scenes/WaitingRoom.tscn` before the host starts `Main2d.tscn`; Offline is unchanged (`SlotSelection.tscn` → `CharacterSelection.tscn` → `Main2d.tscn` directly, no networking).

**`Main2d.tscn` gameplay scene** (scripts/managers/Main2d.gd): minimal state-machine orchestrator. On `_ready()` it resolves `active_character_id` from `SaveManager.get_selected_character_id()`, ensures a `GameStateManager` child exists, instantiates `Player.tscn` at a fixed spawn position, wires a `TurnManager` around it, and connects pause/death overlay signals. Owns a `TestGrid` (scripts/world/TestGrid.gd) child purely for visual reference — a `_draw()`-based grid, no gameplay logic. `Main2dDeathHandler.gd` presents the death overlay/run summary (unchanged, pure presentation helper).

**HUD** (`scenes/HUD.tscn`, `scripts/ui/hud/HUDController.gd`): trimmed to exactly three widgets — HP bar/label, AP label, "Pasar Turno" button (`scripts/ui/hud/StatPanelUI.gd` formats them, `scripts/ui/hud/TurnButtonController.gd` wires the button to `TurnManager.request_pass_turn`). `HUDController` still adds itself to the `"hud"` group and exposes `show_simple_tooltip`/`hide_simple_tooltip` + a `StatTooltip` node — these are load-bearing for `StorePanel.gd` (pause-menu stat-upgrade store, unrelated to the old card system), not just HUD self-use.

## Directory layout

- `scripts/core/` — `actions` (BaseAction/ActionQueue/TurnManager/WaitAction), `player` (Player.gd), `stats` (PlayerStats/CharacterStats/CharacterData/CharacterDatabase/StatBalance/ModifierStack), `theme`, `utils`
- `scripts/managers/` — SaveManager, CurrencyManager, SettingsManager, GameStateManager, ManagerLocator, Main2d/Main2dDeathHandler
- `scripts/network/` — SteamManager (autoload), SteamLobbyManager (Steam lobby/matchmaking)
- `scripts/ui/` — `hud` (HUDController/StatPanelUI/StatIcon/TurnButtonController), `menus` (incl. `MenuTransitionFX.gd` shared fade/scale tween helper used by `BaseMenu`/`BaseSubPanel`, `StorePanel`/`StoreUpgradeCard` stat-upgrade store), `overlays` (incl. `FPSOverlay.gd`), `visual` (FloatingText/FloatingTextManager)
- `scripts/world/` — `TestGrid.gd` only (visual reference grid for `Main2d.tscn`)
- `resources/` — `.tres` data: `characters/{warrior,mage,rogue,tank}.tres` (portraits + base stats, consumed by `CharacterDatabase`)

## When picking up gameplay work here

There is no movement, targeting, combat, enemies, or dungeon generation right now — `Main2d.tscn` is intentionally an empty grid with one hero and a turn counter. Before building a new version of any of those systems, check `scripts/core/actions/` (TurnManager/ActionQueue/BaseAction/WaitAction) first — it survived the wipe specifically so new action types (movement, attack, etc.) can hang off it via `BaseAction` subclasses, the same pattern the old system used.

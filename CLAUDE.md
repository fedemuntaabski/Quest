# CLAUDE.md

Guidance for Claude Code in this repo. **Current state only.** Per-session history lives in `docs/archive/SESSIONS.md` (append new session blocks there, not here); `CHANGELOG.md` has the short player-facing list.

## Keeping this file lean

- Target ≤ 20 KB. Add here only what stays true and that a fresh session needs to avoid a mistake: architecture changes, new invariants, new gotchas, removed systems.
- A session's "what I changed / not verified" goes to `docs/archive/SESSIONS.md` + the topic doc in `docs/` (e.g. `BALANCE.md`, `COOP_PROGRESO.md`, `PLAYTEST.md`). Link the doc from here instead of copying it.
- When a session changes something described below, **edit the paragraph in place** (don't append a correction elsewhere).
- Status artifacts / closing `/goal` prompts follow the same rule: they point to the docs, they don't restate this file.

## Project overview

QUEST: 2D tactical roguelite, Godot 4.6 (4.6.2), GDScript only, GL Compatibility. *Dungeon of the Endless*-style: a party of 2–4 heroes explores a seeded room/corridor graph per floor; opening a door is the only "turn" (pays embers + a random resource, rolls an invasion, reveals the next room). Resources: Hierro (`iron`), Comida (`food`), Saber (`lore`), Brasas (`embers`). Rooms are lit with Brasas (rising cost) to unlock build slots for Obras (`Building`: Talleres produce, Defensas shoot, traps). Win a floor: find the exit, pick up the Reliquia (`Relic`) in the start room, survive the staged extraction waves while carrying it, walk into the exit. 5 floors (bosses on 3 and 5). Lose: every hero downed, or the Reliquia destroyed. Offline single player, 2–4 player host-authoritative co-op (Steam or ENet), Tutorial, intro, offline save between floors.

Visible text is Spanish with medieval vocabulary (see memory `vocabulario-medieval`; `tests/test_vocabulario.gd` fails on old words). Code identifiers match: `Relic`, `embers`, `iron`, `lore`, `Building`, `WorkshopBuilding`, `DefenseBuilding`, `is_lit`/`toggle_light`. Hero id `tank` = Paladín (id kept for saves).

### Gone — don't look for it or "fix" references

Card combat, `MapManager`, `CombatCardSystem`, `CardData`; AP system (`TurnManager`, `ActionQueue`, `ModifierStack`, `StatTypes`, STR/MAG/DEX); cell-by-cell BFS movement (`MapNavigationHelper`, `Highlight` layer); hardcoded `Main2d.LAYOUT` + hand-placed doors; `RoomManager.build_from_layout`; Oro currency (`CurrencyManager`, store, `SaveManager.gold`); `RoomData.kind`/`TYPE_LABELS`; `RoomType.SHOP`; `Enemy.Variant` behaviour by SWARM/SAPPER/HUNTER as the targeting model (replaced by `TargetSelector`); `PlayerStats.active_hero_changed` (use `SelectionManager.selection_changed`); `Building.DESCRIPTIONS`/`DEFENSE`/`TRAP`; `lore_workshop`/`defense_plans` research; `MapTileRenderer` `Doors` layer; `Main2dDeathHandler`/`Main2dVictoryHandler`; `RoomLightSystem`/`BuildingBuildSystem`; `RoomManager.get_all_buildings()` never existed.

## Commands

No build system, linter, CI or export presets.

```bash
godot --path . --editor          # editor
godot --path .                   # run (always via scenes/Main.tscn, never F6 on Main2d)
tools/run_tests.sh [filter]      # whole suite (tests/run_all.gd); exit = failures; OK* = passed but crashed on exit
godot --headless --path . --script res://tests/test_<area>.gd   # one test
godot --headless --path . --editor --quit                       # reindex after a new class_name
python -m gdtoolkit.parser <files.gd>                           # gdparse (not on PATH)
```

Godot on the dev machine: `E:\Descargas\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`.

Tests are plain `extends SceneTree` scripts (exit 0/1), one `tests/test_*.gd` per area, each run in its own process by `tests/run_all.gd` (logs in `user://test_logs`; 0 tests run = failure). Add new tests in the same style. `tests/support/ErrorProbe.gd` collects engine ERROR/WARNING. `tests/tools/` = real-window screenshot tools (`shot_*.gd`), benches, net probes. `test_door_roll` takes ~4.5 min. Tests that need the pause tree or flow boot the real `Main` (`test_estabilizar`, `test_full_run`, `test_run_save`, `test_tutorial`).

## Gotchas (read before editing)

- **Autoload names aren't identifiers under `--script`.** Instances exist (`root.get_node("ResourceManager")`), names don't. Scripts under test must not use autoload names as identifiers; go through `ManagerLocator`, and preload autoload consts (`preload("res://scripts/autoload/GameSession.gd").MAX_PARTY`). That's why `UiStyles` is a `class_name`, not an autoload.
- **New `class_name`** → first `--script` run may say `Could not find type` → reindex (`--editor --quit`).
- **Gameplay input is `Area2D.input_event` only.** Never read mouse in `_input`/`_unhandled_input` of gameplay nodes and `set_input_as_handled()`: it runs before physics picking and swallows the click. UI panels that must beat `Main2d`'s Esc pause consume Esc in their own `_input` (HUD comes after World in the tree).
- **Pause tree.** `Main` is `PROCESS_MODE_ALWAYS`; `Main2d` sets itself `PAUSABLE`. Must-run-while-paused nodes set ALWAYS themselves (`PauseMenu`, `GameStateManager`, `NetSync`, overlays, `PauseController` = child 0 of `Main2d`, owns the run clock). The HUD is ALWAYS → anything it does gates on `GameStateManager.is_active()`. Tactical pause = `Engine.time_scale` 0 (owned by `PauseController`, reset in its `_exit_tree` and next to every `get_tree().paused = false`); feedback tweens use `set_ignore_time_scale()`, `GameCamera` uses real time, enemy timers use `Enemy.game_msec()`.
- **Terminal states.** DEAD and VICTORY never replace each other (`GameStateManager._is_over()`); check it before declaring either.
- **Hurting a hero** only via `Player.take_hit()` (passives/shields). 0 HP = downed and stays 0 (`StatBalance.apply_hp_delta`); only `revive_hero` brings one back.
- **Co-op authority.** Every player action goes through `NetCommands.request(cmd, args)` (offline/host runs `_cmd_<name>` directly; clients RPC, host validates). Shared mutators are guarded by `Net.is_authority()`; clients only apply `NetSync` snapshots/events and `RunState`. **Bump `application/config/version` in `project.godot` (now 1.1) whenever commands or `RunState` keys change** — mismatched peers are refused.
- **Audio in co-op.** `AudioDirector.HOST_KEYS` sounds play on the host and are relayed; wire a new sound at the host-side action, never on a signal `RunState` also fires, or add it to `HOST_KEYS`. Missing audio files play silence (list in `docs/CREDITOS.md`).
- **First-time help** (`SettingsManager.should_show_help`, `user://first_help.cfg`) is not persisted under `--script` (`help_persist` false) and `Main.play_intro` is false there; tests that need them turn them on.
- **Logging**: `QuestLogger` (`scripts/core/utils/Logger.gd`), not `print()`. Hot-path logs are DEBUG (an INFO line costs ~1 ms with file logging).
- **`ManagerLocator.get_main_orchestrator()` can be null** (scene run standalone): null-check and log.
- **Signal 11 on exit (OK\*)** is a Godot 4.6.2 GDScript-teardown crash, not ours (evidence in `docs/PROGRESO_INTEGRACION.md`). Don't hunt it; re-measure on a new Godot.
- **Licences.** Every `res://` art/font/audio path in `scenes/ resources/ scripts/ project.godot` must match the allowlist table in `docs/CREDITOS.md` (`test_licencias`). New asset → add its row with a verified licence. Unknown-licence packs (item sheets, unTied FX, Raven) are local-only and gitignored (`_source/items_sheets`, `_source/super_pixel_effects`, `_rejected/licencia/`); never reference them. Nothing at runtime may point into `assets/art/_source/` (originals only; `test_licencias` bans it so an export can drop it): copy the sheet to `assets/art/{tiles,...}/` first. `.import` files are gitignored.
- Expected headless noise: GodotSteam/Steam not running; `ObjectDB instances leaked` when cut by `--quit-after`.

## Architecture

### Scene flow

- `scenes/Main.tscn` / `scripts/run/Main.gd` = `run/main_scene`, the orchestrator (group `main_orchestrator`). Containers: `WorldContainer` (a `Main2d` per floor), `UIContainer` (menus), `HUDContainer` (a `HUD` per floor), `TransitionOverlay` (fades, `IntroScreen`). API: `show_main_menu`, `start_gameplay(floor, tutorial)`, `start_tutorial`, `continue_run`, `go_to_waiting_room`, `reload_gameplay` (Retry), `advance_floor`, `return_to_main_menu`. Never `change_scene_to_file`. `_begin_new_run()` resets resources, research, levels, inventory, `GameSession` run state, seen types. Floor counter and `run_seed` live here (`Main2d` is freed between floors).
- Menus: `MainMenu` + `MainMenuFlow` (RefCounted): slot → (continue dialog) → network mode → `HeroSelectMenu` → gameplay; online goes through `WaitingRoom`.
- `scripts/run/Main2d.gd` builds the floor: `GameStateManager` (ACTIVE/PAUSED/DEAD/VICTORY), `DoorTurnSystem`, `FloorManager`, `RoomManager` from a `MapLayout`, one `Door` per corridor, heroes (`spawn_hero`), controllers (`HeroInputController`, `PauseController`, `LootSpawner`, `PrisonerSpawner`, `HazardSpawner`), `EnemyManager`, `ExtractionManager`, `ExitIndicator`, `Relic`, overlays (`DeathOverlay`/`VictoryOverlay`, base `EndScreenOverlay`). `is_tutorial()` → fallback layout + `Tutorial` node (`scripts/run/Tutorial.gd`, `STEPS` advance on real signals).

### Autoloads (`project.godot`)

`PartyInventory` (stash 20 + per-hero loadout; before `PlayerStats`), `PlayerStats` (per-hero `CharacterStats`, levels paid in Comida, perks, heal/revive, `get_stat_breakdown`; stat layers base → level → perks+equipment), `SaveManager` (`user://slot_<id>.cfg` via `SafeConfig`; `SAVE_VERSION` 3 + `migrate()`; bestiary; offline run `[run] state`), `SettingsManager` (audio/video/input/accessibility/help), `FPSOverlay`, `SteamManager`, `NetSession` (`CoopSession`), `NetCommands` (`CoopCommands`), `ResourceManager` (4 resources, `spend_resource` refuses on insufficient funds, Taller yield, research via `ResearchState`), `GameSession` (hero pick, difficulty, recruited/lost, tutorial flag), `SelectionManager` (selection + control groups 1–3), `BestiaryService`, `AudioDirector` (`SFX_PATHS`, music crossfade, `HOST_KEYS`).

`ManagerLocator` (`scripts/autoload/ManagerLocator.gd`, not an autoload) is the one lookup point: autoload getters + group lookups (`room_manager`, `player` = primary selected hero, `get_heroes()`, `enemy_manager`, `extraction_manager`, `floor_manager`, `exit_indicator`, `game_camera`, relic, …). Use it instead of raw names or ad-hoc group queries.

### Map

`scripts/world/map/`: `MapGenerator.generate_floor(seed, FloorConfig, floor)` = deterministic tree (slot grid, `SLOT_PITCH` 9) → `add_loops` → `assign_room_types` (each post-pass on its own salted RNG). `MapLayout` (`rooms: Array[RoomData]`, `corridors: Array[CorridorData]`, `validate()`), fallback `resources/maps/fallback_layout.tres`. Seed per floor = `hash([run_seed, floor])`. Reveal group = room + its entry corridor; a loop corridor is its own group (no embers, reveals no room). `RoomData.RoomType` {COMBAT, START, EXIT, REST, LOOT, ELITE, WORKSHOP, PRISONER, ALTAR, SECRET}: rules in `RoomTypeRule` (`FloorConfig.room_types`), display in `RoomTypeVisualConfig`. Docs: `docs/ROOMS.md`, `docs/MAP_RENDER.md`.

`RoomManager` (group `room_manager`) owns the zone graph (rooms + corridors as `RoomZone` `Area2D`s), `find_zone_path` (BFS over revealed zones only), lighting counts, buildings per group. *Revealed* (`DoorTurnSystem.rooms[group].visited`) gates gameplay; *visible* is derived and drawn only through `apply_zone_visibility`/`refresh_visibility`. Rendering: `MapTileRenderer` (Floor/Walls/Decor layers, per-seed plan with an `under` fill behind wall caps, each decoration on its own salted RNG stream; tilesets baked by `tools/build_tilesets.gd`, which keeps the `.tres` uids); the logical hidden `Floor` `FloorGenerator` grid stays. Door leaf = `Sprite2D` on `Door`. Art scale: `ArtConfig` (16 px tiles ×2, logical cell 64 px).

### Turn, economy, building

- `DoorTurnSystem.open_room()` (called by `PlayerActionController._open_group`, refused in pause and during extraction) → `turn_advanced` → `ResourceManager.process_turn_production()` (Talleres only; base yield 0), `FloorManager.on_room_discovered` (embers + `door_bonus`, room-type rewards, banner/hint), `EnemyManager._on_turn_advanced` (threat roll from `DoorRollConfig` × `PlayerScaling`, cap `FloorConfig.max_enemies_by_floor`).
- Lighting: middle-click **release** on a room (not if `GameCamera.was_dragged()`) → `RoomZone.toggle_light()`; cost `LIGHT_COST` + `light_cost_step` per room lit with embers − research; switching off refunds what was paid. Start room lit free.
- Building: only via bottom-bar armed mode (`BuildingMenu` tabs Mayores/Menores/Investigación, keys B/V/R, 1–9) → click a highlighted `BuildingSlot`. Buildings are data: `BuildingDef` `.tres` in `resources/buildings/` → `Building.CATALOG`; costs `BuildingCostCurve`; click a built one → `BuildingPopup` (demolish/repair). `Building.is_working()` honours `requires_light`.
- Research: `ResearchConfig`/`ResearchEntry`/`BuildingResearch` (`resources/research/research_config.tres`), spends Saber, needs a working Scriptorium; consumers read `ResourceManager.get_bonus(effect)`.
- Docs: `docs/ECONOMIA.md`, `docs/BUCLE_JUEGO.md`, `docs/BALANCE.md` (numbers from `BalanceSim`, checked by `test_balance`).

### Heroes, combat, enemies

- `Player` (`scripts/core/player/`): `current_zone_id` is the authoritative position; moves by **right click** on a zone (`PlayerActionController._walk`, tween through zone centres, `enter_zone()` as it crosses; `move_speed_mult` per hero, carrier ×`carrier_speed_mult`). Left click = select (`HeroInputController`, F1–F4, Tab, Ctrl+1..3 / 1..3) or interact (doors, Reliquia, cages, downed bodies). Q = ability (`HeroAbilities`, `AbilityData`). Downed state, revive with Comida.
- Auto-combat: `HitboxComponent`/`HurtboxComponent` on physics layers (3 `player_hurtbox`, 4 `enemy_hurtbox`, 2 `enemy_body`); heroes `single_target`, ranged heroes fire `Projectile`. Hero data: `CharacterData` `.tres` in `resources/characters/` (role, base_hp, attack, perks, `attack_style`). Packs have no attack/death frames: `CharacterVisual` fakes them (`lunge`, `set_downed` topple, `spawn_corpse` under the enemies root), visual only. New world VFX are played host-side (`VfxManager.play` relays them as `fx`; never also play them on a client path). Docs: `docs/PERSONAJES.md`, `docs/ASSETS.md`.
- Enemies: `Enemy` (`scripts/entities/`), types `EnemyType` with `role` HUNTER/RAIDER; destination from `TargetSelector` + `TargetProfile` (`resources/enemies/profiles/`). Movement = `EnemyMoveAction` over `find_zone_path`, 8-slot ring, no physics. Bosses: `BossBrain` (floors 3, 5; exit refused while alive). Docs: `docs/ENEMY_TARGETING.md`.
- Recruitment: Prisoner rooms → `PrisonerCage` → `Main2d.recruit_hero` (max party 4).

### Extraction & floors

`Relic` (HP, cracks, drop/pick-up by any hero in `drop_zone_id`) + `RelicController` (needs exit discovered + hero in start room). `ExtractionManager` (Phase EXPLORATION/EXTRACTION + `stage`): extraction blocks doors and spawns staged waves; carrier into the exit → `declare_victory` → `FloorManager.complete_floor` → `VictoryOverlay` (next floor / final). Run curve: `RunCurve`/`FloorTheme` (`resources/floors/run_curve.tres`), `DifficultyConfig`, `FloorConfig` (`resources/floors/default_floor_config.tres`).

### Save

Offline only, never in Tutorial: `Main._save_run()` at each floor start from floor 2 (after the old `Main2d` is freed) stores `Main.capture_run()`; map comes back from `run_seed`. Cleared on defeat, final victory, new run. Doc: `docs/GUARDADO.md`. Tests: `test_save`, `test_run_save`.

### HUD (`scenes/hud/HUD.tscn`, `HUDController`, group `hud`)

Top-left floor label + `ObjectivePanel` + `HelpCard`; top-right `HeroPortrait`s (HP, ability radial, consumables, revive) → `CharacterPopup`; bottom-center `BottomBar` (`BuildingMenu`/`ResearchPanel` over resources + build buttons + Mochila counter); bottom-right `Minimap`; hints/refusals via `show_hint`/`show_refusal`/`show_help`; online-only `PlayerList`, `ChatPanel`, map pings. Many HUD pieces are code-built.

### Network (`scripts/network/`)

`NetworkTransport` → `SteamTransport` (lobby id = join code) / `EnetTransport` (`--net=enet`, local dev/tests). `Net` static helpers, `NetSession`, `NetCommands`, `NetSync` (snapshots/events), `RunState` (full state, resync, desync hash), `NetConfig` (`resources/net/net_config.tres`). Status/manual steps: `docs/COOP_PROGRESO.md`, `docs/COOP_PRUEBAS.md`. Steam with two real accounts: not verified.

## Directory layout

- `scripts/autoload/` autoloads + `ManagerLocator`; `scripts/run/` per-run composition (Main, Main2d, managers, controllers, Tutorial); `scripts/core/` data + systems by area (abilities, actions, buildings, camera, combat, enemies, floors, input, items, movement, player, research, stats, …); `scripts/entities/` enemies + targeting; `scripts/world/` zones, doors, buildings, relic, chests, cages, map; `scripts/network/`; `scripts/ui/` (hud, menus, overlays, visual).
- `resources/` `.tres` data (characters, sprite_frames, tilesets, buildings, enemies, floors, items, maps, research, upgrades, net, ui, …). `tools/` headless builders (`build_tilesets`, `build_characters`, `build_items`, `build_own_art`, `normalize_assets` = placeholders only, `balance_sim`) + `libresprite.sh` (own art ↔ `.ase` in `assets/art/own/src/`; `build_own_art` skips outputs that have a `.ase`). `assets/art/` normalized CC0 art + `own/` (project-made item icons, Reliquia gem, VFX strips) (`_source` untouched packs, `docs/ASSETS.md`).
- `docs/` topic docs (start at `docs/PLAYTEST.md` for manual checks, `docs/PROGRESO_INTEGRACION.md` for status); `docs/archive/` history (old names on purpose).

## Not verified in a real window

Most UI layout and mouse feel has only been checked headless or by scripted screenshots. Before claiming something "plays right", see the open lists in `docs/PLAYTEST.md` and the per-session notes in `docs/archive/SESSIONS.md`.

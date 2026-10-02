# Reporte de refactor — `session/refactor-2`

Base: `session/arch-1` (`bdaf0e0`). Plan: `docs/DIAGNOSTICO_ARQUITECTURA.md` §12. Alcance acordado ("Medio"): R1–R9, R11 (mínimo), R12, R15–R18 (R18 parcial), R19, R21, R23. Regla: sin cambios de comportamiento ni de balance. Un commit por paso (`git log --oneline bdaf0e0..HEAD`).

## Verificación hecha
- `python -m gdtoolkit.parser` sobre cada `.gd` tocado: sin fallos (gdtoolkit 4.5.0 vs Godot 4.6.2).
- Reindex (`--editor --quit`) y boot headless de `Main.tscn` y `Main2d.tscn` sin `SCRIPT ERROR`.
- `tools/run_tests.ps1` (nuevo): los 21 tests headless con Godot 4.6.2 tras cada paso que movió o separó código.
- `grep` de cada ruta vieja tras cada movimiento: 0 restos fuera de `docs/archive/` y del diagnóstico (que describe el estado previo).

## Estado de tests
Línea base en `bdaf0e0`: 17 OK / 3 rojos (`test_hud_ui`, `test_map_flow`, `test_sprites`, los tres por valores viejos escritos como literales). Ahora: 21/21 (los 20 originales + `test_main2d_overlays` nuevo).
- Godot 4.6.2 a veces hace **segfault al cerrar** (señal 11) después de que el test ya imprimió `OK (0 failures)` (visto en `test_map_flow` y `test_hero_select`, intermitente). El runner lo marca `OK*`. No lo investigué: es del motor y aparece en tests que no se tocaron.
- Los tests ahora arrancan `Main2d` completo bajo `--script` (antes `pause_menu`, `death_overlay`, `victory_overlay` y `retry_button` eran `null` por el autoload `ThemeManager`). `test_hud_ui` asumía ese `PauseMenu` roto y se ajustó.

## Qué se movió (ruta vieja → ruta nueva)
Todos con `git mv` (+ el `.uid` del script). Los `.tres`/`.tscn` movidos conservan su `uid` interno.

| Antes | Ahora |
|---|---|
| `HANDOFF_DOTE_RESOURCE_SYSTEM.md` | `docs/archive/HANDOFF_DOTE_RESOURCE_SYSTEM.md` |
| `HANDOFF_MOVEMENT_HUD_FIX.md` | `docs/archive/HANDOFF_MOVEMENT_HUD_FIX.md` |
| `HANDOFF_ROOM_CORE_M1.md` | `docs/archive/HANDOFF_ROOM_CORE_M1.md` |
| `HANDOFF_ROOM_CORE_M2.md` | `docs/archive/HANDOFF_ROOM_CORE_M2.md` |
| `HANDOFF_ROOM_GRAPH_MOVEMENT.md` | `docs/archive/HANDOFF_ROOM_GRAPH_MOVEMENT.md` |
| `NOTES_SESSION.md` | `docs/archive/NOTES_SESSION.md` |
| `REVIEW_SESSION_10.md` | `docs/archive/REVIEW_SESSION_10.md` |
| `docs/balance/after_nexus.csv` | `docs/balance/after_nexo.csv` |
| `docs/balance/before_nexus.csv` | `docs/balance/before_nexo.csv` |
| `assets/characters/enemy_big_demon.tres` | `resources/sprite_frames/enemy_big_demon.tres` |
| `assets/characters/enemy_big_zombie.tres` | `resources/sprite_frames/enemy_big_zombie.tres` |
| `assets/characters/enemy_chort.tres` | `resources/sprite_frames/enemy_chort.tres` |
| `assets/characters/enemy_goblin.tres` | `resources/sprite_frames/enemy_goblin.tres` |
| `assets/characters/enemy_imp.tres` | `resources/sprite_frames/enemy_imp.tres` |
| `assets/characters/enemy_masked_orc.tres` | `resources/sprite_frames/enemy_masked_orc.tres` |
| `assets/characters/enemy_necromancer.tres` | `resources/sprite_frames/enemy_necromancer.tres` |
| `assets/characters/enemy_ogre.tres` | `resources/sprite_frames/enemy_ogre.tres` |
| `assets/characters/enemy_orc_shaman.tres` | `resources/sprite_frames/enemy_orc_shaman.tres` |
| `assets/characters/enemy_orc_warrior.tres` | `resources/sprite_frames/enemy_orc_warrior.tres` |
| `assets/characters/enemy_skelet.tres` | `resources/sprite_frames/enemy_skelet.tres` |
| `assets/characters/enemy_tiny_zombie.tres` | `resources/sprite_frames/enemy_tiny_zombie.tres` |
| `assets/characters/enemy_wogol.tres` | `resources/sprite_frames/enemy_wogol.tres` |
| `assets/characters/hero_dwarf_m.tres` | `resources/sprite_frames/hero_dwarf_m.tres` |
| `assets/characters/hero_elf_m.tres` | `resources/sprite_frames/hero_elf_m.tres` |
| `assets/characters/hero_knight_m.tres` | `resources/sprite_frames/hero_knight_m.tres` |
| `assets/characters/hero_wizzard_m.tres` | `resources/sprite_frames/hero_wizzard_m.tres` |
| `assets/characters/tc_demon.tres` | `resources/sprite_frames/tc_demon.tres` |
| `assets/characters/tc_dragon.tres` | `resources/sprite_frames/tc_dragon.tres` |
| `assets/characters/tc_eyeball.tres` | `resources/sprite_frames/tc_eyeball.tres` |
| `assets/characters/tc_fire_skull.tres` | `resources/sprite_frames/tc_fire_skull.tres` |
| `assets/characters/tc_ogre.tres` | `resources/sprite_frames/tc_ogre.tres` |
| `assets/characters/tc_red_imp.tres` | `resources/sprite_frames/tc_red_imp.tres` |
| `assets/characters/tc_wolf.tres` | `resources/sprite_frames/tc_wolf.tres` |
| `assets/tilesets/dungeon_tileset.tres` | `resources/tilesets/dungeon_tileset.tres` |
| `resources/tileset/placeholder_tileset.tres` | `resources/tilesets/placeholder_tileset.tres` |
| `assets/tilesets/props_tileset.tres` | `resources/tilesets/props_tileset.tres` |
| `scenes/Player.tscn` | `scenes/entities/Player.tscn` |
| `scenes/ui/BuildingMenu.tscn` | `scenes/hud/BuildingMenu.tscn` |
| `scenes/HUD.tscn` | `scenes/hud/HUD.tscn` |
| `scenes/CharacterCardOption.tscn` | `scenes/menus/CharacterCardOption.tscn` |
| `scenes/ExitConfirmDialog.tscn` | `scenes/menus/ExitConfirmDialog.tscn` |
| `scenes/HeroSelectMenu.tscn` | `scenes/menus/HeroSelectMenu.tscn` |
| `scenes/MainMenu.tscn` | `scenes/menus/MainMenu.tscn` |
| `scenes/NetworkModeSelect.tscn` | `scenes/menus/NetworkModeSelect.tscn` |
| `scenes/OptionsMenu.tscn` | `scenes/menus/OptionsMenu.tscn` |
| `scenes/PauseMenu.tscn` | `scenes/menus/PauseMenu.tscn` |
| `scenes/SlotSelection.tscn` | `scenes/menus/SlotSelection.tscn` |
| `scenes/WaitingRoom.tscn` | `scenes/menus/WaitingRoom.tscn` |
| `scenes/FloatingText.tscn` | `scenes/vfx/FloatingText.tscn` |
| `assets/vfx/buff_aura.tscn` | `scenes/vfx/buff_aura.tscn` |
| `assets/vfx/damage_flash.tscn` | `scenes/vfx/damage_flash.tscn` |
| `assets/vfx/death_dust.tscn` | `scenes/vfx/death_dust.tscn` |
| `assets/vfx/heal_glow.tscn` | `scenes/vfx/heal_glow.tscn` |
| `assets/vfx/impact_sparks.tscn` | `scenes/vfx/impact_sparks.tscn` |
| `assets/vfx/projectile_trail.tscn` | `scenes/vfx/projectile_trail.tscn` |
| `assets/vfx/slash_arc.tscn` | `scenes/vfx/slash_arc.tscn` |
| `scenes/Door.tscn` | `scenes/world/Door.tscn` |
| `scenes/RoomZone.tscn` | `scenes/world/RoomZone.tscn` |
| `scripts/managers/GameSession.gd` | `scripts/autoload/GameSession.gd` |
| `scripts/managers/ManagerLocator.gd` | `scripts/autoload/ManagerLocator.gd` |
| `scripts/managers/ResourceManager.gd` | `scripts/autoload/ResourceManager.gd` |
| `scripts/managers/SaveManager.gd` | `scripts/autoload/SaveManager.gd` |
| `scripts/managers/SelectionManager.gd` | `scripts/autoload/SelectionManager.gd` |
| `scripts/managers/SettingsManager.gd` | `scripts/autoload/SettingsManager.gd` |
| `scripts/core/floors/EnemyPool.gd` | `scripts/core/enemies/EnemyPool.gd` |
| `scripts/core/floors/EnemyType.gd` | `scripts/core/enemies/EnemyType.gd` |
| `scripts/core/actions/DoorTurnSystem.gd` | `scripts/run/DoorTurnSystem.gd` |
| `scripts/managers/EnemyManager.gd` | `scripts/run/EnemyManager.gd` |
| `scripts/managers/ExtractionManager.gd` | `scripts/run/ExtractionManager.gd` |
| `scripts/managers/FloorManager.gd` | `scripts/run/FloorManager.gd` |
| `scripts/managers/GameStateManager.gd` | `scripts/run/GameStateManager.gd` |
| `scripts/managers/Main.gd` | `scripts/run/Main.gd` |
| `scripts/managers/Main2d.gd` | `scripts/run/Main2d.gd` |
| `scripts/managers/VfxManager.gd` | `scripts/run/VfxManager.gd` |
| `scripts/ui/BuildingMenu.gd` | `scripts/ui/hud/BuildingMenu.gd` |
| `scripts/ui/character_select/CharacterCardOption.gd` | `scripts/ui/menus/CharacterCardOption.gd` |
| `scripts/core/theme/ThemeManager.gd` | `scripts/ui/theme/UiStyles.gd` |
| `scripts/core/balance/BalanceSim.gd` | `tools/BalanceSim.gd` |

## Qué se separó
| De | A | Motivo (diagnóstico) |
|---|---|---|
| `Main2d.gd` (493 → 377 líneas) | `HeroInputController` (clic sobre héroe, F1/F2, grupos 1–3, doble toque) | R19, god-script |
| `Main2d.gd` | `PauseController` (pausa táctica; dueño de `Engine.time_scale` y su reseteo) | R19, §11-6 |
| `Main2d.gd` | `LootSpawner` (cofres de salas Loot) | R19, no era su trabajo |
| `Main2dDeathHandler` + `Main2dVictoryHandler` + 6 rutas internas en `Main2d` | `DeathOverlay`, `VictoryOverlay` (base `EndScreenOverlay`) con señales `retry/exit/next_floor/return_requested` | R12 |
| `ThemeManager` (autoload, `extends Node`) | `UiStyles` (`class_name`, solo estáticos) | R7 |
| `scripts/managers/` | `scripts/autoload/` + `scripts/run/` | R15 |
| `RoomPowerSystem`, `ModuleBuildSystem` (pass-throughs) | conexión directa `RoomManager.slot_clicked` → `HUDController`; el log del encendido vive en `RoomZone.try_power_up` | R9 |
| `ManagerLocator` (retornos `Node`) | `get_game_session/selection_manager/settings_manager/steam_manager` tipados, `get_floating_text_manager -> FloatingTextManager`, nuevo `get_hud() -> HUDController` (reemplaza `call_group("hud", …)` en `FloorManager`, `PauseController`, `HeroInputController`) | R21, R23 |

## Qué se eliminó (solo con grep negativo en scripts/scenes/resources/tests/tools)
- **Huérfanos:** `resources/sprites/shared_player_idle_frames.tres`, `Sprites/Player/_Idle.png`, `resources/tileset/highlight_tileset.tres`, `assets/texture/enviorment/highlight_placeholder.png`, `godot_debug_output.txt` (ahora en `.gitignore`).
- **Funciones sin llamadores:** `ThemeManager` ×20 (`build_ap_badge_style`, `get_combat_feedback_*`, 17 `tactical_*`); `GameStateManager` ×7 (`is_paused`, `is_victory`, `can_process_input`, `can_process_turns`, `set_state`, `toggle_pause`, `return_to_previous_state`); `RoomManager` ×7 + 2 privadas (`has_zone`, `get_zone_at_cell`, `get_all_modules`, `are_rooms_connected`, `is_path_open`, `get_adjacent_rooms`, `are_connected`, `_shared_door`, `_door_counterpart`); `SaveManager` ×4 (`get/set/increment_run_cycle`, `set_selected_character_id`); `ResourceManager.add_all`; `DoorTurnSystem.get_room_cells`; `Player.set_grid_position`; `Door.mark_opened`; `StatPanelUI.update_stats`; `FloatingTextManager.spawn_text_from_host` (+ 2 `@export` que solo usaba); `ItemCatalog.get_item`; `ArtConfig.art_px`; `QuestLogger.set_min_level/set_category_enabled`; `ManagerLocator.get_room_power_system/get_module_build_system`.
- **Constantes:** 24 de `QuestPalette` (las 8 del diagnóstico + las que solo usaba el `ThemeManager` borrado).
- **Señales sin oyente:** `DoorTurnSystem.door_opened`, `GameStateManager.pause_requested/resume_requested/death_entered`, `BaseMenu`/`BaseSubPanel.menu_opened/menu_closed`, `RoomZone.powered_up`, `RoomManager.room_powered`, `RoomPowerSystem.room_energized`.
- **Clases/archivos:** `RoomPowerSystem`, `ModuleBuildSystem`, `Main2dDeathHandler`, `Main2dVictoryHandler`, `Main2d.active_character_id` (ahora local en `_spawn_heroes`).

## Renombres de datos (R18 parcial)
`nexus` → `nexo`: `EnemyType.damage_vs_nexus` → `damage_vs_nexo` (solo cambia la clave en 3 `.tres`: goblin, masked_orc, orc_warrior; mismos valores), `Enemy.nexus_damage`, `BalanceSim.nexus_rows`, `AbilityData.Effect.NEXUS_PROXIMITY_REDUCTION` → `NEXO_…` (enum guardado como entero: el valor numérico no cambia), CSV `before/after_nexus` → `*_nexo`. `balance_sim.gd` regenera los mismos números.

## Pendiente y por qué
| Ítem | Por qué no se hizo |
|---|---|
| R10 fusionar `BaseMenu`/`BaseSubPanel` | UI visual: sin ejecutar el juego no puedo comprobar apertura/cierre/animaciones. |
| R11 completo (una sola fuente de la selección de héroes) | Cambia el flujo Offline/WaitingRoom/guardado. Solo quité `Main2d.active_character_id`; el héroe guardado sigue siendo el líder del party por defecto cuando no hay pick de `HeroSelectMenu`. |
| R13 `RunState` | Toca 5 sistemas con estado de run; fuera del alcance acordado. `Main._begin_new_run()` sigue reseteando a mano. |
| R14 `ModuleData`/`EconomyConfig`/`EnemyType` absorbe `VARIANT_CONFIG` | Mover balance a Resources es el cambio que la regla "no cambiar valores" desaconseja sin comparar partidas. |
| R20 partir `RoomManager` (14 dependientes) | Riesgo alto; solo documenté el vocabulario zone/room/group en su cabecera. |
| R22 `HUDController`/`OptionsMenu` en componentes | UI visual. |
| Fase 4 (i18n, guardado, multijugador, `gdlintrc`) | Decisiones de producto. |
| `assets/ui/background.png`, `assets/ui/256x256 textures (113).png` | El diagnóstico pide confirmarlos en el editor antes de borrar. |
| `ResourceManager._calculate_module_bonus` usa el grupo `"generators"` | Autoload leyendo nodos de la escena; se resuelve con R13. |
| `Door.target_room_id` / `DoorTurnSystem.room_id` (en realidad *group id*) | Renombrar rompe la API y los tests; solo se documentó. |
| `Main2d._exit_tree` usa `get_first_node_in_group("vfx_manager")` | Deliberado: `ManagerLocator.get_vfx_manager()` *crea* el manager si falta y al salir no debe crearse uno. |
| `Main.gd` líneas 65/116 (`Engine.time_scale = 1.0`) | Se dejan junto a `paused = false`; `PauseController._exit_tree` ya lo garantiza al salir del piso. |
| Ciclo `Main` ↔ `WaitingRoom` (`Main` hace `preload` de `WaitingRoom`, éste llama a `Main`) | Del diagnóstico §4, no entraba en el plan. |

## Incidente durante la sesión
Había un **editor de Godot abierto** sobre el proyecto (distinto de la 4.6.2 de la consola). Al ver los archivos movidos volvió a guardar escenas/recursos en sus **rutas viejas** (dos veces: `scenes/MainMenu.tscn` recreado y `resources/floors/default_floor_config.tres` reescrito con rutas y pools rotos; la segunda coincidió con cerrar el editor). Los restauré con `git checkout`/`rm` antes de cada commit: ningún commit contiene esos archivos rotos. Una corrida de tests (R19) leyó el `.tres` roto y dio rojos por pools vacíos que desaparecieron al restaurarlo. **Al abrir el editor otra vez, corré `git status` y verificá que no aparezcan `scenes/MainMenu.tscn` ni cambios en `resources/floors/default_floor_config.tres`.**

## Checklist manual en el editor (no verificado sin ejecutar el juego)
1. Abrir el proyecto (Godot 4.6.x): sin avisos de recursos/UIDs faltantes; reimportar si lo pide.
2. Menú → Iniciar partida → Offline → slot → elegir 2 héroes → entra al piso (fondo, fuentes y botones con el mismo aspecto: ahora usan `UiStyles`).
3. Opciones (menú y desde pausa) y `PauseMenu` con Esc: abre/cierra, "Salir" confirma.
4. Mover héroes, abrir puertas, minimapa, luces de sala (clic central), construir un módulo (barra inferior → carta → slot), investigación.
5. Selección: clic sobre héroe, Ctrl+clic, F1/F2, Ctrl+1..3 y 1..3 (doble toque centra cámara), Tab. (Ahora en `HeroInputController`.)
6. Espacio: pausa táctica (cartel PAUSA, la cámara se mueve, se puede construir); Esc encima; reanuda. (Ahora en `PauseController`.)
7. Sala Loot: aparece el cofre en el mismo lugar y suma un hallazgo en el popup del héroe. (Ahora en `LootSpawner`.)
8. Morir → overlay de derrota con fundido de 2 s → Reintentar y Salir. Victoria → "Descender al piso N" y "Volver". (Ahora `DeathOverlay`/`VictoryOverlay`: revisar que **layout, textos y botones se vean igual**; es lo que más cambió en escena.)
9. VFX de combate/curación/mejora/construcción (escenas en `scenes/vfx/`), sprites de héroes/enemigos (`resources/sprite_frames/`), tiles del mapa (`resources/tilesets/`).
10. Steam: lobby/unirse con otro cliente (no tocado, sin test).
11. `git status` limpio tras cerrar el editor (ver incidente).

## Qué no pude verificar sin ejecutar el juego
Aspecto visual de cualquier UI (overlays de muerte/victoria con script nuevo, menús tras mover escenas, estilos de `UiStyles`), entrada real de ratón/teclado (los tests la simulan con `push_input`/llamadas directas; el orden de handlers `_input`/`_unhandled_input` se preservó por diseño, no por prueba manual), audio, Steam, rendimiento, y que el editor abra el proyecto sin avisos. Los tests headless solo prueban lógica y estructura de escena.

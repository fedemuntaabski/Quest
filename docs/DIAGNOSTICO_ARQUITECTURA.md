# Diagnóstico de arquitectura — Quest

Rama: `session/arch-1` (desde `session/balance-4`, HEAD `8201ba8`). Fecha: 2026-10-02.
Alcance: **solo análisis**. No se modificó código, escenas, resources ni se movió ningún archivo; el único archivo nuevo de la sesión es este.

## 0. Cómo se verificó (y qué NO se pudo)

| Medio | Resultado |
|---|---|
| Inventario | `git ls-files` (excluye `addons/`): 130 `.gd` (104 runtime, 20 `tests/`, 5 `tools/`, 1 `tests/tools/`), 34 `.tscn`, 97 `.tres`, 135 `.uid`. ~18.8k líneas GDScript (14.0k runtime). |
| Parser | `python -m gdtoolkit.parser` (gdtoolkit **4.5.0**; `gdparse` no está en PATH): **130/130 archivos parsean**, 0 fallos. Nota: gdtoolkit 4.5 vs Godot 4.6.2, la gramática podría ir atrasada. |
| Lint | `python -m gdtoolkit.linter` con config por defecto (no hay `gdlintrc`): 1029 avisos (ver §8). |
| Tests | Godot 4.6.2 headless (`--script res://tests/<x>.gd`), los 20 tests uno por uno: **17 pasan, 3 fallan** (ver §10). |
| Grafo/señales/huérfanos/código muerto | Scripts Python ad hoc (regex sobre `.gd/.tscn/.tres/project.godot`, comentarios excluidos). Viven en el scratchpad de la sesión, **no** en el repo. Los comandos reproducibles están en el Apéndice. |
| **Juego real** | **No se ejecutó con ventana ni se jugó.** Todo lo afirmado sobre comportamiento en partida sale de lectura de código y de tests headless. Visuales, sensación de juego, audio, Steam real (lobby/auth con otro cliente) y rendimiento: **sin verificar**. |

Limitaciones de los métodos: (a) las referencias se detectan por texto; cargas dinámicas con rutas armadas (`"res://assets/vfx/%s.tscn"`) cuentan como "referencia de patrón" solo si el literal está en el código, (b) "función sin llamadores" cuenta también menciones en strings, así que subestima el código muerto, (c) "cubierto por tests" = el test nombra la clase/ruta; los tests que arrancan `Main2d` ejercitan más código de forma indirecta.

---

## 1. Estructura de carpetas

```
/                      raíz
├─ project.godot       main_scene = scenes/Main.tscn; 9 autoloads; 17 input actions
├─ CLAUDE.md (141 l.)  guía del proyecto; arrastra referencias a `_deprecated/` y `assets/nuevos` que ya no existen
├─ NOTES_SESSION.md (1146 l.), CHANGELOG.md (17), README.md, CREDITS.md
├─ HANDOFF_*.md ×5, REVIEW_SESSION_10.md   notas de sesiones viejas en la raíz
├─ godot_debug_output.txt   log viejo versionado (menciona ActionQueue/MapNavigationHelper, borrados)
├─ translations.csv/.en/.es 25 filas (solo el menú de opciones)
├─ default_bus_layout.tres  layout de audio (Godot lo carga por nombre; NO es huérfano)
├─ Sprites/Player/_Idle.png 1 PNG, solo lo usa un .tres huérfano (ver §9)
├─ QuestIcon.png, icon.svg, bazingastudio.png
├─ addons/godotsteam/       GodotSteam (138 MB en disco, binarios multiplataforma)
├─ assets/                  1179 archivos versionados (724 en art/_source)
│  ├─ art/_source/          packs originales intactos (0x72, Kenney, Tiny Creatures, hojas de items)
│  ├─ art/{tiles,characters,enemies,items,ui,vfx}/   copias curadas por categoría (+ index.json de vfx)
│  ├─ characters/*.tres     24 SpriteFrames (héroes, enemigos, tc_*)       ← RESOURCES dentro de assets/
│  ├─ tilesets/*.tres       2 TileSet                                       ← RESOURCES dentro de assets/
│  ├─ vfx/*.tscn            7 escenas de efectos                            ← ESCENAS dentro de assets/
│  ├─ portraits/, ui/, audio/, fonts/, texture/enviorment/ (typo)
├─ resources/               datos `.tres`: abilities(8) characters(5) enemies(20) floors(6) items(19) maps(4) research camera upgrades vfx ui sprites tileset
├─ scenes/                  16 .tscn sueltas + entities/ ui/ world/ (8)
├─ scripts/
│  ├─ core/                 abilities actions art balance camera combat floors items movement player research stats theme utils vfx
│  ├─ entities/             Enemy, CharacterVisual
│  ├─ managers/             15 scripts (autoloads + escena + por-piso, mezclados)
│  ├─ network/              SteamManager, SteamLobbyManager
│  ├─ ui/                   BuildingMenu.gd suelto + character_select/ hud/ menus/ overlays/ visual/
│  └─ world/                15 scripts + map/ (9)
├─ tests/                   20 tests + tests/tools/shot_map.gd
├─ tools/                   5 generadores/herramientas (build_*, normalize_assets, balance_sim)
└─ docs/                    ASSETS, BALANCE (+balance/*.csv), ENEMY_TARGETING, ENTITY_VISUALS, MAP_RENDER, MISSING_ICONS, ROOMS
```

**¿El nombre refleja el contenido?**

| Carpeta | Veredicto | Evidencia |
|---|---|---|
| `scripts/managers/` | **No.** Mezcla 3 cosas distintas: autoloads (`SaveManager`, `SettingsManager`, `ResourceManager`, `GameSession`, `SelectionManager`), composición de escena (`Main`, `Main2d`, `Main2dDeathHandler`, `Main2dVictoryHandler`, `GameStateManager`) y sistemas por piso (`FloorManager`, `EnemyManager`, `ExtractionManager`, `VfxManager`) + `ManagerLocator`. | `ls scripts/managers` |
| `scripts/core/actions/` | **Parcial.** `BaseAction/MoveAction/EnemyMoveAction` son acciones; `DoorTurnSystem` y `RoomPowerSystem` son sistemas de partida. | `scripts/core/actions/` |
| `scripts/core/floors/` | **No.** Contiene `EnemyType`, `EnemyPool` (datos de enemigos) junto a `FloorConfig`, `RoomTypeRule`. | `scripts/core/floors/` |
| `scripts/core/stats/` | **Parcial.** Además de stats tiene `PartyConfig`, `UpgradeConfig`, `CharacterDatabase`, `CharacterData`. | |
| `scripts/entities/` | **Dudoso.** Solo `Enemy` y `CharacterVisual`; `Player` vive en `core/player/` y usa `CharacterVisual`. | |
| `scripts/ui/` | **Inconsistente.** `BuildingMenu.gd` suelto en la raíz de `ui/` (es un widget del HUD); `ui/character_select/` tiene 1 archivo (`CharacterCardOption`, lo usa `WaitingRoom`, no la selección de héroes, que es `menus/HeroSelectMenu`). | |
| `scripts/world/` + `world/map/` | **Aceptable**, pero mezcla nodos de juego (`Module`, `Nexo`, `Door`, `RoomZone`) con sistemas (`ModuleBuildSystem`) y `FloorGenerator` (grilla lógica oculta). | |
| `scenes/` | **Inconsistente.** 16 escenas sueltas y 3 subcarpetas (`entities`, `ui`, `world`); `HUD.tscn` en raíz, `BuildingMenu.tscn` en `ui/`. | |
| `assets/` vs `resources/` | **No hay criterio.** `assets/characters/*.tres`, `assets/tilesets/*.tres` y `assets/vfx/*.tscn` son resources/escenas; los datos están en `resources/`. `assets/art/vfx` (frames) vs `assets/vfx` (escenas). `assets/texture/enviorment` con typo. `Sprites/` en la raíz con mayúscula. | |
| Raíz | Ruidosa: 5 HANDOFF + REVIEW + NOTES + log viejo. | |
| `_deprecated/` | **No existe** (borrado en `8b0733e "CAMBIOS A LOS MODELOS"`), pero `CLAUDE.md` lo cita 10 veces como lugar de snapshots. | `git log --diff-filter=D -- _deprecated` |

---

## 2. Autoloads / singletons

`project.godot [autoload]` — 9 entradas:

| Autoload | Líneas | Responsabilidad | Estado propio | Observación |
|---|---|---|---|---|
| `PlayerStats` | 281 | HP base, stats por héroe (`heroes`), niveles de run (`run_levels`), hallazgos (`found_items`), señales `stats_changed/player_died/...` | Sí, mezcla persistente y de run | Hace 4 cosas: registro de héroes vivos, balance de upgrades, inventario de hallazgos, "héroe activo". `active_hero_id` es un getter que lee `SelectionManager` (`PlayerStats.gd:28`) y `SelectionManager` lee `PlayerStats` (`SelectionManager.gd:122,155`): acoplamiento bidireccional entre autoloads. |
| `SaveManager` | 148 | Slots en `user://slot_N.cfg` | Sí | Persiste solo `base_hp`, `selected_character_id`, `run_cycle`, `playtime`, flags (§7, "Guardado"). |
| `ThemeManager` | 124 | Builders de `StyleBoxFlat` | **No** (todo `static func`) | No necesita ser autoload. 20 de sus 23 funciones **no tienen llamadores** (§8). Es la causa raíz del ruido `Identifier not found: ThemeManager` en `--script` (§10). |
| `SettingsManager` | 231 | Audio/video/gameplay a `user://settings.cfg`, aplica al arrancar | Sí | Cohesivo. |
| `FPSOverlay` | 37 | Contador FPS | UI | Autoload para un overlay: aceptable. |
| `SteamManager` | 203 | Init Steam (AppID 480), tickets de auth, `connected_clients`; hijo `SteamLobbyManager` | Sí | `_process` solo corre `run_callbacks` si Steam inicializó (`SteamManager.gd:47`). AppID 480 = app de pruebas (`SteamManager.gd:3`, `steam_appid.txt`). |
| `ResourceManager` | 160 | 4 recursos + **investigación** (`research`, `is_unlocked`, `get_bonus`) + bonus de generadores | Sí (de run) | Mezcla economía y árbol de investigación (`ResourceManager.gd:108-160`). Rendimientos base (`:16-19`) y recursos iniciales (`reset_resources`, `:92`) hardcodeados. Lo resetea `Main._begin_new_run()`. |
| `GameSession` | 37 | Pareja elegida en `HeroSelectMenu` | Sí | Una de **cuatro** fuentes de verdad de la selección de héroes (§7). |
| `SelectionManager` | 157 | Selección en partida y grupos de control 1-3 | Sí (de run) | Devuelto como `Node` sin tipo por `ManagerLocator` (`ManagerLocator.gd:36`). |

**¿Acumulan demasiadas?** 9 es manejable; el problema no es la cantidad sino que **5 de ellos tienen estado de run** (`ResourceManager`, `PlayerStats`, `SelectionManager`, `GameSession` + `FloorManager._seen_types` estático) y se reinician a mano desde `Main._begin_new_run()` (`Main.gd:131-145`). No existe un concepto "Run" propio. Ver Riesgo A3.

`ManagerLocator` (`class_name`, `extends Object`, 183 líneas) envuelve autoloads **y** búsquedas por grupo (15 grupos: `add_to_group` ×15). 20 getters; llamados 174 veces en runtime (`get_resource_manager` 31, `get_selection_manager` 19, `get_player_stats` 18, `get_steam_manager` 16...). Cinco devuelven `Node` sin tipo (`get_game_session`, `get_selection_manager`, `get_settings_manager`, `get_steam_manager`, `get_floating_text_manager`) → se pierde el chequeo estático, aunque otros tres autoloads sin `class_name` sí se devuelven tipados (`as SaveManager`, `as ResourceManager`, `as PlayerStats`, `ManagerLocator.gd:22,28,48`). Además hay uso directo de los nombres de autoload (`ThemeManager.` 24, `SettingsManager.` 7, `ResourceManager.` 7, `PlayerStats.` 4) saltándose el locator: la regla "pasar siempre por ManagerLocator" de `CLAUDE.md` no se cumple.

---

## 3. Escenas principales y jerarquía

**Composición (quién instancia a quién):**

```
Main.tscn (Node, scripts/managers/Main.gd, group main_orchestrator, PROCESS_MODE_ALWAYS)   ← run/main_scene
├─ WorldContainer (Node2D)      ← Main2d.tscn (start_gameplay / reload_gameplay / advance_floor)
├─ UIContainer (CanvasLayer)    ← MainMenu.tscn | WaitingRoom.tscn
├─ HUDContainer (Node)          ← HUD.tscn (se instancia JUNTO con Main2d, hermano, no hijo)
└─ TransitionOverlay (CanvasLayer 200) / ColorRect   (fundido vía MenuTransitionFX)
```

- `Main` hace `preload` de 4 escenas (`Main.gd:10-13`) y expone `show_main_menu / start_gameplay / go_to_waiting_room / reload_gameplay / advance_floor / return_to_main_menu`. Es el único dueño de `current_floor` y `run_seed` (`Main.gd:25,28`).
- **Menú:** `MainMenu.tscn` (Control: fondo, perfil, 3 botones, `OptionsMenu` hijo, `AnimationPlayer`) + `MainMenuFlow` (`RefCounted`, 424 líneas, no es nodo; instancia `SlotSelection`, `NetworkModeSelect`, `HeroSelectMenu` — `MainMenuFlow.gd:64,81,108`). `CLAUDE.md` no menciona `MainMenuFlow`.
- **Selección de héroes:** `HeroSelectMenu.tscn` es un `Control` vacío; **toda la UI se construye en código** (`HeroSelectMenu._build_ui`, 82 líneas, `:80`).
- **Partida:** `Main2d.tscn` = `Floor` (TileMapLayer lógico, oculto), `RoomManager`, `PlayerActionController`, `Doors`, `PauseMenu`, `DeathOverlay`, `VictoryOverlay`. En `_ready()` Main2d crea **por código** 9 sistemas hijos (`DoorTurnSystem`, `FloorManager`, `RoomPowerSystem`, `ModuleBuildSystem`, `EnemyManager`, `ExtractionManager`, `ExitIndicator`, `NexoController`, `GameStateManager`) y los héroes/Nexo/`MapTileRenderer` (`Main2d.gd:90-115`). Es la raíz de composición **y** además controla input, selección, cofres y pausa táctica (§8).
- **HUD:** `HUD.tscn` (CanvasLayer) con `Control/{InvasionFlash, TopLeft, BottomBar{BuildingMenu, BottomRow{ResourcePanel, BuildPanel}}, Portraits, StatTooltip}`. `HUDController` agrega **por código** el panel de investigación, pausa táctica, alerta del Nexo, hint, minimapa y retratos (`HUDController.gd:138-254`). Dos estilos de construcción conviven; los nodos de escena se obtienen con rutas largas en strings (`HUDController.gd:9-10,12-29`, 15 `get_node_or_null`).
- **Pausa:** dos mecanismos independientes. (1) Esc → `PauseMenu` (`BaseMenu`, CanvasLayer) → `GameStateManager` pone `get_tree().paused`. (2) Espacio → `Main2d._tactical_paused` → `Engine.time_scale = 0` (`Main2d.gd:474-477`). La fuga del segundo se parchea a mano en 3 sitios (`Main.gd:65,116`, `Main2d._exit_tree:458`).
- **Jugador:** `Player.tscn` = `Player(Node2D)/{AnimatedSprite2D, Camera2D(GameCamera), Stats, Hurtbox, Hitbox}`. Main2d borra la `Camera2D` de los héroes 2+ en runtime (`Main2d.gd:142`). Hay una escena por héroe instanciada N veces, no una por tipo.
- `Main2d/PauseMenu`, `MainMenu/OptionsMenu` y `PauseMenu/{OptionsMenu, ExitConfirmDialog}` son escenas instanciadas dentro del `.tscn` (aparecen sin `type` en el árbol).

---

## 4. Mapa de dependencias entre scripts

Método: 104 scripts runtime, aristas = `preload/load("res://…gd")` + uso de `class_name`/nombre de autoload en código no comentado. Resultado: **un solo componente fuertemente conexo de 38 scripts**, y su causa es `ManagerLocator`:

- Sin `ManagerLocator` ni `Logger` el componente se descompone en **4 ciclos pequeños**:
  1. `Module ↔ GeneratorModule ↔ TurretModule ↔ ResearchEntry` (base ↔ subclases; `ResearchEntry` usa `Module.ModuleType`).
  2. `RoomZone ↔ EnergyButton ↔ RoomLight` (padre ↔ hijos).
  3. `Enemy ↔ EnemyMoveAction ↔ Player ↔ HeroAbilities ↔ Nexo` (entidades que se conocen entre sí: `Enemy` busca héroes y Nexo, `Player` expone habilidades).
  4. `Main ↔ WaitingRoom` (`WaitingRoom` llama `ManagerLocator.get_main_orchestrator().start_gameplay()`, `Main` hace `preload` de `WaitingRoom`).
- Los pares mutuos (16) incluyen `ManagerLocator ↔ {PlayerStats, SaveManager, Main, EnemyManager, ExtractionManager, FloorManager, Nexo, Player}`: el locator conoce el tipo concreto y el tipo concreto usa el locator. En GDScript no rompe porque `class_name` resuelve al compilar, pero impide aislar cualquier sistema en un test sin cargar media base.

**Fan-in (más dependidos):** `ManagerLocator` 38, `Logger` 27, `QuestPalette` 17, `RoomManager` 14, `Module` 13, `RoomData` 12, `CharacterData` 9, `ThemeManager` 9.
**Fan-out (más dependen de otros):** `Main2d` 30, `ManagerLocator` 16, `HUDController` 16, `Enemy` 13, `RoomZone` 13, `RoomManager` 12, `FloorManager` 11.

**Acoplamiento fuerte observado (con evidencia):**

| Acoplamiento | Evidencia |
|---|---|
| Grupo `"hud"` por string desde 4 sitios, sin tipo ni contrato | `FloorManager.gd:101,103` (`call_group("hud","show_hint")`), `Main2d.gd:383` (`hud.building_menu` sobre un `Node` sin tipo), `Main2d.gd:477` (`call_group("hud","set_pause_label")`), `ModuleBuildSystem.gd:27` |
| Un sistema por-piso busca a otro por grupo en vez de recibirlo | `ResourceManager.gd:70` (`get_nodes_in_group("generators")`: un autoload lee nodos de la escena) |
| Main2d conoce los nodos internos de los overlays | `Main2d.gd:49-54` (6 rutas `$DeathOverlay/CenterContainer/VBoxContainer/...`) |
| `Main` hace reset de 5 sistemas ajenos | `Main.gd:131-145` |
| IDs con vocabulario mezclado: `zone_id`, `room_id`, `group_id` | `DoorTurnSystem.rooms` indexa por *group id* pero se llama `room_id`; `Main2d.gd:270` `door.target_room_id = room_manager.get_group_id(corridor.id)` |
| Singleton dentro de escena por string | `Main2d.gd:459` `get_first_node_in_group("vfx_manager")` aunque existe `ManagerLocator.get_vfx_manager()` |

Acoplamiento **sano** (para no tocar): `RoomManager`/`RoomZone` ↔ `PlayerActionController` por señales; Resources de datos (`FloorConfig`, `EnemyType`, `MapVisualConfig`...) sin dependencias hacia escenas.

---

## 5. Señales y eventos

Totales: 84 `signal` declaradas en runtime, 207 `.connect(` en código + 3 conexiones en `.tscn`. Todas las señales están emitidas **o** conectadas excepto lo siguiente.

**Emitidas pero nadie las escucha (14):**

| Señal | Archivo | Comentario |
|---|---|---|
| `door_opened` | `DoorTurnSystem.gd:13` (emit `:47`) | Redundante con `room_revealed` |
| `enemy_wave_requested` | `DoorTurnSystem.gd:17` (emit `:68`) | `CLAUDE.md` la declara "kept for any future listener" |
| `room_energized` | `RoomPowerSystem.gd:8` | El único propósito del script |
| `pause_requested`, `resume_requested`, `death_entered` | `GameStateManager.gd:19-21` | Main2d solo escucha `victory_entered` y `state_changed` |
| `ability_used` | `HeroAbilities.gd:11` | Ningún HUD/VFX la usa (los VFX se llaman directo) |
| `completed` | `BaseAction.gd:4` | `finish()` la emite; ningún llamador la espera |
| `_batch_done` | `PlayerActionController.gd:18` | Se usa con `await` internamente, no es API; además el nombre con `_` incumple `signal-name` |
| `client_rejected` | `SteamManager.gd:7` | Sin UI que la muestre |
| `menu_opened`, `menu_closed` | `BaseMenu.gd`, `BaseSubPanel.gd` (×2 cada una) | Duplicadas, sin oyente |

**Conectadas pero nunca emitidas:** ninguna (el chequeo inicial `attack_changed` fue falso positivo: se emite en `CharacterStats.gd:78,84`).

**Observaciones de diseño:**
- Los emisores tienen oyentes únicos en su mayoría; el bus de eventos **de hecho** es `RoomManager` (re-emite `zone_clicked/hovered/room_powered/room_power_changed/slot_clicked`) y `ResourceManager.resource_changed`. No hay un bus global (correcto para este tamaño).
- `Main2d._connect_signals` protege cada `connect` con `is_connected` (`Main2d.gd:324-351`): el nodo se crea una vez por piso, el guard no hace falta (ruido).
- `PlayerStats.player_died` se conecta desde un nodo de escena (`Main2d`) a un autoload: se limpia solo al liberar Main2d (Callable de objeto liberado), OK.

---

## 6. Datos y configuración

**Resources personalizados existentes (bien resuelto):** `FloorConfig` (+`RoomTypeRule`, `EnemyPool`, `EnemyType`), `MapVisualConfig`/`RoomTypeVisualConfig`, `CameraConfig`, `UpgradeConfig`, `ResearchConfig/ResearchEntry`, `VfxConfig`, `PartyConfig`, `CharacterData`, `AbilityData`, `ItemData`, `HealthBarStyle`, `MapLayout/RoomData/CorridorData`. Más de 90 `.tres` para enemigos/ítems/habilidades. La sesión de balance pudo cambiar números solo tocando `.tres` (`d9c5971`), lo cual es una señal de buena arquitectura de datos.

**Valores que siguen en código y deberían ser datos:**

| Dónde | Qué | Propuesta |
|---|---|---|
| `Module.gd:17` `CATALOG` (+ `TYPE_COLORS :25`, `DESCRIPTIONS :34`, `RESOURCE_LABELS :42`) | Hp/costo/rendimiento/daño/escena de los 5 módulos | `ModuleData` Resource (como `AbilityData`/`ItemData`) |
| `Enemy.gd:13` `VARIANT_CONFIG` | HP/velocidad/intervalo/daño de 3 comportamientos; luego `EnemyType` los pisa con centinela `-1` (`resolved_*`, `Enemy.gd:37-55`) | Dos capas para un mismo dato; mover base a `.tres` y quitar centinelas |
| `ResourceManager.gd:16-19, :92` | Rendimiento base por turno (2/2/1/0) y recursos iniciales (15/15/10/20) | `EconomyConfig` o dentro de `FloorConfig` |
| `RoomZone.POWER_COST` (const, + investigación) | Costo de encender sala | Ya parcialmente en `ResearchEntry`; mover base a config |
| `HUDController.gd:4-7` | Textos de tooltips de recursos | Traducciones |
| `Main2d.gd:18-20, 27-29` | Offsets de Nexo/cofre, margen de click, doble tap | OK como consts de escena; los de gameplay → config |
| `FloorManager.gd:14-16` | Offsets/intensidad de banners | `MapVisualConfig` |
| `PlayerStats`/`StatBalance` (25 l.) | HP/clamp | Ver "Guardado" |
| `ItemData.gd:16-18`, `UpgradeConfig.gd:10` | Etiquetas de rareza/slot/stat en español | Traducciones |
| Tests | Valores esperados literales (0.7, 160, 10) | Leer del `.tres` (causa de 3 tests rotos, §10) |

**Textos / i18n:** `translations.csv` tiene 25 claves y `tr()` aparece en **1 archivo** (`OptionsMenu`, 24 usos). Toda la UI de juego (HUD, build menu, popups, banners, selección de héroes, items, investigación) está hardcodeada en español: ≥37 literales con acentos en `scripts/` (heurística; los textos sin acento como "Recoger" no se cuentan) más los textos de `.tres`/`.tscn`. El menú de opciones ofrece selector de idioma (`KEY_LANGUAGE`) que solo cambia ese menú. **La internacionalización está a medias.**

---

## 7. Sistemas del juego

Estado: **Completo** = implementado y con evidencia (test o uso en el flujo); **Parcial** = existe pero incompleto o con deuda; **Roto** = falla verificada.

| Sistema | Archivos | Responsabilidad | Estado | Evidencia |
|---|---|---|---|---|
| Combate Hitbox/Hurtbox | `core/combat/{Hitbox,Hurtbox}Component`, `Player.gd`, `Enemy.gd`, `TurretModule.gd` | Auto-ataque por capas físicas, números de daño | **Completo** (el test del radio está desactualizado, no el código) | `test_sprites` falla en `hero attack hitbox radius changed`: espera 160 px, pero `Player._apply_attack_range` (`Player.gd:51,123`) ahora toma `CharacterData.attack_range` (130-220 según héroe, `resources/characters/*.tres:20`); `test_enemy_roles` OK. Torretas usan `DetectionZone` propio, no estos componentes (duplicación de modelo). |
| IA de enemigos | `entities/Enemy.gd` (443), `EnemyManager`, `core/floors/EnemyType/EnemyPool`, `core/actions/EnemyMoveAction` | Roles HUNTER/RAIDER, aggro, oleadas | **Completo** | `test_enemy_roles` (65 errores de `--script` conocidos, resultado OK), `test_raider_timing` OK |
| Progresión de pisos | `FloorManager`, `FloorConfig`, `Main.advance_floor`, `Main2d._on_floor_completed` | 5 pisos, multiplicadores, semilla por piso | **Parcial** (lógica OK; reset de run disperso) | `test_map_flow` ejecuta pisos 1-3 y falla solo por esperar 10 de ciencia en una sala de tipo y recibir 12 (pasiva de héroe, ver §10) |
| Generación de mapa | `world/map/{MapGenerator,MapLayout,RoomData,CorridorData}`, `FloorConfig` | Árbol sembrado + bucles + tipos de sala | **Completo** (mejor cubierto) | `test_map_generator` (OK), `test_rooms` (30 semillas × 5 pisos), `test_corridor_picking` |
| Render del mapa | `MapTileRenderer`, `DungeonTiles`, `FloorGenerator` (grilla oculta), `RoomZone` | Tiles, puertas como `Sprite2D`, props por tipo | **Completo** pero con **dos mapas paralelos**: `Floor` lógico oculto + `MapTileRenderer` | `test_tile_renderer`, `test_door_alignment` OK; `floor_layer.visible = false` (`Main2d.gd:189`) |
| Luces | `RoomLight`, `ExitIndicator`, `MapVisualConfig`, `RoomManager/DarkCanvas` | Sala oscura/encendida, indicador de salida | **Completo** | `test_room_type_visuals`, `test_hud_ui`; `RoomLight.is_dark` solo la usa un test |
| Polvo (4º recurso) | `ResourceManager`, `FloorManager.on_room_discovered`, `RoomZone.toggle_power` | Polvo por descubrir sala, costo de iluminar | **Completo** | `test_map_flow` (dust/fog) |
| Módulos y slots | `Module`, `GeneratorModule`, `TurretModule`, `BuildingSlot`, `BuildingMenu`, `ModuleBuildSystem` | Construir generadores/torretas/trampas | **Completo**; `ModuleBuildSystem` es solo un reenvío (31 líneas) | `test_hud_ui` (BuildingMenu), `GeneratorModule`/`ModuleBuildSystem` sin test directo |
| Energía de sala | `RoomZone.toggle_power`, `RoomPowerSystem` | Pagar polvo, encender | **Completo**; `RoomPowerSystem` es un shell de 25 líneas sin lógica | `RoomPowerSystem.gd` (solo log + `room_energized` sin oyentes) |
| Nexo + extracción | `Nexo`, `NexoController`, `ExtractionManager`, `Main2dVictoryHandler` | Recoger, fase de extracción, victoria | **Completo** | `test_enemy_roles`, `test_raider_timing`, `test_map_flow` |
| Tienda | — | — | **No existe** (la tienda de Oro y la moneda se eliminaron en `session/fix-3`); verificado: `git grep -i "gold\|store"` no devuelve nada funcional en `scripts/`. `docs/ROOMS.md` y `CLAUDE.md` lo registran | |
| Selección de héroes (menú) | `HeroSelectMenu` (423), `GameSession`, `MainMenuFlow`, `CharacterDatabase/CharacterData` | Elegir 2 de 4 | **Completo** | `test_hero_select` OK |
| Selección en partida | `SelectionManager`, `Main2d._input/_unhandled_input`, `HeroPortrait`, `HUDController` | Multi-selección, grupos 1-3, Tab | **Completo**, pero la lógica de input vive en `Main2d` (`:353-455`) | `test_selection` (67 checks) OK |
| HUD | `HUDController` (443), `StatPanelUI`, `StatIcon`, `HeroPortrait`, `CharacterPopup`, `Minimap`, `ResearchPanel`, `BuildingMenu` | Recursos, retratos, popups, minimapa | **Completo**; 1 test rojo por valor de balance | `test_hud_ui` falla en `interval_at(1.0, 3)` (esperaba 0.7; `run_upgrade_config.tres` ahora 0.05/nivel, `d9c5971`) |
| Investigación | `ResourceManager`, `ResearchConfig/Entry`, `ResearchPanel` | Gastar Ciencia, desbloquear módulos | **Completo** | `test_hud_ui` |
| Habilidades | `core/abilities/*`, `Player`, `resources/abilities` | Pasiva/activa por héroe, tecla Q | **Completo** | `test_abilities` OK |
| VFX | `VfxManager`, `core/vfx/*`, `assets/vfx/*.tscn` | Pool y tope de efectos | **Completo** | `test_vfx` OK |
| Cámara | `GameCamera`, `CameraConfig` | Seguir/paneo/zoom/límites | **Completo** | cubierto vía `test_*` que la consultan |
| Pausa | `PauseMenu`, `GameStateManager`, `Main2d` (tactical) | Esc + Espacio | **Parcial**: dos mecanismos; 7 helpers de `GameStateManager` sin llamadores | §8 |
| Guardado | `SaveManager`, `SaveSlotSelector` | Slots | **Parcial**: solo persiste `base_hp`, personaje, `run_cycle`, playtime. `increment_run_cycle`/`set_run_cycle`/`get_run_cycle` **no tienen llamadores**, `post_victory_popup_pending` nunca se escribe, `clamp_player_hp(x, x)` clampa un valor contra sí mismo (`SaveManager.gd:75,117`), clave legacy `contracts_completed` (`:85,109`) | |
| Multijugador | `SteamManager`, `SteamLobbyManager`, `WaitingRoom`, `NetworkModeSelect` | Lobby Steam + autenticación | **Parcial**: lobby/auth sí; **no hay replicación de partida** (único `@rpc` es de auth; `WaitingRoom.gd:184` llama `start_gameplay()` local). Sin tests. AppID de prueba 480. | |
| Opciones | `OptionsMenu` (668), `SettingsManager` | Audio/video/jugabilidad | **Completo**, sin tests | |

---

## 8. Calidad de código

**Tipado estático: muy bueno.** 1238 de 1247 funciones declaran retorno (`->`, 99.3 %); 2151 `var` con tipo/inferencia contra 37 sin tipo. Los sin tipo: `MenuTransitionFX` (3/3), `StatPanelUI` (2/5), `StatIcon`, `MainMenuFlow`, `FloatingText`, `FloatingTextManager` (1 cada uno). Los `Node` sin tipo del locator (§2) son la brecha real.

**Scripts largos (runtime, >250 líneas):** `RoomManager` 681, `OptionsMenu` 669, `Main2d` 538, `Enemy` 444, `HUDController` 444, `MainMenuFlow` 425, `HeroSelectMenu` 424, `RoomZone` 348, `BuildingMenu` 342, `PlayerStats` 282, `BalanceSim` 262 (solo la usan tests/tools), `CharacterPopup` 261.

**Responsabilidades múltiples:**
- `Main2d` (538, fan-out 30): composición de 9 sistemas + spawn de héroes/Nexo + **cofres de sala Loot** (`:298-310`, no es su trabajo) + **input global** (`_input` `:353`, `_unhandled_input` `:378`) + **selección/grupos/doble tap/cámara** (`:420-455`) + pausa táctica + overlays de muerte/victoria + navegación entre escenas (`:518-537`).
- `RoomManager` (681, 66 funciones, `max-public-methods` de gdlint): datos del grafo, fábrica de `RoomZone`, consultas (módulos, salas oscuras, encendidas), pathfinding (`find_zone_path :528`), validación (`validate_graph :454`, `validate_visibility :638`), presentación (`apply_zone_visibility :594`), creación del `DarkCanvas` (`:151`).
- `HUDController`: orquesta 8 widgets, muchos construidos en código dentro del mismo script.
- `PlayerStats`: ver §2.
- `OptionsMenu` 669 líneas: tres pestañas en un solo archivo.

**Funciones largas (>60 líneas, runtime, 7):** `HeroSelectMenu._build_ui` 82, `CharacterPopup._build` 77, `MapLayout.validate` 75, `OptionsMenu._sync_from_settings_manager` 69, `HUDController._ready` 66, `BuildingMenu._make_card` 64, `HeroPortrait._ready` 62. Ninguna es crítica; son constructores de UI en código.

**Código duplicado:**
- `BaseMenu` (CanvasLayer) vs `BaseSubPanel` (Control): **95 % idéntico** (difflib 0.95), mismas señales `menu_opened/menu_closed`.
- `Main2dDeathHandler` vs `Main2dVictoryHandler`: 56 %, mismo patrón `setup(main2d, overlay)` + `show_*_screen`.
- Bloque de HP (`take_damage`/`die`/`clamp`) copiado en `Module.gd:95`, `Enemy.gd:150`, `CharacterStats.gd:53` (reconocido en comentarios de `Enemy.gd`).
- Torretas (`DetectionZone`+`FireTimer`) vs combate Hitbox/Hurtbox: dos modelos de ataque.
- `Floor` oculto + `MapTileRenderer`: dos representaciones del mapa.

**Código muerto (51 funciones públicas sin ningún llamador + 22 solo usadas por tests):**
- `ThemeManager`: 20 de 23 (`build_ap_badge_style`, `get_combat_feedback_palette/timing`, 17 `tactical_*`). Vestigios del sistema AP/tablero eliminado.
- `GameStateManager`: `is_paused`, `is_victory`, `can_process_input`, `can_process_turns`, `set_state`, `toggle_pause`, `return_to_previous_state`.
- `RoomManager`: `has_zone`, `get_zone_at_cell`, `get_all_modules`, `are_rooms_connected`, `is_path_open`, `get_adjacent_rooms`, `are_connected`.
- `SaveManager`: `get_run_cycle`, `set_run_cycle`, `increment_run_cycle`, `set_selected_character_id`.
- Otros: `ResourceManager.add_all`, `DoorTurnSystem.get_room_cells`, `Player.set_grid_position`, `Door.mark_opened`, `StatPanelUI.update_stats`, `FloatingTextManager.spawn_text_from_host`, `ItemCatalog.get_item`, `ArtConfig.art_px`, `Logger.{debug,set_min_level,set_category_enabled}`, `ManagerLocator.{get_room_power_system,get_module_build_system}`.
- `QuestPalette`: 8 de 46 constantes sin uso (`DUNGEON_ASH`, `METAL`, `UI_TEXT_READY`, `UI_TEXT_WARN`, `COMBAT_TEXT_HEAL`, `CARD_STRENGTH`, `CARD_AGILITY`, `CARD_MAGIC`).
- Solo tests: `BalanceSim.*` (herramienta), getters de `GameCamera`, `HeroAbilities.is_ready`, etc. (legítimo como API de inspección).

**Nombres inconsistentes:** `Nexo` (clase) vs `damage_vs_nexus` / `nexus_rows` / `*_nexus.csv`; `Player` = héroe, grupo `"player"`, `PlayerStats` guarda héroes; `zone/room/group` (§4); `Main` vs `Main2d` (el segundo es "la escena del piso"); `GameSession` vs `SelectionManager` vs `PartyConfig`; typo `enviorment`; `wizzard` (heredado del pack, aceptable).

**`_process`/`_physics_process`:** **no hay `_physics_process`** en runtime (movimiento por `Tween`/acciones; física solo por `Area2D`). `_process` en 7 scripts, todos razonables: `Minimap` y `ExitIndicator` lo activan solo si hace falta (`set_process`), `SteamManager` solo con Steam, `GameCamera` y `CharacterVisual` por frame. Mejorables: `HeroAbilities._process` emite `cooldown_changed` **cada frame** mientras hay cooldown (podría ser `Timer`/tween), y `CharacterVisual._process` corre por cada enemigo.

**Convenciones GDScript 2.0 (gdlint):** `class-definitions-order` **284** (no-test: `Enemy` 26, `HUDController` 23, `Main2d` 22, `RoomZone` 18, `Module` 12; típico: consts/signals después de vars/funciones estáticas), `max-line-length` 735 (límite 100 por defecto; `.editorconfig` no define ninguno; 81 en `ui/menus`, 44 en `ui/hud`), 3 `trailing-whitespace` (`Main2dDeathHandler.gd:21,26`, `WaitingRoom.gd:68`), `signal-name` ×1 (`_batch_done`), `function-preload-variable-name` ×1 (`ManagerLocator.gd:159`), 2 `unused-argument`, `max-public-methods` ×1 (`RoomManager`). Se usa `QuestLogger` en lugar de `print` (los 34 `print(` restantes son tests y el propio Logger). `PlayerStats`/`SaveManager` hacen `const StatBalance = preload(...)` sombreando el `class_name` global (`PlayerStats.gd:3-4`) por el problema de `--script`.

---

## 9. Archivos huérfanos

| Archivo | Evidencia | Acción sugerida |
|---|---|---|
| `resources/sprites/shared_player_idle_frames.tres` | Ninguna escena/script/resource lo referencia; los héroes usan `assets/characters/hero_*.tres` (`resources/characters/mage.tres:5`). `docs/ENTITY_VISUALS.md:7` aún dice lo contrario | eliminar |
| `Sprites/Player/_Idle.png` | Solo lo usa el `.tres` anterior | eliminar con él |
| `resources/tileset/highlight_tileset.tres` | `CLAUDE.md` lo declara huérfano; ningún `.tscn` lo carga | eliminar |
| `assets/texture/enviorment/highlight_placeholder.png` | Solo lo usa el tileset anterior | eliminar con él |
| `godot_debug_output.txt` | Log viejo versionado (menciona `ActionQueue`, ya borrado) | eliminar, añadir a `.gitignore` |
| `assets/ui/background.png`, `assets/ui/256x256 textures (113).png` | Sin referencia literal en código/escenas/resources (`mainbackground.png` sí se usa) | verificar en el editor y eliminar |
| `scripts/core/balance/BalanceSim.gd` | Solo `tests/` y `tools/` lo usan | mantener; mover a `tools/` o `tests/support/` (no se exporta con el juego) |
| `HANDOFF_*.md` ×5, `REVIEW_SESSION_10.md` | Notas históricas | mover a `docs/archive/` |
| Arte curado (`assets/art/{characters,enemies,items,tiles,ui,vfx}`) | De 455 archivos, ~304 sin referencia literal (characters 70, enemies 32, items 50, tiles 75, ui 35, vfx 42). **Cautela:** se cargan por tablas/patrones (`Pickup.TEXTURES`, `VfxEffect.SHEET_PATH`, `tools/build_*`), así que es lista de candidatos, no de borrado | baja prioridad; revisar con la herramienta de `tools/normalize_assets.gd` |
| `default_bus_layout.tres` | Aparece como no referenciado pero **Godot lo carga por nombre**: no es huérfano | — |

Scripts: **ningún script runtime está huérfano** (`BalanceSim` solo por tests/tools). Todas las escenas `.tscn` están referenciadas.

---

## 10. Tests y cobertura real

Ejecución (Godot 4.6.2 headless, un test por vez, 2026-10-02, HEAD `8201ba8`):

| Test | Líneas | Arranca `Main2d` | Resultado |
|---|---|---|---|
| test_abilities | 164 | sí | OK |
| test_art_config | 12 | no | OK |
| test_assets_art | 61 | no | OK |
| test_balance | 99 | no | OK |
| test_corridor_picking | 115 | sí | OK |
| test_door_alignment | 116 | sí | OK |
| test_enemy_roles | 268 | sí | OK (62 s) |
| test_hero_select | 184 | sí | OK |
| **test_hud_ui** | 615 | sí | **FALLA** `interval_at(1.0, 3)` |
| test_items | 82 | no | OK |
| **test_map_flow** | 408 | sí | **FALLA** `types (seed 0 floor 3): 'room_4' reward 12 science, expected 10` |
| test_map_generator | 229 | no | OK |
| test_party | 380 | sí | OK |
| test_raider_timing | 77 | sí | OK |
| test_room_type_visuals | 116 | no | OK |
| test_rooms | 244 | sí | OK |
| test_selection | 405 | sí | OK |
| **test_sprites** | 204 | no | **FALLA** `hero attack hitbox radius changed` |
| test_tile_renderer | 152 | no | OK |
| test_vfx | 150 | sí | OK |

- **Los 3 fallos son tests desactualizados, no regresiones de gameplay** (los tests tienen valores viejos como literales). Causas: (a) `interval_at(1.0, 3)`: `d9c5971` ("Balance… solo en .tres") añadió `attack_speed_per_level = 0.05` y `min_attack_interval = 0.3` a `run_upgrade_config.tres` (diff verificado); (b) hitbox: el rango de ataque pasó a ser dato por héroe (`Player.gd:51,123`, 130-220 px; commit `eb6e3b8`); (c) `reward 12 science, expected 10`: la pasiva `SCIENCE_ON_DISCOVERY` de un héroe (`AbilityData.gd:11`, `FloorManager._apply_hero_passives`, `FloorManager.gd:75`) suma Ciencia al descubrir (commit `26eb413`). (b) y (c) están atribuidos por lectura de código, **no bisectados ni instrumentados**.
- **Hallazgo crítico — falsos verdes por arranque parcial.** En modo `--script` los identificadores de autoload no existen: `ThemeManager` falla al compilar, arrastra `PauseMenu`, y `Main2d.gd:45` (`@onready var pause_menu: PauseMenu = $PauseMenu`) aborta con `Trying to assign value of type 'CanvasLayer' to a variable of type 'PauseMenu.gd'`. Lo verifiqué con una sonda aparte: tras instanciar `Main2d.tscn`, `pause_menu`, `death_overlay`, `victory_overlay` y `retry_button` son `null` (y `death_handler` se crea con overlay nulo). **12 de los 20 tests** corren con ese Main2d a medias (el error aparece en 12 logs). `CLAUDE.md` lo presenta como "ruido esperado"; en realidad significa que pausa, muerte, victoria y botones **no están cubiertos** por ningún test y que los tests pasan en una configuración distinta a la del juego.
- **Cobertura por nombre:** 64 de 104 scripts runtime aparecen nombrados en algún test. **Sin test directo (40):** `SaveManager`, `SettingsManager`, `SteamManager`, `SteamLobbyManager`, `OptionsMenu`, `MainMenu`, `MainMenuFlow`, `SaveSlotSelector`, `WaitingRoom`, `NetworkModeSelect`, `PauseMenu` base (`BaseMenu`, `BaseSubPanel`, `ExitConfirmDialog`), `ResearchPanel`, `StatPanelUI`, `FloatingTextManager`, `ModuleBuildSystem`, `RoomPowerSystem`, `GeneratorModule`, `Main2d*Handler`, `HeroAbilities`/`AbilityData` (los cubre `test_abilities` por escena), `MoveAction/EnemyMoveAction/BaseAction`, `Hitbox/HurtboxComponent` (indirecto), `ThemeManager/QuestPalette`, `CameraConfig`. Los componentes de combate y movimiento sí se ejercitan indirectamente al arrancar `Main2d`.
- **Tipo:** son pruebas de integración (arrancan escenas reales) con pocos tests unitarios puros (`test_map_generator`, `test_balance`, `test_items`, `test_art_config`). Sin framework, sin runner único, sin CI: hay que lanzar cada archivo a mano y revisar el exit code.
- **Huecos funcionales importantes:** guardado/carga, opciones, flujo de red/Steam, extracción→victoria→siguiente piso con overlays reales, derrota/reintento, `Engine.time_scale` (fuga entre escenas), construcción de módulos de punta a punta con dinero.

---

## 11. Riesgos técnicos priorizados

### ALTO
1. **Red de seguridad poco fiable (tests).** 3/20 rojos en HEAD, 12/20 con `Main2d` incompleto, sin runner ni CI. Cualquier refactor grande (RoomManager/Main2d) pierde la garantía que debería dar. *Justificación:* verificado con ejecución real y sonda (§10).
2. **Estado de run sin dueño.** `Main._begin_new_run()` resetea 5 sistemas y 1 estático (`FloorManager._seen_types`, `FloorManager.gd:28`); un sistema nuevo con estado de run que no se añada allí **filtra estado entre partidas** (Retry/menú). *Justificación:* `Main.gd:131-145` es el único punto y es manual.
3. **`ManagerLocator` como nudo (38 scripts en un ciclo) + acoplamiento por grupos con strings.** Fallos silenciosos: la mayoría de los usos hacen `if x:` y siguen (`ModuleBuildSystem` solo emite un warning si falta el HUD). Un renombre de grupo rompe sin error de compilación. *Justificación:* §4.
4. **Cuatro fuentes de verdad para "qué héroes juego".** `GameSession.selected_hero_ids` (menú), `SaveManager.selected_character_id` (persistido; también usado por `WaitingRoom`), `SelectionManager.selected_ids` (en partida), `PlayerStats.active_hero_id` (vista) + `Main2d.active_character_id` y `PartyConfig` como fallback (`Main2d.gd:100,131`). Cualquier cambio de flujo (p. ej. reclutar, 3 héroes) toca todos. *Justificación:* grep de usos (§2, §7).
5. **God-scripts `Main2d` y `RoomManager`.** Alto fan-out/fan-in, 14 dependientes directos de `RoomManager`; el cambio de una parte exige entender las demás. *Justificación:* §8.

### MEDIO
6. **Dos pausas y `Engine.time_scale` global.** Parcheado en 3 lugares; cualquier escena nueva que cambie de escena sin pasar por `Main` lo hereda. `Timer`s y `Tween`s ya necesitan `set_ignore_time_scale()` (documentado en CLAUDE.md).
7. **Datos duplicados en dos capas** (`VARIANT_CONFIG` + `EnemyType` con centinela `-1`; `Module.CATALOG` en código frente a `AbilityData`/`ItemData` como Resource). Aumenta la superficie de errores de balance.
8. **Multijugador incompleto con expectativa de producto.** Lobby y auth existen (203+100 líneas), pero el juego no replica estado; sin tests; AppID 480. Riesgo de mantener código que no tiene consumidor real.
9. **Deriva de documentación.** `CLAUDE.md` (141 líneas, párrafos de 1500+ caracteres) cita `_deprecated/` (inexistente), `assets/nuevos`, y omite `MainMenuFlow`; `docs/ENTITY_VISUALS.md` afirma un recurso huérfano; 1146 líneas de `NOTES_SESSION.md`. Las IAs/personas que lo leen toman decisiones sobre código que ya no existe.
10. **i18n a medias** (25 claves vs. cientos de literales). Cambiar de idioma produce UI mixta.
11. **Guardado con campos muertos** (`run_cycle`, `post_victory_popup_pending`, `contracts_completed`, `clamp_player_hp(x,x)`) → falsa sensación de progresión persistente.

### BAJO
12. Estilo: 284 avisos de orden de definiciones, 735 de longitud de línea (no hay `gdlintrc`).
13. 51 funciones muertas, 8 constantes de paleta sin uso, `ThemeManager` casi vacío (§8).
14. Higiene de assets: 724 archivos de packs en el repo, ~304 imágenes curadas sin referencia literal, `addons/godotsteam` 138 MB.
15. `gdtoolkit` 4.5.0 frente a Godot 4.6.2: sin fallos hoy, pero podría quedarse atrás en sintaxis nueva.

---

## 12. Plan de refactor recomendado

Orden por dependencias. **Riesgo** = probabilidad de romper el juego. **Verificación** = con qué se comprueba. Convención: hacer cada paso en su propio commit; mover archivos **desde el editor de Godot** (actualiza `.uid` y referencias de `.tscn/.tres`) y reindexar con `godot --headless --editor --quit`.

### Fase 0 — Red de seguridad y limpieza sin riesgo

| # | Acción | Archivos | Riesgo | Depende de | Verificación |
|---|---|---|---|---|---|
| R1 | **Arreglar los 3 tests rojos** leyendo los valores de los `.tres` en vez de literales: `interval_at` ← `run_upgrade_config.tres`; reward de sala de tipo ← `RoomTypeRule` **más** el bonus de pasiva de los héroes de la partida (o fijar un `PartyConfig` sin pasiva de descubrimiento); radio ← `CharacterData.attack_range` del héroe | `tests/test_hud_ui.gd:59`, `tests/test_map_flow.gd`, `tests/test_sprites.gd:128` | Bajo | — | Los 20 tests en verde |
| R2 | **Runner único de tests** que lance todos los `tests/test_*.gd`, agregue exit codes e imprima resumen (`tools/run_tests.ps1` + `.sh`) | nuevo `tools/run_tests.*` | Bajo | R1 | Un solo comando, exit ≠ 0 si falla alguno |
| R3 | **Eliminar código muerto** de §8: 20 funciones de `ThemeManager` (dejar `build_panel_style`, `build_reward_card_style`, `build_slot_icon_style`), helpers de `GameStateManager`, `RoomManager` (7), `SaveManager` run-cycle, `ResourceManager.add_all`, `DoorTurnSystem.get_room_cells`, `Player.set_grid_position`, `Door.mark_opened`, `StatPanelUI.update_stats`, `FloatingTextManager.spawn_text_from_host`, `ItemCatalog.get_item`, `ArtConfig.art_px`, `Logger.{debug,set_*}`, 8 consts de `QuestPalette`, `ManagerLocator.{get_room_power_system,get_module_build_system}` | los archivos listados | Bajo | R2 (para ver que nada rompe) | Tests + `godot --headless --path . res://scenes/Main2d.tscn --quit-after 90` sin `SCRIPT ERROR` |
| R4 | **Eliminar huérfanos** (§9): `shared_player_idle_frames.tres`, `Sprites/`, `highlight_tileset.tres`, `highlight_placeholder.png`, `godot_debug_output.txt` (+ `.gitignore`), `assets/ui/background.png` y `256x256 textures (113).png` tras confirmar en el editor | ver §9 | Bajo | — | Boot headless + `test_assets_art` |
| R5 | **Eliminar señales sin oyente** o documentarlas como API: `door_opened`, `room_energized` (con R8), `pause_requested`/`resume_requested`/`death_entered`, `menu_opened`/`menu_closed` (con R9), `client_rejected` (decidir con multijugador). Mantener `ability_used`/`completed` solo si hay consumidor planeado | `DoorTurnSystem`, `RoomPowerSystem`, `GameStateManager`, `BaseMenu`, `BaseSubPanel`, `SteamManager` | Bajo | R3 | Tests |
| R6 | **Documentación:** mover `HANDOFF_*.md`, `REVIEW_SESSION_10.md` a `docs/archive/`; `NOTES_SESSION.md` a `docs/archive/`; corregir `CLAUDE.md` (quitar `_deprecated/` y `assets/nuevos`, añadir `MainMenuFlow`, resumir secciones por sesión) y `docs/ENTITY_VISUALS.md:7` | docs | Nulo | — | Revisión manual |

### Fase 1 — Unificar y quitar fuentes duplicadas

| # | Acción | Archivos | Riesgo | Depende de | Verificación |
|---|---|---|---|---|---|
| R7 | **`ThemeManager`: dejar de ser autoload.** Convertirlo en `class_name UiStyles` (solo estáticos); actualizar 24 usos y quitar la entrada de `project.godot`. Elimina la causa raíz de los `Identifier not found` en `--script` | `ThemeManager.gd`, `PauseMenu`, `BuildingMenu`, `HeroSelectMenu`, `MainMenu`, `CharacterCardOption`, `ExitConfirmDialog`, etc., `project.godot` | Bajo-medio | R3 | `Main2d.gd:45` deja de fallar en `--script` |
| R8 | **Reejecutar los 12 tests de Main2d ya con Main2d completo** y arreglar lo que aflore (pausa/overlays). Añadir 1 test de pausa+muerte+victoria que ejerza `pause_menu`/overlays reales | `tests/` | Medio (puede destapar bugs ocultos) | R7, R2 | Probe: `pause_menu`, `death_overlay` no nulos |
| R9 | **Borrar los pass-through** `RoomPowerSystem` (25 l.) y `ModuleBuildSystem` (31 l.): `Main2d`/`HUDController` se conectan directo a `RoomManager.slot_clicked`/`room_powered` (el log de energía va al sitio que paga el polvo). Quita 2 grupos y 2 getters | `RoomPowerSystem.gd/.uid`, `ModuleBuildSystem.gd/.uid`, `Main2d.gd`, `HUDController.gd`, `RoomManager.gd`, `ManagerLocator.gd` | Bajo | R3, R5 | `test_hud_ui` (BuildingMenu), `test_map_flow` |
| R10 | **Fusionar `BaseMenu` y `BaseSubPanel`** (95 % iguales): extraer el comportamiento común a un helper (`MenuBehavior`/composición) que ambos usen, o hacer que `BaseSubPanel` sea el único con `extends Control` y `PauseMenu` lo envuelva en un `CanvasLayer` | `BaseMenu.gd`, `BaseSubPanel.gd`, `PauseMenu.gd`, `ExitConfirmDialog.gd`, `OptionsMenu.gd` | Medio (UI visual) | R8 | Prueba manual de apertura/cierre de Pausa, Opciones, Confirmar salida |
| R11 | **Una sola fuente de verdad de la selección de héroes:** `GameSession` = pareja del menú; `SelectionManager` = selección en partida; `SaveManager.selected_character_id` solo para el último héroe guardado; quitar `Main2d.active_character_id` y dejar `PartyConfig` solo como valor por defecto | `GameSession`, `SelectionManager`, `PlayerStats` (quitar su getter de `active_hero_id` o invertir la dependencia), `SaveManager`, `Main2d`, `WaitingRoom`, `MainMenuFlow` | Medio | R8 | `test_hero_select`, `test_party`, `test_selection` |
| R12 | **Unificar Death/Victory** en dos escenas con script propio (`DeathOverlay.tscn`, `VictoryOverlay.tscn`) que expongan señales `retry/exit/next_floor`; Main2d deja de conocer 6 rutas internas y se borran `Main2dDeathHandler/VictoryHandler` | `Main2d.tscn/.gd`, 2 handlers, escenas nuevas | Bajo-medio | R8 | Test de R8 (muerte/victoria) |
| R13 | **Estado de run con dueño:** `RunState` (nodo hijo de `Main` o autoload) con `start_run()` que emite `run_started`; `ResourceManager`, `PlayerStats`, `SelectionManager`, `FloorManager._seen_types`, `GameSession` se suscriben y se resetean solos. `Main._begin_new_run()` solo llama `RunState.start_run()` | `Main.gd`, `ResourceManager`, `PlayerStats`, `SelectionManager`, `FloorManager`, nuevo script | Medio | R11 | `test_map_flow` (varias runs seguidas) + test nuevo "reset entre runs" |
| R14 | **Datos de código a Resources:** `ModuleData` (`resources/modules/*.tres`, sustituye `Module.CATALOG/TYPE_COLORS/DESCRIPTIONS/RESOURCE_LABELS`); `EconomyConfig` (rendimientos base, recursos iniciales); `EnemyType` absorbe `VARIANT_CONFIG` y se eliminan los centinelas `-1` | `Module.gd`, `BuildingMenu.gd`, `Module*.tscn`, `ResourceManager.gd`, `Enemy.gd`, `EnemyType.gd`, `resources/enemies/*.tres` (20), `BalanceSim.gd` | Medio | R1 | `test_balance`, `test_hud_ui`, `test_enemy_roles`; comparar `docs/BALANCE.md` antes/después |

### Fase 2 — Reorganización de carpetas y nombres (hacer en el editor)

| # | Acción | Archivos | Riesgo | Depende de | Verificación |
|---|---|---|---|---|---|
| R15 | **Partir `scripts/managers/`:** `scripts/autoload/` (`SaveManager`, `SettingsManager`, `ResourceManager`, `GameSession`, `SelectionManager`, `ManagerLocator`) y `scripts/run/` (`Main`, `Main2d`, `GameStateManager`, `FloorManager`, `EnemyManager`, `ExtractionManager`, `VfxManager`, `DoorTurnSystem`). `core/actions` queda con `BaseAction/MoveAction/EnemyMoveAction` | ~16 scripts + referencias en `project.godot`, `.tscn` | Medio-alto (rutas en `project.godot`, `preload` literales) | R3, R9, R12 | Boot headless + los 20 tests |
| R16 | **`core/floors` → separar enemigos:** `EnemyType/EnemyPool` a `scripts/core/enemies/`; `BuildingMenu.gd` a `scripts/ui/hud/`; `CharacterCardOption` a `scripts/ui/menus/`; `BalanceSim.gd` a `tools/` | listados | Bajo-medio | R15 | Tests |
| R17 | **`assets/` vs `resources/`:** `assets/characters/*.tres` → `resources/sprite_frames/`, `assets/tilesets/*.tres` → `resources/tilesets/`, `assets/vfx/*.tscn` → `scenes/vfx/` (actualizar `VfxManager.SCENE_PATH`); renombrar `enviorment`; ordenar `scenes/` en `menus/ hud/ world/ entities/ vfx/` | muchos `.tscn/.tres` | Medio-alto (referencias por ruta en 30+ resources) | R4, R15 | `test_assets_art`, `test_sprites`, `test_vfx`, boot |
| R18 | **Vocabulario y nombres:** `nexus`→`nexo` (`EnemyType.damage_vs_nexus` + 20 `.tres`, `BalanceSim.nexus_rows`, CSVs); documentar `zone` (celda lógica), `room` (zona de tipo sala), `group` (unidad de revelado) y usar `group_id` donde corresponda (`DoorTurnSystem`, `Door.target_room_id`) | `EnemyType.gd`, `resources/enemies/*.tres`, `DoorTurnSystem`, `Door`, `Main2d` | Medio (renombrar campo de Resource rompe `.tres` si no se migran) | R14 | `test_balance`, `test_enemy_roles` |

### Fase 3 — Partir los god-scripts (con la red de seguridad ya sólida)

| # | Acción | Archivos | Riesgo | Depende de | Verificación |
|---|---|---|---|---|---|
| R19 | **`Main2d` → raíz de composición delgada.** Extraer `HeroInputController` (clic sobre héroe, F1/F2, grupos, doble tap, `_unhandled_input`) y mover la lógica de cofres Loot a `FloorManager`/nuevo `LootSpawner`; que `PauseController` posea `Engine.time_scale` y su reseteo | `Main2d.gd` (538 → <250), nuevos scripts | Medio | R11, R12, R13 | `test_selection`, `test_party`, `test_map_flow` |
| R20 | **`RoomManager` (681) → `RoomGraph` + `RoomVisibility` + fachada.** `RoomGraph`: zonas, vecinos, `find_zone_path`, `validate_graph`; `RoomVisibility`: `apply_zone_visibility/on_group_revealed/refresh_*`; la fachada conserva la API pública para no tocar los 14 dependientes en el mismo commit | `RoomManager.gd` + 2 nuevos | **Alto** (14 dependientes, 30+ tests) | R2, R3, R8 | `test_rooms`, `test_corridor_picking`, `test_map_flow`, `test_tile_renderer`, `test_door_alignment` |
| R21 | **Acoplamiento por grupo `"hud"`:** `ManagerLocator.get_hud()` tipado + señales del HUD (`show_hint`, `set_pause_label`) en vez de `call_group`; eliminar los `get_first_node_in_group` sueltos | `FloorManager`, `Main2d`, `ResourceManager.gd:70`, `HUDController` | Bajo-medio | R9, R19 | `test_hud_ui` |
| R22 | **`HUDController` y UI en código:** sacar a scripts propios `HintPanel`, `NexoAlert`, `PauseLabel`, `TooltipPanel`; usar `%NombreUnico` en `HUD.tscn` en vez de rutas largas; separar `OptionsMenu` por pestaña (Video/Audio/Juego) | `HUDController.gd`, `HUD.tscn`, `OptionsMenu.gd` | Medio | R19 | `test_hud_ui` + prueba visual |
| R23 | **Tipado del locator:** cambiar el retorno `Node` de `get_selection_manager/get_game_session/get_settings_manager/get_steam_manager` por el identificador del autoload (como ya hacen `get_save_manager`/`get_resource_manager`/`get_player_stats`, que no tienen `class_name`) y `get_floating_text_manager` por `FloatingTextManager` (esa clase sí existe, `FloatingTextManager.gd:2`) | `ManagerLocator.gd` | Bajo | R7 | Parser + tests |

### Fase 4 — Producto (decidir antes de invertir)

| # | Acción | Riesgo | Depende de |
|---|---|---|---|
| R24 | **i18n:** o bien mover los literales de UI a `translations.csv` (HUD, build menu, popups, ítems, investigación, textos de `.tres`) o quitar el selector de idioma hasta que exista | Bajo (volumen alto) | R14 |
| R25 | **Guardado:** decidir qué se persiste (meta-progresión). Si no hay: quitar `run_cycle`, `post_victory_popup_pending`, `contracts_completed`, `clamp_player_hp(x,x)`; si hay: definir esquema versionado y test | Medio | R13 |
| R26 | **Multijugador:** decidir alcance. Mientras no haya replicación, mover Steam/Lobby a un módulo opcional (o detrás de feature flag) y sacar AppID 480 a config; añadir tests de la lógica de tickets con un mock | Medio | R15 |
| R27 | **Estilo:** añadir `gdlintrc`/`.gdformatrc` (límite de línea acordado) y aplicar `gdformat`+orden de definiciones solo en archivos tocados por R19-R22 | Bajo | R20 |

**Secuencia mínima recomendada para el siguiente paso:** R1 → R2 → R3 → R4 → R6 → R7 → R8. Con eso hay red de seguridad real y el repositorio queda limpio antes de mover nada. Luego R9, R11, R12, R13 (reducen Main2d), y recién después R15-R17 (mover carpetas) y R19-R20 (partir scripts).

---

## Apéndice — comandos reproducibles

```bash
# Inventario
git ls-files | grep -v '^assets/\|^addons/' | awk -F/ '{print $1"/"$2}' | sort | uniq -c | sort -rn
# Parser (todos los .gd)
python - <<'EOF'
import subprocess; from gdtoolkit.parser import parser
for f in subprocess.check_output(['git','ls-files','*.gd'],text=True).split():
    if not f.startswith('addons/'): parser.parse(open(f,encoding='utf-8').read(), gather_metadata=False)
EOF
# Lint
git ls-files '*.gd' | grep -v '^addons/' | xargs python -m gdtoolkit.linter | grep -o '([a-z-]*)' | sort | uniq -c | sort -rn
# Tests (uno a uno; reindexar antes)
G='E:\Descargas\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
"$G" --headless --path . --editor --quit
for t in tests/test_*.gd; do "$G" --headless --path . --script res://$t; echo "$t exit=$?"; done
# Señales declaradas / emitidas / conectadas
git grep -n '^signal ' -- 'scripts/*.gd';  git grep -n '\.emit(' -- 'scripts/*.gd';  git grep -n '\.connect(' -- 'scripts/*.gd'
# Uso del locator y de grupos
git grep -h -o 'ManagerLocator\.\w\+' -- 'scripts/*.gd' | sort | uniq -c | sort -rn
git grep -n 'get_first_node_in_group\|get_nodes_in_group\|call_group' -- 'scripts/*.gd'
# Hallazgo de Main2d parcial en --script (sonda): instanciar Main2d.tscn bajo root y imprimir pause_menu/death_overlay
# Estado de _deprecated
git log --oneline --diff-filter=D -- _deprecated
```

Los scripts Python de grafo de dependencias (Tarjan sobre `preload`/`class_name`), código muerto (funciones sin menciones fuera de su definición) y huérfanos (ruta/uid/`class_name` buscados en `.gd/.tscn/.tres/project.godot`) están descritos en §0; no se versionan por pedido de la sesión (solo este `.md`).

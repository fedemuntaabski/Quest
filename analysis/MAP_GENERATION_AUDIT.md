# Auditoría técnica: Generación de Mapa, Spawning de Enemigos e Integración del Personaje

**Fecha:** 2026-09-11
**Rama auditada:** `refactor/code-audit-cleanup`
**Alcance:** `scripts/world/dungeon/*`, `scripts/world/rooms/*`, `scripts/core/enemy/*`, `scripts/core/movement/*`, `scripts/world/camera/*`, `scripts/managers/ManagerLocator.gd`, `scripts/managers/Main2d.gd`, escenas `Player.tscn`, `Enemy.tscn`, `MapManager.tscn`.
**Metodología:** auditoría estática read-only (sin ejecución del motor); citas de archivo/línea verificadas contra el contenido real del repositorio en el momento de escribir este informe.

> Nota de contexto: `CLAUDE.md` referencia `docs/architecture/` y archivos como `CODE_CLEANUP_REPORT.md`/`MIGRATION_PLAN.md` que **no existen** en el repo actual. Este informe se guarda en `analysis/`, la carpeta real donde ya viven documentos hermanos (`Dungeon-Architecture-Overview.md`, `Grid-and-Occupancy-Ownership.md`, `Spawning-and-Pacing.md`).

---

## 1. Diagnóstico del Modelo Actual de Generación de Mundo

### 1.1 Algoritmo y flujo

El proyecto **no** usa BSP, cellular automata, marching squares ni ruido. El algoritmo real es **salas rectangulares + pasillos, forzados a una cadena lineal estricta** (Room 0 → Room 1 → … → Room 7). No hay ramificaciones, loops ni grafos no lineales — el propio validador del grafo (`DungeonGraph.validate()`) rechaza cualquier topología que no sea la cadena `[id-1, id+1]`.

**Pipeline paso a paso** (todo síncrono, mismo frame):

```
MapManager._ready()                                          scripts/world/rooms/MapManager.gd:30
 ├─ _ensure_helpers()                                          línea 37
 ├─ _setup_turn_manager()                                      línea 40
 ├─ dungeon_generator.generate_dungeon(player)                 línea 43  ← bloqueante, sin await
 │    └─ DungeonGenerator.generate_dungeon()                   scripts/world/dungeon/DungeonGenerator.gd:227
 │         ├─ randomize()                                       línea 228
 │         ├─ _clear_generated_content()                        línea 229
 │         ├─ layout_generator.generate()                       línea 250
 │         │    └─ DungeonLayoutGenerator.generate()            scripts/world/dungeon/DungeonLayoutGenerator.gd:32-89
 │         │         ├─ hasta 32 reintentos (LAYOUT_RETRIES, línea 33)
 │         │         ├─ dungeon.room_count = 8  # forzado         línea 34
 │         │         ├─ coloca 8 salas, ordena izq→der            líneas 38-79
 │         │         ├─ _register_room() por sala                 líneas 146-177
 │         │         ├─ _connect_rooms_with_corridors()            líneas 180-200
 │         │         │    └─ _carve_corridor() (camino en L)        líneas 203-258
 │         │         └─ _validate_graph() (DungeonGraph.validate)   líneas 312-320
 │         ├─ _apply_layout_data(layout_data)                    línea 255 (278-284)
 │         ├─ wall_manager.generate_walls_from_floor()            línea 257
 │         ├─ presentation.build(floor_tileset, wall_texture)     líneas 259-266
 │         ├─ place_player_in_start_room(player)                  líneas 268-272
 │         └─ _set_active_room(0)                                 líneas 274-275
 ├─ [si floor_cells vacío → push_warning + return, SIN reintento]  MapManager.gd:45-47
 ├─ _setup_enemy_manager()                                       línea 49
 └─ navigation_helper.bake_navigation_region()                    línea 50
```

Detalle del algoritmo de layout (`DungeonLayoutGenerator.gd`):
- `_roll_room_size()` (114-132): sesgo 34%/34%/32% entre sala alargada horizontal / vertical / cuadrada.
- Colocación por intentos aleatorios (`attempts = room_count * 90`, línea 38) con chequeo de solapamiento inline (`grow(room_padding)`, líneas 58-67).
- `_get_connection_point()` (339-355): elige **un solo borde** de salida por sala según posición relativa entre salas consecutivas.
- `_carve_corridor()` (203-258): camino en "L" (orden horizontal/vertical al azar, línea 217), ensanchado a 2 celdas de ancho vía `_add_corridor_cell_double()` (261-274) — el offset extra siempre es `(+1, 0)`, es decir el ensanche real solo ocurre en el eje X, nunca correctamente en ambos ejes para pasillos verticales.
- `_get_room_template()` (302-309): sala 0 = `TEMPLATE_TUTORIAL`, última = `TEMPLATE_BOSS`, resto = `TEMPLATE_NORMAL`.

**Código muerto confirmado dentro del algoritmo:**
- `_room_overlaps_existing()` (`DungeonLayoutGenerator.gd:135-143`) — nunca invocado; el chequeo real está duplicado inline en `generate()` (60-64).
- `_fill_corner()` (`DungeonLayoutGenerator.gd:322-337`) — nunca invocado.
- `main_path_branching` (`DungeonGenerator.gd:27`, `@export`) — nunca leído; solo se escribe `false` fijo en metadata (`DungeonLayoutGenerator.gd:107`).

### 1.2 Uso de TileMaps (Godot 4)

**Capas activas en el pipeline real: 3 `TileMapLayer`**, todas puramente visuales/de presentación, ninguna de colisión:

| Capa | Archivo | Propósito |
|---|---|---|
| `FloorLayer` | `DungeonTileRenderer.gd:30-34` | Piso, autotiling manual |
| `FogOfWar` | `FogOfWarManager.gd:4,27-28` | Niebla no visitada (alpha 0.9) |
| `VisitedFog` | `FogOfWarManager.gd:5,47-48` | Niebla semi-visitada (alpha 0.45) |

- **No hay terrain sets**: el `.tres` del tileset (`assets/texture/enviorment/dungeon_tileset.tres`) solo define un `TileSetAtlasSource` con celdas individuales — sin bloque `terrain_sets`. No hay ninguna llamada a `set_cells_terrain_connect`/`set_cells_terrain_path` en todo el repo.
- **Autotiling manual**: `DungeonTileRenderer._paint_cell()` (53-82) compara vecinos contra `wall_cells` (UP/DOWN/LEFT/RIGHT + esquinas) para elegir entre 9 coordenadas de atlas fijas (`TILE_MAIN_FLOOR`, `TILE_EDGE_*`); pinta con `floor_layer.set_cell(cell, 0, atlas_coords)` (línea 82), celda a celda.
- **Paredes NO son TileMap**: `DungeonWallManager.generate_walls_from_floor()` (33-67) crea un `StaticBody2D` completo (`Sprite2D` + `CollisionShape2D` + `LightOccluder2D`) por cada celda de pared candidata (líneas 135-192) — potencialmente cientos de nodos individuales, en vez de usar physics layers agregadas del TileSet.
- **Physics Layers / Navigation Layers**: `project.godot` **no tiene sección `[layer_names]`** — ninguna capa física ni de navegación está nombrada. Todo el código referencia capas por número mágico:
  - Muros: `collision_layer=1`, `collision_mask=1` (`DungeonWallManager.gd:147-148`)
  - RoomArea (trigger de sala): `collision_layer=0`, `collision_mask=1` (`DungeonRoomFactory.gd:60-61`)
  - Enemigo normal: `collision_layer=4` (`Enemy.tscn:25`, duplicado también implícitamente en código)
  - Enemigo tutorial: `collision_layer=4`, `collision_mask=0` (`Enemy.gd:386-387`)
- `NavigationRegion2D` declarado en `scenes/MapManager.tscn:12`, sin `navigation_layers` explícito (usa default `1`). El `TileSet` no contiene `physics_layer_*` ni `navigation_layer_*` — es puramente visual.
- **Escena huérfana detectada**: `scenes/tilemapquest.tscn` contiene un `TileMapLayer` propio con `TileSetAtlasSource` basado en `mainlevbuild.png` — **ninguna escena ni script del proyecto lo referencia**. Candidato a limpieza.

### 1.3 Rendimiento y sincronismo

- **100% síncrono en el hilo principal.** No hay `await`, `Thread.new()` ni `WorkerThreadPool` en ningún script de `scripts/world/dungeon/*`. Todo el pipeline (layout + paredes + tilemap + navmesh + spawn de enemigos) corre en el mismo frame de `MapManager._ready()`.
- Los únicos usos de `call_deferred` en el árbol son **polling de referencias** (esperar a que exista el jugador/cámara en un grupo), no diferimiento de trabajo pesado: `room_camera_controller.gd:52,64,69,74`, `TileHighlighter.gd:84`.
- **Riesgo de hitch real**: con `grid_width=90`, `grid_height=70` (hasta 6300 celdas) y 8 salas, `DungeonWallManager.generate_walls_from_floor()` puede instanciar cientos de `StaticBody2D` completos en un único frame, sin generación incremental ni segundo hilo. Sin mitigación alguna hoy.
- **Seeds**: `randomize()` se llama una única vez (`DungeonGenerator.gd:228`), sin `seed()` ni instancia propia de `RandomNumberGenerator` en todo el repo. **No hay forma de fijar ni loggear el seed usado** — imposible reproducir un layout específico para reportar/depurar un bug.
- **Regeneración**: no existe ninguna función `generate_new_floor`/`next_floor`/`regenerate` en el repo. El único punto de invocación de `generate_dungeon()` es `MapManager._ready()`. La única forma de obtener un mapa nuevo es recargar la escena completa (`Main2d._reload_current_scene()` → `Main2d.gd:449-450` → `get_tree().reload_current_scene()`). El juego **no tiene concepto de "piso siguiente"** dentro de la misma sesión de mapa.
- **Sin fallback ante fallo de layout**: si `layout_generator.generate()` agota los 32 reintentos y devuelve `null` (`DungeonLayoutGenerator.gd:89`), `DungeonGenerator.generate_dungeon()` hace `push_error` y retorna sin generar nada (`DungeonGenerator.gd:251-253`); `MapManager._ready()` detecta `floor_cells.is_empty()` y solo hace `push_warning` + `return` (líneas 45-47) — **sin reintentar**. El mapa queda vacío, sin recuperación.

---

## 2. Integración y Spawning de Enemigos

### 2.1 Momento de spawning

**No hay señal `map_generated`/`generation_finished`.** El spawn ocurre síncronamente, en el mismo call-stack de `MapManager._ready()`, después de que la generación del mapa ya terminó por completo:

```
MapManager._ready():49  →  _setup_enemy_manager()
  → MapTurnSetup.setup_enemy_manager()          scripts/world/rooms/MapTurnSetup.gd:15-46
       ├─ crea EnemyManager, add_child            líneas 22-24
       ├─ enemy_manager.setup(dungeon, player, tm) línea 28
       ├─ enemy_manager.spawn_enemies(room_infos, wall_cells)  línea 37
       │    └─ EnemyManager.spawn_enemies()      scripts/core/enemy/EnemyManager.gd:56
       │         └─ EnemySpawnLifecycleService.spawn_enemies()  scripts/core/enemy/EnemySpawnLifecycleService.gd
       │              └─ _spawn_enemy_for_room()  líneas 25-75
       │                   ├─ enemy_scene.instantiate()   línea 52
       │                   └─ manager.add_child(enemy)    línea 67
       └─ turn_manager.start()                    línea 46
```

**Orden llamativo**: `_setup_enemy_manager()` (línea 49) se ejecuta **antes** que `navigation_helper.bake_navigation_region()` (línea 50). Ver 2.2.

### 2.2 Navegación (Pathfinding 2D)

**`NavigationAgent2D` no se usa en ningún script del proyecto** (0 resultados). El bake de `NavigationRegion2D` **existe pero es código vestigial**:

- `MapManager.gd:14` declara `nav_region: NavigationRegion2D`, pasado a `MapNavigationHelper.setup()` (línea 66).
- `MapNavigationHelper.bake_navigation_region()` (`scripts/core/movement/map_navigation_helper.gd:18-63`) construye un `NavigationPolygon` a mano desde `floor_cells` y lo asigna a `nav_region.navigation_polygon`.
- **Este polígono nunca se consulta después**: no hay `NavigationServer2D.map_get_path`, `nav_region.get_navigation_polygon()` usado en pathfinding, ni ningún `NavigationAgent2D` conectado. Confirmado por búsqueda global.
- **Race condition latente (no activa hoy)**: `_setup_enemy_manager()` (spawnea/registra enemigos, línea 49) corre **antes** que `bake_navigation_region()` (línea 50). Hoy es inocuo porque nada consume el navmesh; pero si en el futuro se conecta un `NavigationAgent2D` a los enemigos asumiendo navmesh listo al spawnear, este orden de líneas produciría rutas rotas o nulas.

**Pathfinding real: A\* manual sobre grid**, no `AStarGrid2D`/`AStar2D` ni `NavigationServer2D`:
- `MapNavigationHelper.find_path()` (`map_navigation_helper.gd:116-156`): A* implementado a mano (open_set, g_score, f_score propios), vecinos ortogonales filtrados por `is_cell_walkable` + `OccupancyManager.is_cell_blocked` (línea 182).
- `find_path_preferred()` (línea 202) tiene un comentario indicando que se dejó preparado para "switch to NavigationRegion" pero nunca se implementó (líneas 210-214) — siempre cae al A* manual.
- `MapManagerCore.find_path()`/`find_path_to_adjacent()` (`scripts/world/rooms/MapManagerCore.gd:125-167`) acotan la búsqueda al `Rect2i` de la sala activa del actor.
- `EnemyTurnPolicy.decide()` (`scripts/core/enemy/EnemyTurnPolicy.gd:50-55`) llama `find_path_to_adjacent()` y usa `path[1]` como siguiente celda; el movimiento se ejecuta vía `MoveAction` encolado (`Enemy.gd:273-283`) y consumido por `TurnManager`/`ActionQueue`.

No se detectan errores de cálculo de rutas per se — el sistema de A* manual funciona sobre el grid consistentemente — pero el navmesh horneado es trabajo desperdiciado (CPU/memoria) que no cumple ninguna función.

### 2.3 Validación de posición

`EnemySpawnPlanner.get_random_floor_cell_in_room()` (`scripts/core/enemy/EnemySpawnPlanner.gd:4-53`) filtra candidatos así:

1. Descarta muros (`wall_cells.has(cell)`, línea 24).
2. Descarta celdas de entrada de sala y vecinas (`forbidden_spawn_cells`, línea 26, vía `DungeonGenerator.get_room_spawn_forbidden_cells()`).
3. Descarta la celda exacta del jugador (línea 28).
4. Descarta celdas ya usadas por otro enemigo en esta misma pasada (línea 30).
5. Si `avoid_center` (solo sala tutorial): descarta radio 1 del `center_cell` (líneas 33-37) — coincide con el punto de spawn del jugador.
6. `near_wall`: descarta además celdas adyacentes a un muro (buffer 1 celda, líneas 39-46).
7. Si no queda ningún candidato → **retorna `Vector2i(-1,-1)` y el enemigo simplemente no se spawnea**, de forma silenciosa (`EnemySpawnLifecycleService.gd:43-44`, sin `push_warning` ni log).

**Riesgos concretos:**

- **Dentro de muro**: riesgo bajo/mitigado — chequeos 1 y 6 cubren esto razonablemente.
- **Fuera de límites del mapa**: riesgo bajo hoy (candidatos vienen de `room_info["floor_cells"]`, ya validado transitivamente por el generador), pero **no hay guard explícito `is_within_bounds`** en el planner — si en el futuro `room_infos` se alimenta desde otra fuente (edición manual, mods), esto se vuelve explotable.
- **Encimado con el jugador — riesgo real más allá de la sala inicial**: la exclusión (paso 3) usa `player_cell` calculado **una sola vez, fuera del bucle de salas** (`EnemySpawnLifecycleService.gd:18-20`). Solo excluye la celda exacta, no un radio — si en el futuro se reinvoca `spawn_enemies()` en runtime (oleadas, respawns) con el jugador ya en una sala intermedia, un enemigo podría spawnear pegado al jugador (ataque garantizado en turno 1).
- **Bug de diseño confirmado — `OccupancyManager` nunca se consulta en el spawn**: la única fuente de verdad real de ocupación (`OccupancyManager.is_cell_blocked()`, `scripts/world/rooms/OccupancyManager.gd:89-112`) **no se usa** en `EnemySpawnPlanner.gd` ni en `EnemySpawnLifecycleService.gd`. El chequeo de "celda libre" es ad-hoc y local (`occupied_spawn_cells` + comparación directa con `player_cell`). Si se agregan actores estáticos que se registran en `OccupancyManager` antes del spawn (trampas, NPCs, objetos bloqueantes), el spawner no los verá.
- **Fallo silencioso sin recuperación**: si una sala pequeña combinada con `avoid_center`/`near_wall` agota el pool de candidatos, la sala queda sin enemigo asignado y sin log. Si alguna mecánica de progreso depende de `room_cleared` (que solo se dispara al derrotar un enemigo — `EnemyRewardService.process_enemy_defeat()` sale temprano si `_room_enemy_counts` no tiene la sala), esa sala podría quedar **permanentemente bloqueada** si `room_cleared` es prerequisito de apertura de puertas u otra progresión.

---

## 3. Interacción del Personaje con el Mapa Generado

### 3.1 Punto de aparición

Decidido enteramente por `DungeonGenerator`, no por el propio Player:

```gdscript
// DungeonGenerator.gd:287-295 (place_player_in_start_room)
var start_room := room_infos[0]
var center_cell: Vector2i = start_room["center_cell"]
player.position = grid_to_world_coords(center_cell)
if player.has_method("sync_to_grid"):
    player.sync_to_grid()
```

Invocado desde `generate_dungeon()` (`DungeonGenerator.gd:268-272`) tras generar layout, paredes y presentación. No hay nodo `spawn_point` explícito ni export — el spawn nace de `room_infos[0]["center_cell"]` (primera sala de la cadena lineal, siempre `TEMPLATE_TUTORIAL`).

### 3.2 Física y colisiones

Matriz consolidada:

| Nodo | collision_layer | collision_mask | Fuente |
|---|---|---|---|
| Player | 1 (default) | 1 (default) | `scenes/Player.tscn` (sin overrides) |
| Muro (`StaticBody2D`) | 1 | 1 | `DungeonWallManager.gd:147-148` |
| Enemigo normal | 4 | 1 (default, no sobrescrito) | `scenes/Enemy.tscn:25` |
| Enemigo tutorial | 4 | 0 | `Enemy.gd:386-387` |
| RoomArea (`Area2D`) | 0 | 1 | `DungeonRoomFactory.gd:60-61` |

**Inconsistencia detectada**: enemigos normales heredan `mask=1` (default) mientras que enemigos de tutorial lo ponen explícitamente a `0` — parche aplicado a un solo caso, no replicado al camino normal. **Hoy es inofensivo**: ni `Enemy.gd` ni `PlayerMovement.gd` usan `move_and_slide()`/`move_and_collide()` (movimiento por interpolación directa de `global_position`, `Enemy.gd:249-264`, `PlayerMovement.gd:218-226`); el bloqueo de paredes es puramente lógico vía `MapManagerCore.is_walkable_cell`. Pero es una divergencia latente si se introduce física real (knockback, empuje).

RoomArea con `mask=1` detecta al Player (correcto para `room_changed`), pero jugador y muros comparten el mismo layer 1 sin distinción semántica "world" vs "player".

No existen proyectiles físicos: "Descarga Arcana" y cartas similares se resuelven lógicamente vía `CombatCardSystem.gd` (grid/turno), no como `Area2D`/`RigidBody2D`.

### 3.3 Límites de cámara y mundo

Los límites (`limit_left/right/top/bottom`) **sí se calculan dinámicamente**, derivados de `room_rect * tile_size`, no hardcodeados:

```gdscript
// CameraMode_Room.gd:72-79
var margin_px: float = base_margin_tiles * dg.tile_size
var room_world_pos: Vector2 = dg.grid_to_world_coords(room_rect.position)
var room_world_end: Vector2 = dg.grid_to_world_coords(room_rect.end)
camera.limit_left = int(room_world_pos.x - margin_px)
...
```

Mismo patrón en `CameraMode_Corridor.gd:52-60` y `room_camera_controller.gd:139-148`.

**Problema de mantenibilidad, no de correctness**: hay **tres implementaciones casi duplicadas** del mismo cálculo (`CameraMode_Room.gd`, `CameraMode_Corridor.gd`, `room_camera_controller._update_camera_for_room`). En `room_camera_controller.gd:137`, el zoom está hardcodeado a `Vector2(3.3, 3.3)` con el cálculo dinámico real **comentado** (líneas 133-135) — sugiere dos sistemas de cámara compitiendo, no consolidados en una sola fuente de verdad.

---

## 4. Acoplamiento, Mantenibilidad y Bugs Críticos

### 4.1 Dependencias directas vs. señales

**Sí se usan señales** para eventos de alto nivel:
- `room_changed` (`DungeonGenerator`/`room_system`) → `Main2d._connect_dungeon()`, `room_camera_controller.gd:42-43`, `DungeonPresentationManager.gd:22-23`.
- `room_cleared`, `enemy_defeated_global`, `boss_defeated` → `Main2d.gd:116-123`.
- `player_died` (`PlayerStats`) → `Main2d._connect_player()`.
- `state_changed` (`GameStateManager`) → `TurnManager._bind_game_state()`, `PlayerMovement._connect_game_state()`.

**Pero la relación estructural Player↔MapManager↔DungeonGenerator es 100% referencia directa:**
- `MapManager.gd:42`: `get_node_or_null("Player") as CharacterBody2D`.
- `MapTurnSetup.gd:26`: `map_manager.get_node_or_null("Player")`.
- `Main2d.gd:189,191`: `get_node_or_null("Player")`, luego `.get_node_or_null("PlayerActionController")`.
- `room_camera_controller.gd:62,102,180,219`: `dungeon.get_spawned_player()` (getter sobre `DungeonGenerator._spawned_player`, guardado en `DungeonGenerator.gd:269`).
- `MapManagerCore.gd:69,268`: chequeo directo `actor is PlayerMovement`.
- `EnemyManager.gd:53`: `player.get_node_or_null("PointLight2D")` — acceso directo a nodo interno de la escena del Player desde fuera.

Conclusión: eventos de alto nivel (cambio de sala, muerte, estado) sí desacoplados; la inicialización posicional/estructural del jugador, no.

### 4.2 Condiciones de carrera (confirmadas)

**Race condition real (mitigada, no eliminada)**: `PlayerMovement` es hijo directo de `MapManager` en la escena (`get_parent() as MapManager`, `PlayerMovement.gd:60`). En Godot, `_ready()` se propaga hijos→padres, por lo que `PlayerMovement._ready()` (`PlayerMovement.gd:57-95`) corre **antes** que `MapManager._ready()` (`MapManager.gd:30-50`).

En ese momento, `MapManager.core`/`occupancy_manager`/`navigation_helper` son aún `null` (se crean en `_ensure_helpers()`, invocado dentro de `MapManager._ready()`, todavía no ejecutado). Pero `PlayerMovement.gd:65-67` ya llama:

```gdscript
sync_to_grid()
if map_manager:
    map_manager.register_actor(self, grid_pos, true)
```

- `sync_to_grid()` → `map_manager.world_to_grid_coords()` (`MapManager.gd:209-210`, patrón `core... if core else ...`) devuelve `Vector2i.ZERO` silenciosamente porque `core` es `null`.
- `register_actor()` (`MapManager.gd:265-269`) es un no-op silencioso con ambos helpers en `null`.

**Se autocorrige** porque `DungeonGenerator.place_player_in_start_room()` (llamado dentro de `generate_dungeon()`, después de que `_ensure_helpers()` ya construyó `core`/`navigation_helper`) vuelve a llamar `player.sync_to_grid()` (`DungeonGenerator.gd:294-295`). **No existe señal `map_generated`/`generation_complete`** que documente o fuerce este contrato — la corrección funciona solo por el orden implícito de llamadas dentro de `MapManager._ready()`. Un refactor que reordene estas líneas, o que cambie a `PlayerMovement` para no ser hijo directo de `MapManager`, dejaría al jugador registrado permanentemente en `grid_pos=(0,0)` en `OccupancyManager` — bug de colisión/ocupación silencioso y difícil de detectar.

`TurnManager` es más seguro: no arranca turnos en `_ready()`, sino que espera `start()` explícito desde `MapTurnSetup.setup_enemy_manager()` (línea 46), llamado después de que dungeon y player ya están posicionados — sin carrera en este punto.

### 4.3 Lista consolidada de bugs y code smells

| # | Ubicación | Hallazgo |
|---|---|---|
| 1 | `DungeonLayoutGenerator.gd:34` | `dungeon.room_count = 8` fuerza el valor, ignorando el `@export room_count` (`DungeonGenerator.gd:16`) configurable desde el inspector — export decorativo/engañoso. |
| 2 | `DungeonLayoutGenerator.gd:135-143, 322-337` | `_room_overlaps_existing()` y `_fill_corner()` son código muerto, nunca invocado. |
| 3 | `DungeonGenerator.gd:27` | `main_path_branching` exportado pero nunca leído. |
| 4 | `DungeonGenerator.gd:21-22`, `DungeonRoomFactory.gd:51` | `room_light_energy`/`room_light_transition_seconds` ignorados; luces de sala se crean con `energy=0.0` hardcodeado y nunca se encienden. |
| 5 | `DungeonLayoutGenerator.gd:250-251` | Validación de longitud de corredor solo emite `push_warning`, no corrige ni rechaza — el límite es informativo, no funcional. |
| 6 | `DungeonGenerator.gd:251-253`, `MapManager.gd:45-47` | Fallo de layout tras 32 reintentos deja el mapa vacío sin reintento ni fallback. |
| 7 | `OccupancyManager.gd:144-146` | Colisión de ocupación de celda resuelta reemplazando silenciosamente al actor anterior. |
| 8 | Físicas/navegación globales | Ausencia de `[layer_names]` en `project.godot`; capas por número mágico repartidas en 5+ archivos, con duplicación código/escena (`Enemy.gd:386` vs `Enemy.tscn:25`). |
| 9 | `scenes/tilemapquest.tscn` | Escena huérfana, sin referencias desde código — candidata a limpieza. |
| 10 | Manejo de seed | `randomize()` no determinista, sin `RandomNumberGenerator` propio ni registro del seed — imposible reproducir mapas para debug/QA. |
| 11 | `MapManager.gd` (~20 wrappers, líneas 204-303) | Patrón repetido `core.metodo(...) if core else fallback` — duplicación de lógica de fallback. |
| 12 | `DungeonWallManager.gd:33-67` | Un `StaticBody2D` completo por celda de pared (potencialmente cientos de nodos) en vez de physics layers del TileSet — impacto en tiempo de carga y memoria de nodos. |
| 13 | `EnemyData.ai_type` (`EnemyData.gd:21`) | Exportado pero nunca leído — `EnemyTurnPolicy.decide()` implementa una única política fija; todos los enemigos se comportan igual sin importar el valor configurado. |
| 14 | `EnemySpawnPlanner.gd` | No consulta `OccupancyManager.is_cell_blocked()` ni valida bounds explícitamente — ver sección 2.3. |
| 15 | `EnemySpawnLifecycleService.gd:43-44` | Fallo silencioso si no hay celda de spawn candidata — sala puede quedar sin enemigo, sin log, con riesgo de bloquear progreso dependiente de `room_cleared`. |
| 16 | `MapManager.gd:49-50` | `_setup_enemy_manager()` antes de `bake_navigation_region()` — orden inocuo hoy, trampa si se reactiva `NavigationAgent2D`. |
| 17 | `room_camera_controller.gd:133-137` | Cálculo de zoom dinámico comentado y reemplazado por `Vector2(3.3, 3.3)` fijo; triplicación de lógica de cámara entre `CameraMode_Room`, `CameraMode_Corridor` y este controlador. |
| 18 | `ManagerLocator.get_game_state_manager()` | Subutilizado: `TurnManager.gd:33`, `PlayerMovement.gd:103`, `PlayerActionController.gd:25`, `PlayerMovementTurnBridge.gd:27`, `MapManagerCore.gd:31` repiten `get_tree().get_first_node_in_group("game_state_manager")` en vez de pasar por el locator; `Main2d.gd` mantiene además una tercera vía (instancia cacheada propia) — tres caminos distintos al mismo objeto. |
| 19 | Enemigo normal vs. tutorial | `collision_mask` inconsistente (1 vs 0) — ver sección 3.2. |

No se encontraron marcadores `TODO`/`FIXME`/`HACK` en `scripts/world/dungeon` ni `scripts/world/rooms`.

---

## 5. Propuesta de Rediseño y Modularización

### 5.1 Arquitectura propuesta

La separación de responsabilidades **ya existe parcialmente** y es un buen punto de partida — no requiere reescritura desde cero:

- **Capa de algoritmo puro** (ya aislada, mantener en GDScript — no hay razón para C# en un proyecto GL Compatibility/GDScript-only): `DungeonLayoutGenerator` + `DungeonGraph` + `DungeonLayoutData`, todos `RefCounted`, sin dependencia de nodos de escena. Correcto tal como está.
- **Capa de renderizado** (`DungeonTileRenderer`, `DungeonWallManager`, `DungeonPresentationManager`, `FogOfWarManager`): consumir `DungeonLayoutData` sin acoplarse al generador de layout. Ya razonablemente separado; el problema no es la capa sino el **acoplamiento de orquestación** (`DungeonGenerator.generate_dungeon()` conoce y llama a las tres capas directamente en secuencia rígida).
- **Capa de spawning de entidades** (`EnemyManager`/`EnemySpawnLifecycleService`/`EnemySpawnPlanner`): correcta en estructura (composición + servicios estáticos), pero necesita una **dependencia explícita a `OccupancyManager`** en vez de reimplementar su propio chequeo de ocupación local.

**Cambio concreto recomendado — introducir señal `map_generated(layout_data: DungeonLayoutData)`:**

Reemplazar el orden implícito actual (`generate_dungeon()` → `_setup_enemy_manager()` → `bake_navigation_region()`, todo por llamada directa secuencial en `MapManager._ready()`) por:

```gdscript
# DungeonGenerator.gd
signal map_generated(layout_data: DungeonLayoutData)
# emitir al final de generate_dungeon(), después de place_player_in_start_room()
```

```gdscript
# MapManager.gd
dungeon_generator.map_generated.connect(_on_map_generated)
dungeon_generator.generate_dungeon(player)

func _on_map_generated(layout_data):
    navigation_helper.bake_navigation_region()   # ahora antes del spawn
    _setup_enemy_manager()
```

Esto (a) corrige el orden bake-navmesh-antes-de-spawn (hallazgo #16), (b) documenta explícitamente el contrato "mapa listo" en vez de depender de la posición de líneas dentro de `_ready()`, y (c) es la base para eliminar la race condition de `PlayerMovement` (hallazgo 4.2): `PlayerMovement` podría esperar esta señal en vez de intentar `sync_to_grid()`/`register_actor()` en su propio `_ready()`.

**Reemplazar referencias directas por desacoplamiento real:**
- `MapManager.get_node_or_null("Player")`, `DungeonGenerator._spawned_player`/`get_spawned_player()` → registrar al Player vía `ManagerLocator` (extendiendo el patrón ya usado para `PlayerStats`/`GameStateManager`) o vía grupo consistente (`is_in_group("player")` ya existe en algunos puntos, formalizarlo en todos).
- Unificar los 3 caminos de acceso a `GameStateManager` (hallazgo #18) forzando el uso de `ManagerLocator.get_game_state_manager()` en `TurnManager`, `PlayerMovement`, `PlayerActionController`, `PlayerMovementTurnBridge`, `MapManagerCore`, y eliminar la instancia cacheada duplicada en `Main2d`.
- Consolidar cámara: elegir **una** fuente de verdad entre `CameraMode_Room`/`CameraMode_Corridor` y `room_camera_controller` (hallazgo #17); el cálculo de límites ya es correcto en ambos, solo hay que eliminar la duplicación y decidir si el zoom fijo (`3.3,3.3`) fue una decisión de diseño intencional o un olvido del cálculo comentado.

### 5.2 Custom Resources / Data-Driven

- **Seed reproducible**: agregar `@export var map_seed: int = -1` a `DungeonGenerator`; si `-1`, usar `randi()` y loggear el valor elegido (vía `Logger.info(Category.MAP, ...)`); si se fija un valor, usar `RandomNumberGenerator` propio con `.seed = map_seed` en vez de `randomize()` global — esto habilita reproducir bugs de layout reportados por QA.
- **`ai_type` real**: o bien implementar las ramas correspondientes en `EnemyTurnPolicy.decide()` (p. ej. `"ranged"`, `"stationary"`, distinto de `"melee_chase"`), o eliminar el campo de `EnemyData.gd` si no hay plan de usarlo — mantenerlo sin uso es confuso para cualquiera que edite un `.tres` de enemigo esperando que tenga efecto.
- **Densidad/dificultad por sala**: `DungeonGraph`/room templates (`TEMPLATE_TUTORIAL`/`TEMPLATE_NORMAL`/`TEMPLATE_BOSS`) ya existen como constantes — se podrían formalizar como un `Resource` (`RoomTemplateConfig.tres`) con campos `min_enemies`, `max_enemies`, `enemy_pool: Array[EnemyData]`, en vez de la lógica actual repartida entre `EnemyDataSelector.gd` (selección de `EnemyData` por plantilla) y constantes hardcodeadas en `DungeonGraph`.
- **Tamaños de sala/bioma**: los `@export` de `DungeonGenerator` (`room_min/max_size`, `room_padding`, `corridor_min/max_length`, `grid_width/height`) ya son parametrizables desde el inspector — el paso natural es envolverlos en un `Resource` (`DungeonGenerationConfig.tres`) para poder tener múltiples perfiles (piso fácil/difícil, bioma A/B) intercambiables sin tocar la escena, y para que `room_count=8` (hoy forzado en código, hallazgo #1) vuelva a ser configurable de verdad si se desea variar el largo de la run.
- **Validación de spawn robusta**: pasar `OccupancyManager` como parámetro explícito a `EnemySpawnPlanner.get_random_floor_cell_in_room()` y agregar `if occupancy_manager.is_cell_blocked(cell): continue` dentro del bucle de candidatos (línea 21-48) — cierra el hallazgo #14 sin rediseño estructural, solo una dependencia explícita donde hoy falta.

### 5.3 Priorización sugerida (impacto/esfuerzo)

1. **Alto impacto, bajo esfuerzo**: conectar `EnemySpawnPlanner` a `OccupancyManager` (#14), loggear seed (#10), `push_warning` en spawn fallido (#15), eliminar código muerto (#2, #3, #4).
2. **Medio impacto, medio esfuerzo**: señal `map_generated` para ordenar bake-navmesh/spawn/player-sync (#4.2, #16), consolidar acceso a `GameStateManager` vía `ManagerLocator` (#18).
3. **Mayor esfuerzo, mejora estructural**: unificar sistema de cámara (#17), decidir el destino de `ai_type` (#13), formalizar `DungeonGenerationConfig.tres`/`RoomTemplateConfig.tres` data-driven (5.2).

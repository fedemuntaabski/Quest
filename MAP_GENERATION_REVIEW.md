# Auditoría Técnica — Sistema de Generación Procedural de Mapas y Salas

**Proyecto**: Quest (Godot 4.6, GDScript)
**Alcance**: `scripts/world/dungeon/*`, `scripts/world/rooms/*`, `scripts/core/movement/map_navigation_helper.gd`, `scripts/core/enemy/*`, escenas/recursos relacionados.
**Nota de contexto**: ya existen `analysis/MAP_GENERATION_AUDIT.md` y `analysis/MAP_GENERATION_REFACTOR.md` (2026-09-11) documentando una auditoría previa y su refactor. Este documento verifica el estado **actual** del código directamente contra esos hallazgos: confirma qué se arregló y qué sigue vivo, y agrega hallazgos nuevos no cubiertos antes.

---

## 1. Estructura General y Archivos Involucrados

### Núcleo de generación (`scripts/world/dungeon/`)

| Archivo | Rol |
|---|---|
| `DungeonGenerator.gd` | Orquestador top-level + estado de grid en runtime (`floor_cells`, `wall_cells`, `room_infos`, seed/RNG, conversión de coordenadas). Entry point: `generate_dungeon()`. |
| `DungeonLayoutGenerator.gd` | Algoritmo de layout real (colocación de salas, tallado de corredores, loop de reintentos). `RefCounted`, sin dependencia de scene tree. |
| `DungeonGraph.gd` | Modelo de grafo sala/conexión; fuerza y valida topología de cadena lineal. |
| `DungeonLayoutData.gd` | DTO inmutable de entrega (`floor_cells`, `corridor_cells`, `room_infos`, `graph`, `metadata`), validado antes de aplicarse. |
| `DungeonGenerationConfig.gd` | `Resource` con los 11 parámetros de generación (tamaño de grid, tamaño de sala, padding, largo de corredor, seed, luces). |
| `DungeonRuntimeSetup.gd` | Instancia lazy de todos los managers/helpers (`layout_generator`, `wall_manager`, `room_manager`, `room_factory`, `room_system`, `room_camera_controller`, `scene_helper`). |
| `DungeonSceneHelper.gd` | Crea/limpia nodos raíz del scene tree (`Corridors`, `Rooms`, `Walls`, `RoomDetectors`, `Enemies`) y helpers genéricos de fábrica `TileMapLayer`/`Node2D`. |
| `DungeonWallManager.gd` | Deriva `wall_cells` desde `floor_cells` (scan de 8 vecinos), fusiona celdas de pared contiguas en rectángulos, genera un `StaticBody2D` por rectángulo (Sprite2D+CollisionShape2D+LightOccluder2D). |
| `DungeonRoomFactory.gd` | Construye nodos de presentación por sala: raíz `RoomVisual_N`, `RoomArea_N` (`Area2D` trigger), nodos marcador de corredor, `PointLight2D` de sala (actualmente sin uso, ver §7). |
| `DungeonRoomManager.gd` | Bookkeeping de visibilidad/tinte de niebla de la sala activa (`set_active_room`), delega el cambio autoritativo a `RoomSystem`. |
| `DungeonPresentationManager.gd` | Construye todos los visuales: llama `DungeonRoomFactory` por sala/conexión, luego `DungeonTileRenderer` y `FogOfWarManager`. |
| `DungeonTileRenderer.gd` | Pinta el `TileMapLayer` de piso celda por celda con regla de autotile artesanal basada en vecinos. |

### Runtime de salas/grid (`scripts/world/rooms/`)

| Archivo | Rol |
|---|---|
| `MapManager.gd` | Entry point a nivel de escena (`_ready()` dispara la generación); fachada con ~30 métodos wrapper (grid/pathfinding/occupancy) que delegan a `core`. |
| `MapManagerCore.gd` | Implementación real detrás de la fachada: chequeos de transitabilidad, reglas de room-lock, delegación de pathfinding y occupancy, resolución de room-id por actor. |
| `MapTurnSetup.gd` | Bootstrap de `TurnManager` y `EnemyManager`, dispara `spawn_enemies()`. |
| `OccupancyManager.gd` | Mapa autoritativo actor↔celda con contador `_version` y señal `occupancy_changed`. |
| `room_system.gd` (`RoomSystem`) | Máquina de estado autoritativa de "sala activa"; escucha `body_entered` de `RoomArea`, fuerza transiciones de adyacencia lineal. |
| `FogOfWarManager.gd` | Dos `TileMapLayer` extra (`FogOfWar`, `VisitedFog`) dibujadas/borradas por sala según estado visitado/activo. |
| `room_camera_controller.gd` (`RoomCameraController`) | Fuente única de verdad (post-refactor) para límites de cámara/zoom, encuadre de sala y expansión de bounds en corredores. |
| `TileHighlighter.gd` / `TileHighlighterCache.gd` / `TileHighlighterRenderer.gd` | Overlay de UI (hover/path/range highlights); lee estado de `MapManager`/`DungeonGenerator`, no lo muta. |

### Navegación/pathfinding (`scripts/core/movement/`)

- `map_navigation_helper.gd` (`class_name MapNavigationHelper`) — bakea un `NavigationPolygon` en `NavigationRegion2D`, e implementa A* artesanal sobre el grid (`find_path`, `find_path_preferred`).

### Spawning de enemigos (`scripts/core/enemy/`)

| Archivo | Rol |
|---|---|
| `EnemyManager.gd` | Manager de ciclo de vida por mapa; posee `enemy_data_pool`, delega a `EnemySpawnLifecycleService`, trackea `_room_enemy_counts`, maneja flag de boss y acumulación de oro de recompensa. |
| `EnemySpawnLifecycleService.gd` | Loop real de instanciar/registrar/conectar por sala. |
| `EnemySpawnPlanner.gd` | Política de filtrado de celdas candidatas (paredes, entradas, celda del jugador, celdas ocupadas, bloqueo por occupancy manager, buffer cerca de pared). |
| `EnemyDataSelector.gd` | Elige un recurso `EnemyData` para una plantilla de sala (pools tutorial/boss/normal). |
| `EnemyData.gd` | `Resource` con stats de enemigo + `enemy_scene: PackedScene`. |
| `EnemyRewardService.gd` | Acumulación de oro, emisión de `room_cleared`/`boss_defeated` al morir el último enemigo de la sala. |
| `EnemyTurnPolicy.gd` | Decisión de IA por turno (attack/move/wait/skip), consumido por `Enemy.gd`; usa `MapManagerCore.find_path_to_adjacent`. |

### Config/recursos

- `resources/dungeon/DungeonGenerationConfig_Default.tres` — recurso de config por defecto; **no está asignado** al nodo `DungeonGenerator` en `MapManager.tscn` (verificado — no tiene línea `config =`), por lo que está inerte/de ejemplo únicamente.
- `resources/enemies/{tutorial,skeleton,boss}.tres` — instancias `EnemyData` que referencian `scenes/{TutorialEnemy,SkeletonEnemy,BossEnemy}.tscn`.
- `assets/texture/enviorment/dungeon_tileset.tres` — un solo `TileSetAtlasSource`, **sin bloque `terrain_sets`** (confirmado por grep, cero matches de "terrain").

### Escenas

- `scenes/MapManager.tscn` — escena raíz: `MapManager` (script) → hijo `DungeonGenerator` (script) + hermano `NavigationRegion2D`. Sin nodo `Player` embebido (se agrega en runtime en otro lado, vía `get_node_or_null("Player")`).
- `scenes/map_elements/Room.tscn` — escena `Node2D`+`Sprite2D` "Room". **Confirmado huérfano**: cero referencias en `.gd`/`.tscn` (el único match de `"Room.tscn"` es `WaitingRoom.tscn`, coincidencia de substring). Las salas reales se construyen como `Node2D` puro vía `DungeonRoomFactory.create_room_nodes()`, no instanciando esta escena.
- `scenes/tilemapquest.tscn` — **confirmado eliminado** (estaba flageado como huérfano en la auditoría anterior; ya no existe en `scenes/`).
- `scripts/world/camera/` — **directorio confirmado vacío**; `CameraMode.gd`, `CameraMode_Room.gd`, `CameraMode_Corridor.gd` fueron eliminados en el refactor, lógica absorbida en `room_camera_controller.gd`.
- `scripts/generation/` — no existe.

### Enfoque de generación

**No es** BSP, Drunkard's Walk, Autómata Celular, ni basado en ruido. Es **colocación aleatoria de salas rectangulares con reintentos, conectadas por una cadena lineal forzada de corredores en L**, sobre un grid de tamaño fijo (`Dictionary<Vector2i,bool>`, no un array 2D tipo TileMap).

Evidencia directa:
- `DungeonLayoutGenerator.gd:40-68` — las salas se colocan muestreando repetidamente una posición aleatoria (`dungeon.rng.randi_range`) dentro del grid y rechazando por solapamiento de AABB (`expanded.intersects(other)`, línea 61), hasta `room_count * 90` intentos (línea 37), dentro de un loop externo de `LAYOUT_RETRIES = 32` (línea 33).
- `DungeonLayoutGenerator.gd:172-188` (`_connect_rooms_with_corridors`) conecta explícitamente `Room[i] -> Room[i+1]` únicamente — un grafo de camino estricto, sin ramificación ni ciclos.
- `DungeonGraph.gd:10-11` — `LINEAR_ROOM_COUNT = 8`, `MAX_CONNECTIONS_PER_ROOM = 2`, y `validate()` (líneas 122-203) **rechaza activamente** cualquier topología donde `connected != [room_id-1, room_id+1]` (líneas 174-187) — el generador está arquitectónicamente fijado a una mazmorra lineal, no a un grafo general.

---

## 2. Algoritmo y Flujo Paso a Paso

1. **Entrada**: `MapManager._ready()` (`scripts/world/rooms/MapManager.gd:30-45`) → `_ensure_helpers()` → `_setup_turn_manager()` → conecta `dungeon_generator.map_generated` (línea 42) → llama `dungeon_generator.generate_dungeon(player)` (línea 45), síncrono, sin `await`.
2. **Init de seed/RNG** (`DungeonGenerator.gd:246-251`): si `map_seed == -1`, `rng.randomize()` luego `seed_to_use = rng.get_seed()`; si no, usa el `map_seed` fijo. Setea `rng.seed = seed_to_use` y loguea vía `QuestLogger.info(QuestLogger.Category.MAP, ...)` (línea 251). `rng` es una instancia `RandomNumberGenerator` propia del `DungeonGenerator` (línea 31), no el RNG global del motor.
3. **Limpieza de contenido previo** (`DungeonGenerator.gd:253-264`): `_clear_generated_content()` (delega a `DungeonSceneHelper.clear_generated_content()`, líneas 45-61, que hace `queue_free()` de los hijos de `corridors_root`/`rooms_root`/`walls_root`/`room_detectors_root`/`room_lights_root`/`enemies_root`), luego limpia `floor_cells`, `wall_cells`, `corridor_cells`, `wall_nodes`, `room_infos`, dicts de runtime/presentación.
4. **Cálculo de origen del grid** (`DungeonGenerator.gd:266-269`), centrando el grid en el origen del mundo.
5. **Generación de layout** (`DungeonGenerator.gd:274`, `layout_generator.generate()` → `DungeonLayoutGenerator.gd:32-88`):
   - Hasta 32 reintentos externos (`LAYOUT_RETRIES`, línea 33).
   - Tamaño de sala: `_roll_room_size()` (líneas 113-131) tira un sesgo de forma — 34% ancha, 34% alta, 32% cuadrada (`shape_roll < 0.34` / `< 0.68`, líneas 124/127).
   - Colocación + chequeo de solapamiento inline en `generate()` (líneas 40-68), usando intersección de AABB `room_rect.grow(room_padding)`.
   - Orden determinista de IDs izquierda-a-derecha vía `sort_custom` sobre el centro del rect (líneas 72-78), así `room_infos[0]` siempre es la sala más a la izquierda (spawn) y `room_infos[-1]` la más a la derecha (boss).
   - Registro por sala `_register_room()` (líneas 134-165): llena `_working_floor_cells`, construye el dict `room_info` (`id`, `rect`, `center_cell`, `floor_cells`, `template`), registra en `_working_graph.add_room()`.
   - Conexión de corredores `_connect_rooms_with_corridors()` (líneas 168-188): cadena estricta `i -> i+1`; por cada par elige un punto de salida por sala vía `_get_connection_point()` (líneas 310-327, elige una única celda de borde según dirección relativa al centro de la sala destino — diseño de "puerta única", sin entradas múltiples) y talla vía `_carve_corridor()`.
   - `_carve_corridor()` (líneas 191-246): orden en L aleatorio (`horizontal_first = rng.randf() < 0.5`, línea 205), recorre un eje y luego el otro con `signi()`; el largo del corredor se valida contra `corridor_min_length`/`corridor_max_length` pero solo vía `push_warning` (líneas 238-239) — **no se rechaza/reintenta**. El ancho se duplica vía `_add_corridor_cell_double()` (líneas 249-261), que solo agrega un offset `+1` en el eje X (línea 252) — los segmentos de corredor verticales **no** se ensanchan realmente en el eje perpendicular, solo los horizontales (bug real de ancho/consistencia, confirmado leyendo el array de offsets: `[Vector2i(0,0), Vector2i(1,0)]`, ambos eje X).
   - Validación de grafo `_validate_graph()` (líneas 300-308) llama `DungeonGraph.validate(room_count, true)`; si inválido, todo el loop de 32 reintentos vuelve a intentar (línea 85 `continue`); si los 32 reintentos fallan, `generate()` retorna `null`.
6. **Commit / aplicación**: `DungeonGenerator._apply_layout_data()` (líneas 304-310) copia `layout_data.floor_cells/corridor_cells/room_infos/graph` a los campos vivos del generador y llama `_initialize_room_state()`.
7. **Camino de falla**: si `layout_data == null` o `!layout_data.is_valid(room_count)` (líneas 275-277), `push_error` y `generate_dungeon()` retorna — **sin fallback/reintento en este nivel**. `MapManager._on_map_generated()` (`MapManager.gd:48-51`) chequea `floor_cells.is_empty()` y solo hace `push_warning` + `return` — el mapa queda vacío sin recuperación automática; la única forma de obtener un mapa nuevo es recargar la escena completa.
8. **Derivación de paredes**: `wall_manager.generate_walls_from_floor()` (`DungeonGenerator.gd:281` → `DungeonWallManager.gd:33-81`) — scan de vecinos en 8 direcciones (incluye diagonales) de cada celda de piso para juntar candidatos "no piso, no ya pared" (líneas 37-74), luego fusión greedy de rectángulos `_compute_wall_rects()` (líneas 88-117) y un `StaticBody2D` por rect fusionado vía `_spawn_wall_rect()` (líneas 191-234).
9. **Construcción de presentación**: `presentation.setup()`/`presentation.build()` (`DungeonGenerator.gd:283-290` → `DungeonPresentationManager.gd:44-89`):
   - Por sala: `DungeonRoomFactory.create_room_nodes()` → `RoomVisual_N` + `RoomArea_N` (`Area2D`), registrados en `RoomSystem`.
   - Por par de salas adyacentes: `create_corridor_entity()` crea un nodo marcador solo-metadata.
   - `DungeonTileRenderer.setup()`/`set_data()`/`build()` (líneas 78-80) pinta el `TileMapLayer` de piso.
   - `FogOfWarManager.setup()`/`build()` (líneas 82-89) crea las dos capas de niebla.
10. **Pintado de tiles / autotiling** (`DungeonTileRenderer.gd:42-82`): itera cada clave de `floor_cells` y llama `_paint_cell()`, que es un **lookup de vecinos hand-coded contra `wall_cells`** (chequea ARRIBA/ABAJO/IZQUIERDA/DERECHA y las 4 combinaciones de esquina diagonal primero, líneas 56-74) para elegir una de 9 coordenadas de atlas fijas; si no hay vecino pared, 30% de chance de tile de variación de piso aleatoria (`TILE_VARIATIONS.pick_random()`, línea 79, usa el `randf()` **global**, no `dungeon.rng` — brecha de determinismo, ver §6). `floor_layer.set_cell(cell, 0, atlas_coords)` (línea 82) es asignación manual de atlas por celda — **no se usa terrain-set / `set_cells_terrain_connect` de Godot en ningún lado** (confirmado: el `.tres` del tileset no tiene bloque `terrain_sets`; cero llamadas `set_cells_terrain_*` en el repo).
11. **Colocación del jugador**: `place_player_in_start_room()` (`DungeonGenerator.gd:313-321`) setea `player.position` al `room_infos[0]["center_cell"]` convertido a coords de mundo y llama `player.sync_to_grid()` si existe.
12. **Sala activa + señal**: `_set_active_room(room_infos[0].id, false)` (líneas 298-299), luego `map_generated.emit(layout_data)` (línea 301) — esta señal es el contrato (post-refactor) que ordena el bake de navmesh antes del spawn de enemigos.
13. **Post-generación, dirigida por `map_generated`** (`MapManager.gd:48-54`): `navigation_helper.bake_navigation_region()` corre **antes** de `_setup_enemy_manager()` (este orden fue el fix de Fase 2 del refactor — confirmado vivo en el código).

---

## 3. Tipos de Salas y Variación

**Puramente datos de grid algorítmicos — no se instancian escenas `.tscn` prefabricadas para el layout de salas.** Las salas son solo `Rect2i` + un tag string `template`:

- `DungeonLayoutGenerator._get_room_template()` (líneas 290-297): sala 0 → `DungeonGraph.TEMPLATE_TUTORIAL`, sala `room_count-1` → `TEMPLATE_BOSS`, todo lo demás → `TEMPLATE_NORMAL`. Constantes en `DungeonGraph.gd:4-8` (`TEMPLATE_TUTORIAL`, `TEMPLATE_NORMAL`, `TEMPLATE_BOSS`, más `TEMPLATE_CORRIDOR`/`TEMPLATE_CUSTOM` sin uso).
- **No existe plantilla de sala de tesoro/tienda/evento** en ningún lado del código — solo tutorial/normal/boss.
- Los visuales físicos de sala son genéricos: `DungeonRoomFactory.create_room_nodes()` (líneas 12-31) siempre crea un `Node2D` puro (`RoomVisual_N`) y un `Area2D` (`RoomArea_N`) — misma construcción para cada template, sin variante de escena por template, sin lógica de rotación en ningún lado.
- `scenes/map_elements/Room.tscn` existe pero está muerta/sin referencias (ver §1) — no es el mecanismo usado.
- La selección de template de sala solo afecta: (a) selección de pool de enemigos (`EnemyDataSelector.select_enemy_data`, indexado por string `room_template`) y (b) el flag `avoid_center` de `EnemySpawnPlanner` (true solo para `"tutorial"`, `EnemySpawnLifecycleService.gd:40`).
- Las escenas de enemigos sí **son** prefabs `.tscn` (`scenes/TutorialEnemy.tscn`, `scenes/SkeletonEnemy.tscn`, `scenes/BossEnemy.tscn`, fallback genérico `scenes/Enemy.tscn`), elegidas vía `EnemyData.enemy_scene` (`EnemyData.gd:22`) e instanciadas dinámicamente por sala en `EnemyManager.get_enemy_scene_for_room()` (líneas 65-76).

---

## 4. Conexiones, Puertas y Navegación

- **Puertas**: no existe objeto/escena de puerta física. Una "conexión" es solo celdas de piso+corredor talladas más un nodo marcador solo-metadata de `DungeonRoomFactory.create_corridor_entity()` (líneas 34-44), que guarda `room_a`/`room_b`/`corridor_cells` como metadata del nodo para bookkeeping — sin rol de colisión/visual.
- **Garantía de conectividad**: fuertemente forzada en tiempo de generación, no dejada al azar. `DungeonGraph.validate()` (líneas 189-198, `_collect_reachable_rooms()` líneas 229-250) hace un chequeo de alcanzabilidad BFS/DFS desde la sala 0 y falla la validación (disparando el loop completo de 32 reintentos, o eventualmente un fallo duro de generación) si alguna sala es inalcanzable. Combinado con la regla estricta de arista de cadena lineal (`_is_valid_linear_edge`, `absi(room_a-room_b)==1`, línea 215) y `MAX_CONNECTIONS_PER_ROOM=2`, la garantía es trivialmente fuerte (un grafo de camino recto siempre está totalmente conectado por construcción) — pero esto también significa que nunca hay loops, atajos, ni caminos ramificados.
- **NavigationRegion2D**: declarado en `scenes/MapManager.tscn:12`. Bakeado en `MapNavigationHelper.bake_navigation_region()` (líneas 18-63) construyendo un polígono de contorno por celda de piso (inset de 2px, líneas 36-53) y llamando `nav_poly.make_polygons_from_outlines()` (línea 57). **Este navmesh bakeado nunca se consulta** — confirmado por búsqueda en todo el repo: cero `NavigationAgent2D`, cero `NavigationServer2D.map_get_path`, cero uso de `nav_region.get_navigation_polygon()` para pathfinding. `find_path_preferred()` (líneas 202-219) tiene un parámetro `mode` explícito ("auto"/"astar"/"nav") y un comentario de que el modo nav se agregaría después, pero ambas ramas actualmente caen al A* manual (líneas 215-219) — capacidad muerta/vestigial.
- **Pathfinding real**: A* hand-written en `MapNavigationHelper.find_path()` (líneas 116-156), 4-direccional (`_get_neighbors`, líneas 159-188), filtrado por `is_cell_walkable()` y `occupancy_manager.is_cell_blocked()` (línea 182). No se usa clase built-in `AStar2D`/`AStarGrid2D` (confirmado 0 matches). `MapManagerCore.find_path`/`find_path_to_adjacent` (líneas 122-164) restringen la búsqueda al `Rect2i` de la sala del actor activo cuando hay room-lock.

---

## 5. Spawning de Entidades, Enemigos y Objetos

Solo se spawnean **enemigos** proceduralmente; no existe sistema de spawn de cofres/trampas/decoración en ningún lado de `scripts/world/` ni `scripts/core/enemy/` (no aparecen scripts `Chest`, `Trap`, `Decoration` en este alcance).

- Cadena de responsabilidad: `MapManager._on_map_generated()` (líneas 48-54) → `_setup_enemy_manager()` (líneas 172-176) → `MapTurnSetup.setup_enemy_manager()` (líneas 15-46) — crea el nodo `EnemyManager`, llama `.setup()` luego `.spawn_enemies(room_infos, wall_cells)` (líneas 37-40).
- `EnemyManager.spawn_enemies()` (líneas 56-58) es un delegador delgado a `EnemySpawnLifecycleService.spawn_enemies()` (líneas 4-24) — un enemigo por sala, iterando sobre `room_infos` (sin oleadas, sin salas multi-enemigo).
- La selección de celda es **aleatoria + validada por colisión/occupancy**, no basada en `Marker2D` ni en una grilla interna separada del grid de la mazmorra: `EnemySpawnPlanner.get_random_floor_cell_in_room()` (líneas 4-56) filtra candidatos por: no ser pared, no estar en `forbidden_spawn_cells` (celdas de entrada + vecinos, vía `DungeonGenerator.get_room_spawn_forbidden_cells()`, líneas 191-215), no ser la celda del jugador, no ya usada en este pase, no estar en radio `avoid_center` (solo salas tutorial), no estar adyacente a pared (buffer `near_wall`, líneas 42-49), y — post-refactor — no estar bloqueada según `OccupancyManager.is_cell_blocked()` (línea 33, parámetro agregado en Fase 1 del refactor, confirmado presente). La selección entre candidatos restantes es `candidates[randi() % candidates.size()]` (línea 56) — **usa el `randi()` global, no `dungeon.rng`** (brecha de determinismo, ver §6).
- Selección de tipo de enemigo: `EnemyManager._select_enemy_data()` (líneas 79-94) resuelve `room_template` desde `dungeon.get_room_info(room_id)` y delega a `EnemyDataSelector.select_enemy_data()` (líneas 4-34), que también usa `randi()` **global** (líneas 16, 29) para la selección aleatoria del pool boss/normal.
- Instanciación (`EnemySpawnLifecycleService._spawn_enemy_for_room`, líneas 26-116): obtiene la escena vía `manager.get_enemy_scene_for_room(room_id)` (dinámico según `EnemyData.enemy_scene` por sala), instancia, posiciona en `grid_to_world_coords(spawn_cell)`, setea `my_room_id`/`dungeon_generator`, aplica `EnemyData` vía `apply_enemy_data()`, parenta a `EnemyManager` (**no** a `dungeon.enemies_root`, que existe — `DungeonSceneHelper.gd:17` — pero nunca se usa como parent de nada, confirmado por grep: solo se le asigna y se lo referencia en el loop de limpieza), registra en `OccupancyManager` (vía `map_manager.core.repair_actor_room()`) y `TurnManager.register_actor()`.
- Manejo de boss: la sala con `template == "boss"` cuyo `EnemyData` seleccionado tenga `is_boss == true` se flaguea como boss y se renombra `Boss_Purple_%d` (líneas 84-95); `EnemyRewardService.process_enemy_defeat()` (líneas 19-20) emite `boss_defeated` en vez de la señal de recompensa normal por enemigo.
- Riesgo de fallo silencioso (aún presente, pero ahora logueado): si el pool de candidatos de una sala está vacío, `EnemySpawnPlanner` retorna `Vector2i(-1,-1)` y `EnemySpawnLifecycleService.gd:46-48` hace `push_warning(...)` y retorna sin spawnear — mejora respecto al estado pre-refactor totalmente silencioso, pero la sala igual termina con **cero enemigos y sin recuperación**, y si alguna lógica de progresión depende de que `room_cleared` dispare (lo cual requiere que `_room_enemy_counts[room_id]` exista y llegue a 0, `EnemyRewardService.gd:30-37`), una sala sin enemigo asignado nunca puede emitir `room_cleared` para ese room id.

---

## 6. Rendimiento, Seed y Determinismo

**Determinismo — parcial, no total.** El *layout* de la mazmorra (colocación de salas, tamaño, forma de corredores) es totalmente reproducible desde una seed fija; el spawn de enemigos **no**:

- `DungeonGenerator.gd:28,31,246-251` — `@export var map_seed: int = -1`, `var rng: RandomNumberGenerator`, seedeado una vez por llamada a `generate_dungeon()` y logueado (`QuestLogger.info(QuestLogger.Category.MAP, "DungeonGenerator: using seed %d" % seed_to_use)`, línea 251).
- `DungeonLayoutGenerator.gd` usa `dungeon.rng.randi_range(...)` / `dungeon.rng.randf()` en todo el archivo (líneas 52-53, 114-129, 205) — confirmado sin llamadas remanentes a `randi_range`/`randf` globales en este archivo.
- **Pero**: `DungeonTileRenderer._paint_cell()` (línea 78) usa `randf()` global para elegir tile de variación de piso; `EnemySpawnPlanner.get_random_floor_cell_in_room()` (línea 56) usa `randi()` global; `EnemyDataSelector.select_enemy_data()` (líneas 16, 29) usa `randi()` global. Ninguno de estos tres toma ni usa `dungeon.rng`. **Efecto neto: fijar `map_seed` reproduce exactamente el layout de salas/corredores/paredes, pero no la variación visual de tiles de piso, ni en qué celda spawnea un enemigo, ni qué tipo de enemigo spawnea en salas normal/boss.** Es una brecha real y verificable en la afirmación de determinismo de `MAP_GENERATION_REFACTOR.md:24-26` (ese doc solo discute determinismo de layout, así que no lo contradice, pero un lector podría asumir fácilmente que "map_seed" reproduce toda la corrida — no lo hace).
- `DungeonGenerationConfig` soporta seeds por perfil vía `config.map_seed`, copiado al init en los campos propios del generador (`DungeonGenerator.gd:232-244`) — pero el `.tres` shippeado (`resources/dungeon/DungeonGenerationConfig_Default.tres:18`, `map_seed = -1`) no está cableado a `scenes/MapManager.tscn`, así que este camino no se usa actualmente en la práctica.

**Rendimiento / sincronicidad** — confirmado totalmente síncrono, de un solo frame:

- Cero `await`, `Thread.new()`, o `WorkerThreadPool` en ningún lado de `scripts/world/dungeon/*.gd` (verificado por grep).
- Todo — reintentos de layout (hasta 32× hasta `room_count*90` intentos de colocación cada uno), derivación de paredes, pintado de tiles (una llamada `set_cell` por celda de piso), construcción de polígonos de navmesh (un contorno por celda de piso), y todo el spawn de enemigos — ocurre dentro del mismo call stack de `MapManager._ready()` → `generate_dungeon()` → handler de `map_generated`.
- Tamaños de grid por defecto: `grid_width=90`, `grid_height=70` (`DungeonGenerator.gd:14-15`) → hasta 6300 celdas; `DungeonWallManager` ahora genera un `StaticBody2D` por **rectángulo fusionado** en vez de por celda (mejora, líneas 76-117), reduciendo (pero no eliminando) la preocupación histórica de cantidad de nodos.
- La validación de largo de corredor es solo informativa: `push_warning("Corridor length %d outside bounds...")` (líneas 238-239) — no rechaza ni reintenta, así que corredores fuera de spec igual pueden shippear.
- No hay comentarios TODO/FIXME/HACK en `scripts/world/dungeon/` ni `scripts/world/rooms/` (verificado por grep en ambos dirs) — coincide con la afirmación del doc de auditoría anterior.
- No hay sección `[layer_names]` en `project.godot` (verificado) — todas las capas físicas/de colisión se referencian por números mágicos (`DungeonWallManager.gd:203-204` layer=1/mask=1 para paredes; `DungeonRoomFactory.gd:60-61` layer=0/mask=1 para triggers de área de sala).

---

## 7. Diagnóstico de Puntos Débiles, Fallos y Limitaciones

Confirmados presentes en el código actual:

1. **Salas de una sola puerta / sin ramificación** — `_get_connection_point()` elige exactamente un borde de salida por sala (`DungeonLayoutGenerator.gd:310-327`, comentario "elegimos UN SOLO borde (no múltiples entradas/salidas)" en línea 317); combinado con la cadena lineal estricta, produce un único camino crítico largo sin loops, rutas alternativas, ni salas laterales opcionales. **Es la causa raíz de la sensación de mapa monótono/poco orgánico** que menciona el pedido original.
2. **Bug de ancho de corredor** — `_add_corridor_cell_double()` (líneas 249-261) solo ofsetea `Vector2i(1,0)`, así que los corredores se ensanchan de forma confiable en el eje X pero **no** en el eje Y para segmentos verticales — riesgo real de asimetría/desalineación visual en corredores norte-sur.
3. **Largo de corredor no forzado** — `_carve_corridor()` solo advierte (líneas 238-239) si está fuera de `[corridor_min_length, corridor_max_length]`; sin rechazo/reintento ligado a este chequeo específico (separado del loop de reintento por solapamiento de salas), así que corredores demasiado largos/cortos pueden shippear silenciosamente más allá del log.
4. **Sin fallback en fallo de layout** — si los 32 reintentos fallan, `DungeonLayoutGenerator.generate()` retorna `null` (línea 88), `DungeonGenerator.generate_dungeon()` hace `push_error` y retorna con estado vacío (líneas 275-277), y `MapManager._on_map_generated()` solo hace `push_warning` (líneas 49-51) — el juego queda con un mapa genuinamente vacío y sin camino de reintento/regeneración (no existe función `regenerate()`/`next_floor()` en ningún lado del repo, confirmado).
5. **Fallo semi-silencioso de spawn de enemigo** — una sala puede terminar con cero enemigos si todos los candidatos se filtran; ahora logueado vía `push_warning` (línea 47, mejora sobre el estado histórico totalmente silencioso) pero sin recuperación, con el riesgo downstream de que `room_cleared` nunca dispare para esa sala si algo de progresión depende de eso (ver §5).
6. **Brecha de determinismo** en aleatoriedad de variación de tile/celda de enemigo/tipo de enemigo, aún usando RNG global en vez de `dungeon.rng` (ver §6) — no señalado explícitamente antes en los docs de análisis post-refactor, verificado directamente en esta auditoría.
7. **`room_lights_root` muerto/nunca creado** — declarado (`DungeonGenerator.gd:53`) y referenciado en el loop de limpieza (`DungeonSceneHelper.gd:54`) pero nunca asignado por `ensure_scene_roots()` (líneas 9-17, que solo crea `Corridors/Rooms/Walls/RoomDetectors/Enemies`) — las luces de sala (`DungeonRoomFactory.create_room_light()`, aún presente en líneas 46-55 con `energy=0.0` hardcodeado según el hallazgo histórico #4 de la auditoría) son código efectivamente muerto sin raíz viva a la cual parentarse.
8. **Ambigüedad de `enemies_root` persiste** — `DungeonSceneHelper` crea un nodo raíz `Enemies` (línea 17) pero `EnemySpawnLifecycleService` parenta los enemigos a `EnemyManager` en su lugar (`manager.add_child(enemy)`, línea 71) — el nodo `enemies_root` existe en el scene tree pero está permanentemente vacío, exactamente la ambigüedad señalada en `analysis/Grid-and-Occupancy-Ownership.md:69` y `analysis/Spawning-and-Pacing.md:56`.
9. **Escenas huérfanas**: `scenes/map_elements/Room.tscn` sin referencias (hallazgo nuevo, no cubierto en ninguno de los dos docs de análisis previos — solo flagueaban `tilemapquest.tscn`, ya eliminado).
10. **`DungeonGenerationConfig_Default.tres` sin uso en la práctica** — no asignado a `scenes/MapManager.tscn`, así que el camino data-driven agregado por el refactor está actualmente dormido (confirmado leyendo el `.tscn`, que no tiene propiedad `config` seteada en el nodo `DungeonGenerator`).
11. **Bake de NavigationRegion2D vestigial** — confirmado que se bakea en cada generación (`MapNavigationHelper.bake_navigation_region()`, llamado desde `MapManager._on_map_generated()`, línea 53) pero nunca se consume para pathfinding (0 queries `NavigationAgent2D`/`NavigationServer2D` en el repo) — CPU/memoria gastada en construcción de navmesh sin uso, un polígono de contorno por celda de piso (hasta miles en mapas grandes).
12. **Nota sobre `occ_version`**: `OccupancyManager._version` (`OccupancyManager.gd:10,154,158-159`) es un contador monotónico simple incrementado dentro de `_update_actor_cell()`; no se encontró ningún lector adicional que asuma atomicidad a través de múltiples pasos más allá de lo ya documentado en `analysis/Grid-and-Occupancy-Ownership.md:58` ("los consumidores deberían leer la versión atómicamente para evitar queries obsoletas durante movimientos multi-paso") — sigue siendo un riesgo documentado-pero-no-verificado-como-explotado, no un bug confirmado en vivo dentro de este alcance.
13. **Acoplamiento de room-lock a la cadena lineal**: `MapManagerCore.is_cell_allowed_for_actor()` (líneas 59-82) y `_get_actor_room_rect()` (líneas 261-276) restringen fuerte el movimiento/pathing de enemigos a su propio rect de sala y bloquean al jugador a la sala activa mientras queden enemigos (`_is_player_room_locked()`, líneas 251-259) — por diseño, pero vale notarlo para la auditoría como mecánica fuertemente acoplada al supuesto de cadena lineal (se rompe si el grafo alguna vez deja de ser lineal sin revisar esta lógica).

### Hallazgos históricos ya corregidos (no re-reportar como bugs vivos)

Confirmado en el código actual que `analysis/MAP_GENERATION_AUDIT.md` está desactualizado en estos puntos — el refactor documentado en `analysis/MAP_GENERATION_REFACTOR.md` ya los resolvió:

- `_room_overlaps_existing()`/`_fill_corner()` muertas — eliminadas (grep sin matches).
- Export `main_path_branching` sin uso — eliminado de `DungeonGenerator.gd`.
- `room_count = 8` hardcodeado en el layout generator — eliminado, ahora fluye desde `dungeon.room_count`/config.
- Campo `ai_type` en `EnemyData` — eliminado.
- `randomize()` no determinista — reemplazado por `RandomNumberGenerator` seedeado (salvo las brechas del punto 6/§6).
- Orden spawn-de-enemigo-antes-de-navbake — arreglado vía señal `map_generated`.
- Race condition en `PlayerMovement._ready()` — arreglado vía sincronización basada en señal `_on_map_generated`.
- Costo de spawn de `StaticBody2D` por celda de pared — fusionado en rectángulos.
- Lógica de cámara triplicada (`CameraMode_Room`/`CameraMode_Corridor`) — eliminada, consolidada en `RoomCameraController`.
- `scenes/tilemapquest.tscn` huérfana — eliminada.

---

## Resumen ejecutivo

El sistema genera mazmorras **lineales por diseño** (8 salas en cadena, sin ramas, sin loops), con colocación de rectángulos por reintento aleatorio — no BSP ni autómata celular. La conectividad está garantizada matemáticamente (por construcción del grafo, no por validación defensiva), pero esa misma rigidez es la causa principal de la sensación de monotonía: un solo camino, una puerta por sala, sin salas especiales (tesoro/tienda/evento), sin variedad estructural. Los bugs técnicos más accionables son: (1) el ensanchado de corredor asimétrico eje X vs Y, (2) la ausencia total de fallback si la generación falla tras 32 reintentos, y (3) la brecha de determinismo por usar RNG global en 3 puntos (tile paint, celda de enemigo, tipo de enemigo) pese a tener seed dedicada para el layout. El navmesh baked es trabajo desperdiciado (nunca consumido). No hay riesgo de loop infinito confirmado — los retry loops tienen límites duros (32 y `room_count*90`) — pero sí hay un "fallo silencioso hacia mapa vacío" cuando se agotan.

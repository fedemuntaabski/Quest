# Refactor: Ramas, Salas Especiales, Determinismo y Limpieza en Generación de Mazmorras

**Fecha:** 2026-09-16
**Rama:** `refactor/code-audit-cleanup`
**Continúa sobre:** `analysis/MAP_GENERATION_REFACTOR.md` (refactor previo de determinismo/spawning/cámara)

La mazmorra era una cadena lineal estricta de 8 salas vacías (`DungeonGraph._is_valid_linear_edge()` rechazaba cualquier conexión no `id±1`; cada sala tenía una sola puerta). Este refactor agrega ramas secundarias (tesoro/tienda), obstáculos internos en salas, cierra los huecos de determinismo restantes, corrige un bug de simetría en corredores, agrega fallback anti-mapa-vacío, y limpia código/recursos muertos.

Todo se verificó leyendo el código real antes de tocarlo (no es especulación) y se probó vía diagnósticos del editor en cada edición (no hay `godot`/`godot4` disponible en este entorno para correr un smoke test real — queda como verificación pendiente).

---

## FASE 1 — Determinismo + fixes críticos

### RNG global → `dungeon.rng`
- **`DungeonTileRenderer.gd`**: agregado `var rng: RandomNumberGenerator`, nuevo parámetro en `setup()`. `_paint_cell()` ya no usa `randf()`/`Array.pick_random()` globales (no seedables) sino `rng.randf()`/indexado manual con `rng.randi_range()`.
- **`EnemySpawnPlanner.get_random_floor_cell_in_room()`**: ya recibía `dungeon` sin usarlo para RNG — ahora usa `dungeon.rng.randi_range()` para elegir la celda de spawn.
- **`EnemyDataSelector.select_enemy_data()`**: nuevo parámetro `rng: RandomNumberGenerator = null`, usado en ambos sorteos de tipo de enemigo (con fallback a `randi()` si no se pasa). `EnemyManager._select_enemy_data()` ahora pasa `dungeon.rng`.

Con esto, fijar `map_seed` reproduce layout, variación de tiles y spawn/tipo de enemigos de forma idéntica.

### Simetría de corredores
`DungeonLayoutGenerator._add_corridor_cell_double()` aplicaba siempre el mismo offset (`Vector2i(1,0)`) sin importar si el tramo era horizontal o vertical — los corredores verticales nunca se ensanchaban en Y. Se agregó un array paralelo `corridor_is_vertical` en `_carve_corridor()` que registra la orientación real de cada celda, y `_add_corridor_cell_double()` ahora aplica el offset perpendicular al movimiento (`Vector2i(1,0)` para tramos verticales, `Vector2i(0,1)` para horizontales).

**Corrección posterior (mismo día):** la primera implementación de este fix quedó con el mapeo invertido (`is_vertical → Vector2i(0,1)`, cuando el offset perpendicular correcto para un tramo vertical es en X). Corregido a `Vector2i(1, 0) if is_vertical else Vector2i(0, 1)`.

### Fallback anti-mapa-vacío
`DungeonGenerator.generate_dungeon()`: si `DungeonLayoutGenerator.generate()` falla (agotó sus 32 reintentos internos), ahora reintenta hasta 3 veces más con `map_seed + 1`, `+2`, `+3` (constante `MAX_GENERATION_ATTEMPTS := 4`), logueando cada intento fallido con `QuestLogger.warn()`. Nunca deja la escena con mapa vacío sin al menos un `QuestLogger.error()` explícito.

---

## FASE 2 — Grafo con ramas y salas especiales

### `DungeonGraph.gd`
- `MAX_CONNECTIONS_PER_ROOM`: `2` → `3`.
- Nuevas constantes `TEMPLATE_TREASURE`, `TEMPLATE_SHOP`, `TEMPLATE_EVENT`.
- Eliminada `_is_valid_linear_edge()` y todo el bloque de `validate()` que forzaba cadena estricta (cada sala conectada solo a `id-1`/`id+1`). Se mantiene el chequeo de cap de conexiones y la validación de conectividad (BFS), ambos ya genéricos.
- `add_edge()` ahora acepta un parámetro `kind` (`"critical"` / `"branch"` / `"shortcut"`), guardado en el edge para logging/debug.
- Semántica de `expected_room_count` pasó de "exactamente N" a "al menos N" (el total de salas ahora es camino crítico + ramas).

### `DungeonLayoutGenerator.gd` — topología
- Las primeras `room_count` salas siguen siendo el camino crítico (0=tutorial, última=boss), sin cambios en su empaquetado ni encadenado.
- `_roll_branch_plan()`: decide 1-2 ramas (si `room_count >= 4`), cada una de profundidad 1 (70%) o 2 (30%), template `TREASURE` (60%) o `SHOP` (40%).
- Las salas de rama se registran después del camino crítico, con ids continuos (sin renumerar), vía `_register_room()` extendido con `template_override`.
- `_connect_branch_rooms()`: conecta cada rama a una sala aleatoria del camino crítico (nunca tutorial ni boss), respetando el cap de conexiones.
- `_maybe_add_shortcut_edge()`: con 15% de probabilidad (si `room_count >= 5`), conecta dos salas no consecutivas del camino crítico (nunca la sala boss).
  - **Bug encontrado y corregido durante la implementación**: el rango inicial de `randi_range()` para el atajo podía dar `min > max` cuando `a` tomaba su valor más alto permitido, causando un `randi_range` inválido. Se ajustó el límite superior de `a` a `critical_path_count - 4`.

### Fixes adicionales encontrados durante la implementación (no estaban en el pedido original, pero eran bloqueantes)
- **`DungeonPresentationManager.build()`**: solo creaba entidades visuales de corredor para pares `i→i+1` — las ramas/atajos habrían quedado sin corredor visual. Ahora itera `graph.get_edge_records_sorted()`.
- **`scripts/world/rooms/room_system.gd`, `_is_valid_linear_transition()`**: tenía `if absi(to_id - from_id) != 1: return false` — esto habría bloqueado en runtime cualquier entrada del jugador a una sala de rama (id no consecutivo), aunque la generación fuera correcta. Se eliminó ese chequeo; la validación depende solo de `dungeon.are_rooms_connected()`.
- **`DungeonLayoutData.is_valid()`**: `room_infos.size() != expected_room_count` → `size() < expected_room_count`, espejo del cambio de semántica en `DungeonGraph.validate()`.

### Sin combate en salas especiales
- `EnemySpawnLifecycleService._spawn_enemy_for_room()`: return temprano (antes de pedir la escena de enemigo) si `template` es `treasure`/`shop`.
- `EnemyDataSelector.select_enemy_data()`: devuelve `null` para esos templates como defensa adicional.
- **Hardening posterior (mismo día):** ambos guards usaban strings literales (`"treasure"`/`"shop"`) en vez de `DungeonGraph.TEMPLATE_TREASURE`/`TEMPLATE_SHOP`, sin normalizar mayúsculas. Se cambió a las constantes de `DungeonGraph` (clase global, sin import necesario) y `EnemySpawnLifecycleService` ahora normaliza con `.to_lower()` antes de comparar, con log en español a nivel `info`.

---

## FASE 3 — Variación interna de salas

Nuevo archivo **`scripts/world/dungeon/DungeonRoomObstaclePlacer.gd`**. Decisión clave: los obstáculos se crean **borrando celdas de `floor_cells`**, no insertándolas en `wall_cells` directamente — `DungeonWallManager.generate_walls_from_floor()` ya promueve a pared cualquier celda vecina de piso que no esté en `wall_cells`, así que borrar de `floor_cells` deja que el pipeline existente genere pared física, tile de borde y bloqueo de spawn automáticamente, sin tocar `DungeonWallManager`.

- 3 patrones de obstáculo (pilares 50%, cobertura central 30%, esquinas 20%), máximo 12% de las celdas de piso de la sala.
- Reutiliza `dungeon.get_room_spawn_forbidden_cells()` (detección de entradas existente) para no bloquear puertas.
- BFS de verificación (`_keeps_entrances_connected`) antes de comprometer los obstáculos, para garantizar que las entradas sigan conectadas entre sí.
- Sala tutorial excluida; sala boss incluida a propósito (interés táctico).
- Toda la aleatoriedad usa `dungeon.rng`.
- Llamado desde `DungeonGenerator.generate_dungeon()` justo después de `_apply_layout_data()` y antes de `wall_manager.generate_walls_from_floor()`.

**Bug encontrado post-implementación** (reportado por el usuario vía error del editor): en `_keeps_entrances_connected()`, el loop `for dir in [Vector2i.RIGHT, ...]` usaba un array-literal sin tipo, por lo que `dir` quedaba como `Variant` y `var neighbor := current + dir` no podía inferir tipo (parser error). Corregido tipando explícitamente `var dirs: Array[Vector2i] = [...]` y `var neighbor: Vector2i = current + dir`.

---

## FASE 4 — Limpieza

- **Enemigos → `dungeon.enemies_root`**: `EnemySpawnLifecycleService` parentaba enemigos a `EnemyManager` (`manager.add_child(enemy)`); `dungeon.enemies_root` existía y ya se limpiaba en cada generación pero nunca recibía hijos. Ahora los enemigos se parentan a `dungeon.enemies_root` (con fallback a `manager` si no existe), y `global_position` se asigna *después* de `add_child` (antes de estar en el árbol, la posición se resolvía contra transform identidad).
- **Bake de NavMesh muerto eliminado**: `MapNavigationHelper.bake_navigation_region()` generaba un `NavigationPolygon` síncrono por celda en cada carga de mapa sin ningún consumidor (todo el pathfinding real usa A* manual; el modo `"nav"` de `find_path_preferred()` es un stub nunca invocado). Se borró la función y su único call site en `MapManager._on_map_generated()`. Se dejaron intactos el nodo `NavigationRegion2D`, el campo `nav_region` y el stub `mode == "nav"` (punto de extensión de costo cero, fuera de scope de esta limpieza).
- **Escena huérfana eliminada**: `scenes/map_elements/Room.tscn` (cero referencias confirmadas en todo el repo).
- **`DungeonGenerationConfig_Default.tres` conectado**: `scenes/MapManager.tscn` no tenía `config` asignado en el nodo `DungeonGenerator`, así que el `.tres` estaba inerte (el bloque de copia en `generate_dungeon()` nunca corría). Se agregó el `ext_resource` y `config = ExtResource(...)`. Se agregó un comentario junto a `@export var config` avisando que a partir de ahora el `.tres` es la fuente de verdad, no los `@export` del nodo en el Inspector.

---

## FASE 5 — Logging de verificación

- **Topología**: `DungeonLayoutGenerator.generate()` loguea `rooms=N critical_path=N branches=N edges=N` al completar una generación válida.
- **Determinismo**: `DungeonGenerator.generate_dungeon()` calcula y loguea un hash (`sha256_text()`) de `floor_cells` ordenado; `EnemySpawnLifecycleService.spawn_enemies()` loguea un hash de `nombre@posición` de cada enemigo spawneado. Corriendo dos veces con el mismo `map_seed`, ambos hashes deben coincidir byte a byte.

---

## Archivos modificados

- `scripts/world/dungeon/DungeonGenerator.gd`
- `scripts/world/dungeon/DungeonLayoutGenerator.gd`
- `scripts/world/dungeon/DungeonGraph.gd`
- `scripts/world/dungeon/DungeonLayoutData.gd`
- `scripts/world/dungeon/DungeonTileRenderer.gd`
- `scripts/world/dungeon/DungeonPresentationManager.gd`
- `scripts/world/rooms/room_system.gd`
- `scripts/world/rooms/MapManager.gd`
- `scripts/core/enemy/EnemySpawnPlanner.gd`
- `scripts/core/enemy/EnemyDataSelector.gd`
- `scripts/core/enemy/EnemySpawnLifecycleService.gd`
- `scripts/core/enemy/EnemyManager.gd`
- `scripts/core/movement/map_navigation_helper.gd`
- `scenes/MapManager.tscn`

## Archivos creados

- `scripts/world/dungeon/DungeonRoomObstaclePlacer.gd`

## Archivos eliminados

- `scenes/map_elements/Room.tscn`

---

## Verificación pendiente

No hay `godot`/`godot4` en el PATH de este entorno — no se pudo correr un smoke test real. Checklist manual sugerido (`godot --path . --editor` y luego `godot --path .`):

1. Parseo sin errores en el editor (los dos parser errors encontrados en esta sesión ya están corregidos).
2. Log de topología muestra camino crítico + 1-2 ramas con templates `treasure`/`shop`.
3. Ninguna sala de rama spawnea enemigos de combate (log de skip coincide con ids de rama).
4. Caminar del camino crítico a una sala de rama y volver — sin warning de "rejected activation".
5. Fijar `map_seed` en el `.tres`, correr dos veces, comparar los hashes de fingerprint en los logs — deben coincidir. Cambiar la seed en 1 y confirmar que cambian.
6. Inspección visual de corredores: tramos horizontales y verticales ambos de 2 celdas de ancho.
7. Forzar un `room_count` imposible para el grid y confirmar los reintentos + error final controlado (nunca mapa vacío silencioso).
8. Confirmar que los enemigos son hijos de `Enemies` (`dungeon.enemies_root`), no de `EnemyManager`.

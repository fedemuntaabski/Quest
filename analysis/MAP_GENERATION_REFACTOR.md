# Refactor: Generación de Mapa, Spawning, Integración de Jugador y Cámara

**Fecha:** 2026-09-11
**Rama:** `refactor/code-audit-cleanup`
**Basado en:** `analysis/MAP_GENERATION_AUDIT.md` (19 hallazgos originales)

Refactor ejecutado en 3 fases sobre el pipeline de generación de dungeon, spawning de enemigos, integración del jugador y cámara. Cada hallazgo del audit fue verificado contra el código real antes de aplicar el cambio (algunos números de línea del audit original estaban desactualizados).

---

## Decisiones tomadas

| Decisión | Elegido | Alternativa descartada | Motivo |
|---|---|---|---|
| Zoom de cámara | Restaurar cálculo dinámico (viewport/room size) | Mantener `Vector2(3.3,3.3)` fijo | El cálculo correcto ya existía en `CameraMode_Room` pero nunca se aplicaba a `camera.zoom` — comportamiento roto, no diseño intencional |
| Inyección de `DungeonGenerationConfig` | Copy-on-init (config opcional copia valores encima de los `@export` existentes al inicio de `generate_dungeon()`) | Reemplazo total de campos (`dungeon.room_count` lee directo de `config.room_count`) | Evita tocar 27+ referencias externas a `dungeon.room_count`/`grid_width`/etc en 4+ archivos; config queda 100% opcional/aditivo |
| Física de muros (`DungeonWallManager`) | Migrar ahora: merge greedy de celdas de pared contiguas en rectángulos, 1 `StaticBody2D` por rectángulo | Solo documentar el tradeoff sin tocar código | Se confirmó que los muros no tienen variación visual por celda (textura/tint/shape uniformes) — fusionar sprite+colisión+occluder es seguro y reduce drásticamente el conteo de nodos |
| `ai_type` en `EnemyData` | Eliminar campo | Implementar branching real en `EnemyTurnPolicy` | Cero referencias en código o `.tres` — sin evidencia de intención futura, mantenerlo sin uso es confuso |

---

## FASE 1 — Determinismo, spawning seguro, limpieza

### Seed reproducible
- **`scripts/world/dungeon/DungeonGenerator.gd`**: agregado `@export var map_seed: int = -1` y `var rng: RandomNumberGenerator`. Si `map_seed == -1`, se genera uno nuevo (`rng.randomize()` + `get_seed()`) y se loggea vía `QuestLogger.info(QuestLogger.Category.MAP, ...)`. Reemplaza el `randomize()` global no reproducible.
- **`scripts/world/dungeon/DungeonLayoutGenerator.gd`**: todos los `randi_range()`/`randf()` (colocación de salas, roll de tamaño, dirección de corredor) ahora usan `dungeon.rng` en vez de las funciones globales — con la misma seed, el layout es 100% reproducible.

### Spawning seguro vía `OccupancyManager`
- **`EnemySpawnPlanner.get_random_floor_cell_in_room()`**: nuevo parámetro `occupancy_manager: OccupancyManager = null`; dentro del loop de candidatos ahora descarta celdas con `occupancy_manager.is_cell_blocked(cell)`.
- **`EnemyManager._get_random_floor_cell_in_room()`** y **`EnemySpawnLifecycleService`**: propagan el `OccupancyManager` obtenido de `map_manager.get_occupancy_manager()` a través de toda la cadena de llamadas.
- **`EnemySpawnLifecycleService`**: si una sala agota los candidatos de spawn, ahora emite `push_warning` con el room_id en vez de fallar en silencio.

### Limpieza de código muerto
- Borradas `_room_overlaps_existing()` y `_fill_corner()` de `DungeonLayoutGenerator.gd` (cero call sites).
- Borrado `@export var main_path_branching` de `DungeonGenerator.gd` (nunca leído). El literal `"main_path_branching": false` en metadata de `DungeonLayoutGenerator.gd` se dejó intacto (inerte, fuera de scope).
- Borrada la escena huérfana `scenes/tilemapquest.tscn` (sin referencias en todo el repo).

---

## FASE 2 — Señal `map_generated`, fin de race condition, `ManagerLocator`

### Señal `map_generated`
- **`DungeonGenerator.gd`**: nueva `signal map_generated(layout_data: DungeonLayoutData)`, emitida al final de `generate_dungeon()` (solo en el camino de éxito — la función ya retorna antes en fallo de layout).

### `MapManager.gd` — orden de `_ready()` corregido
Antes: `generate_dungeon()` → guard → `_setup_enemy_manager()` → `bake_navigation_region()` (spawn de enemigos antes del navmesh, hallazgo #16 del audit).
Ahora: se conecta a `map_generated` antes de generar; el nuevo handler `_on_map_generated()` corre `bake_navigation_region()` primero y luego `_setup_enemy_manager()`.

### Fin de la race condition en `PlayerMovement`
- `PlayerMovement._ready()` ya no llama `sync_to_grid()`/`register_actor()` directamente (antes corría con `map_manager.core`/`occupancy_manager` aún `null`, autocorregido solo por el orden implícito de `DungeonGenerator.place_player_in_start_room()`).
- Ahora se conecta a la señal `map_generated` y hace el sync/register en el handler `_on_map_generated()`.
- **Detalle de implementación no trivial**: `map_manager.dungeon_generator` es un `@onready var` de `MapManager`, y como `PlayerMovement` es hijo de `MapManager` en la escena, su `_ready()` corre *antes* que los `@onready var` del padre se resuelvan (Godot resuelve onready del padre recién antes de llamar a su propio `_ready()`, después de que todos los hijos ya corrieron el suyo). Por eso se usa `map_manager.get_node_or_null("DungeonGenerator")` (lookup directo por nombre de nodo, no depende del onready) para obtener la referencia y conectar la señal.

### Unificación de acceso a `GameStateManager`
Reemplazados los 11 sitios que reimplementaban `get_tree().get_first_node_in_group("game_state_manager")` por `ManagerLocator.get_game_state_manager()`, preservando la lógica de reintento (`call_deferred`) donde existía:
`TileHighlighter.gd`, `MapManagerCore.gd`, `PotionController.gd`, `CardSystemController.gd` (x2), `PlayerMovementTurnBridge.gd`, `PlayerActionController.gd` (x2), `PlayerMovement.gd`, `TurnManager.gd` (x2).
`Main2d.gd` no se tocó — mantiene su instancia cacheada autoritativa (crea el nodo `GameStateManager` si no existe).

---

## FASE 3 — Cámara, config data-driven, física de muros

### Cámara consolidada
- **`scripts/world/rooms/room_camera_controller.gd`** es ahora el único escritor de `camera.limit_*`/`camera.zoom` (antes había doble escritura: `CameraMode_Room`/`CameraMode_Corridor` por frame, y el propio controller en cada cambio de sala).
- Restaurado el cálculo dinámico de zoom (viewport-fit, usando los exports ya existentes `margin_factor`/`min_zoom`/`max_zoom`, antes muertos).
- Agregado manejo de márgenes ampliados en pasillo (`corridor_base_margin_tiles`/`corridor_margin_expansion_factor`, portados de `CameraMode_Corridor`), aplicado cada frame mientras el jugador está en un pasillo.
- **Borrados**: `scripts/world/camera/CameraMode.gd`, `CameraMode_Room.gd`, `CameraMode_Corridor.gd` (lógica absorbida por `RoomCameraController`, confirmado sin otros referenciadores).

### `DungeonGenerationConfig` (data-driven)
- Nuevo `scripts/world/dungeon/DungeonGenerationConfig.gd` (`Resource`) con los 12 parámetros de generación (grid, salas, corredores, luces, seed).
- `DungeonGenerator.gd` tiene `@export var config: DungeonGenerationConfig = null`; si se asigna, sus valores se copian encima de los `@export` propios al inicio de `generate_dungeon()` (patrón copy-on-init, opcional/aditivo).
- Nuevo recurso `resources/dungeon/DungeonGenerationConfig_Default.tres` con los valores default actuales (no asignado por defecto a ninguna escena).
- `DungeonLayoutGenerator.gd`: eliminado el hardcode `dungeon.room_count = 8` — `room_count` ahora respeta el valor real configurado (el validador de grafo y la selección de template de sala ya eran genéricos sobre `room_count`, así que esto es seguro para cualquier valor).

### Física de muros — merge de rectángulos
- **`DungeonWallManager.gd`**: `generate_walls_from_floor()` ahora recolecta todas las celdas de pared candidatas primero, las fusiona en rectángulos contiguos vía un algoritmo greedy (`_compute_wall_rects()`), y spawnea **un solo** `StaticBody2D` (con `Sprite2D` + `CollisionShape2D` + `LightOccluder2D`) por rectángulo en vez de por celda.
- Esto era seguro de hacer porque los muros no tienen variación visual por celda (mismo texture/tint/shape en todos), a diferencia del piso que sí tiene autotiling.
- Se mantiene `_spawn_wall(cell)` (una celda) sin cambios, usado por la API dinámica `set_wall()` — confirmado sin callers activos en el repo hoy, documentado como limitación aceptada que `clear_wall()` sobre una celda dentro de un rectángulo fusionado libera el bloque completo.

### `ai_type` eliminado
- `scripts/core/enemy/EnemyData.gd`: borrado `@export var ai_type: String = "melee_chase"` (cero referencias en código o `.tres`, `EnemyTurnPolicy.decide()` intacto).

---

## Archivos modificados

- `scripts/world/dungeon/DungeonGenerator.gd`
- `scripts/world/dungeon/DungeonLayoutGenerator.gd`
- `scripts/world/dungeon/DungeonWallManager.gd`
- `scripts/core/enemy/EnemySpawnPlanner.gd`
- `scripts/core/enemy/EnemySpawnLifecycleService.gd`
- `scripts/core/enemy/EnemyManager.gd`
- `scripts/core/enemy/EnemyData.gd`
- `scripts/core/movement/PlayerMovement.gd`
- `scripts/world/rooms/MapManager.gd`
- `scripts/world/rooms/room_camera_controller.gd`
- `scripts/world/rooms/TileHighlighter.gd`
- `scripts/world/rooms/MapManagerCore.gd`
- `scripts/ui/hud/PotionController.gd`
- `scripts/core/cards/CardSystemController.gd`
- `scripts/core/movement/PlayerMovementTurnBridge.gd`
- `scripts/core/movement/PlayerActionController.gd`
- `scripts/core/actions/TurnManager.gd`

## Archivos creados

- `scripts/world/dungeon/DungeonGenerationConfig.gd`
- `resources/dungeon/DungeonGenerationConfig_Default.tres`

## Archivos eliminados

- `scenes/tilemapquest.tscn`
- `scripts/world/camera/CameraMode.gd`
- `scripts/world/camera/CameraMode_Room.gd`
- `scripts/world/camera/CameraMode_Corridor.gd`

---

## Verificación pendiente

No hay test suite/CI en el repo. Verificación manual sugerida (`godot --path . --editor` y luego `godot --path .`):
1. Log de seed en consola al generar mapa.
2. Salas con enemigos programados los tienen, o aparece el `push_warning` de sala agotada (no fallo silencioso).
3. Jugador aparece posicionado y registrado en el grid desde el primer frame (sin quedar "pegado" en 0,0).
4. Zoom dinámico visible al cambiar entre salas de distinto tamaño; márgenes ampliados en pasillos.
5. Sin huecos/artefactos visuales en muros tras el merge de rectángulos.

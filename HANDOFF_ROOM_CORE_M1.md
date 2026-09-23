# Handoff — Milestone 1: Room Core / Graph Integrity

Rama: `feature/td-module-effects`. Plan completo: `C:\Users\FEDE\.claude\plans\ultra-whimsical-puffin.md`.
Refactor puro: **sin cambios de comportamiento de gameplay**. No se agregó ni se ejecutó ningún test (ver "Fuera de este cambio").

## Cambios realizados

### T1.1 — Reach-ins y convenciones divergentes
- `scripts/world/RoomManager.gd`
  - Accessors públicos nuevos: `get_room_zone_id_in_group(group_id)` (promueve el antiguo `_first_room_zone_in_group`), `get_zone_kind(zone_id)`, `get_zone_node(zone_id)`, `get_zone_ids()`.
  - Predicado único `is_room_dark(zone_id)` (revelada y sin energía), usado por `get_dark_rooms()` y `get_unpowered_revealed_room_group_ids()`.
- `scripts/entities/Enemy.gd`: `on_zone_entered` y `_find_zone_with_modules` usan los accessors en vez de `room_manager.zones[...]`.
- `scripts/managers/EnemyManager.gd`: `spawn_enemies_in_room` usa `get_room_zone_id_in_group()` en lugar de `zone_ids[-1]` (antes divergía de la convención "primer room-kind" de `RoomManager`).

### T1.2 — Sin caché `RoomZone.is_visited`
- Eliminado el campo `is_visited` de `scripts/world/RoomZone.gd`; el gate de click en `_on_input_event` ahora usa `_revealed`.
- `RoomManager.reveal_room()` ya no escribe estado de visita; `get_dark_rooms()`/`get_powered_rooms()` consultan `is_zone_revealed()` (→ `DoorTurnSystem`).
- Discovery queda con una única fuente: `DoorTurnSystem.rooms[group_id].visited`.

### T1.3 — Ownership documentado
- Docstrings en `RoomManager.gd`, `RoomZone.gd` y `DoorTurnSystem.gd`: `RoomManager` = geometría/grafo/consultas · `RoomZone` = visual/input · `DoorTurnSystem` = estado/lifecycle.
- Documentada la diferencia entre zone-graph (grano movimiento, incluye corredores, autoral) y room-graph (grano puertas, solo rooms, derivado).

### T2.1 — Door-graph derivado
- `scripts/world/Door.gd`: `room_a_id`/`room_b_id` dejan de ser `@export` (ninguna `.tscn` los seteaba).
- `RoomManager._link_door_to_rooms()` los calcula siempre: `room_a = from_zone_id`, `room_b = get_room_zone_id_in_group(target_room_id)`. Se eliminaron las ramas "si viene seteado".

### T3.1 — Consultas del grafo
- Sin cambio de firmas públicas. Se mantienen ambas granularidades: `find_zone_path`/`are_connected` (zonas) y `are_rooms_connected`/`is_path_open`/`get_adjacent_rooms` (rooms/puertas).

### T4.1 — `RoomManager.validate_graph() -> bool`
- Verifica: aristas simétricas y con endpoints existentes, zonas↔grupos consistentes, y que las puertas coincidan uno a uno con las conexiones room↔room derivadas del zone-graph (colapsando cadenas de corredores).
- Loguea cada problema con `QuestLogger.warn` (categoría MAP); si no hay problemas, `QuestLogger.info` con conteos. No crashea.
- Se llama una vez al final de `Main2d._register_groups_and_doors()`.

## Archivos modificados
`scripts/core/actions/DoorTurnSystem.gd`, `scripts/entities/Enemy.gd`, `scripts/managers/EnemyManager.gd`, `scripts/managers/Main2d.gd`, `scripts/world/Door.gd`, `scripts/world/RoomManager.gd`, `scripts/world/RoomZone.gd`.

## Fuera de este cambio
- **Tests**: se había instalado GUT y escrito una suite, pero se retiraron a pedido; no hay `addons/gut/` ni `test/`. Las tareas T5.1/T5.2 del plan quedan sin hacer.
- **Sin verificar**: no hay binario de Godot en el entorno, así que nada de esto fue ejecutado ni jugado.

## Pendiente para cerrar M1 (T6.1)
1. Abrir el proyecto en Godot y comprobar que no hay errores de parseo.
2. En el log al iniciar debe aparecer `RoomManager.validate_graph: OK (5 rooms, 4 doors).`
3. Playtest completo: mover, abrir las 4 puertas, energizar, construir, tomar Nexo, extracción (invasiones en rooms oscuras), victoria.
4. Comprobar que no quedan reach-ins: buscar `\.zones\[` fuera de `RoomManager.gd` (0 resultados al momento de escribir esto) y `is_visited` en `scripts/` (0).

Con eso, M1 queda cerrado y se puede arrancar M2 (Discovery / Visibility).

# Handoff — Milestone 2: Discovery / Visibility

Rama: `feature/td-module-effects`. Plan: `C:\Users\FEDE\.claude\plans\pasted-content-id-39e6-quiero-continuar-imperative-cookie.md`.
Refactor sin cambios de gameplay. Sin tests agregados. **Nada ejecutado** (no hay binario de Godot en el entorno).

## Cambios
- `RoomManager.gd`
  - Glosario revealed/visible/shown en docstring.
  - Nuevos: `is_group_revealed(group_id)`, `is_zone_visible(zone_id)` (derivado, == revealed; único punto de extensión futuro). `is_zone_revealed` delega en `is_group_revealed`.
  - Pipeline único de presentación: `reveal_room` → `apply_zone_visibility(zone_id)` (idempotente, guiado por `is_zone_visible`); `on_group_revealed` ahora pinta también la celda de puerta; nuevo `refresh_visibility()` (bootstrap, deriva de estado).
  - `refresh_door_visibility` usa `is_zone_visible`.
  - Nuevo `validate_visibility()` (dev): compara `is_zone_visible` vs `RoomZone.is_shown()` vs tiles pintados. Corre tras cada `on_group_revealed` solo en builds debug; se saltea con `auto_fill_full_map`.
- `RoomZone.gd`: `_revealed`→`_shown`, `set_revealed`→`set_shown`, `set_visibility`→`_set_render_visible` (privado), `is_revealed`→`is_shown`. Solo render state empujado.
- `Main2d.gd`: ya no pinta tiles; bootstrap con `room_manager.refresh_visibility()` (sin literal `"start"`); `_on_room_revealed` solo retransmite.
- `PlayerActionController.gd`: chequeo de puerta vía `room_manager.is_group_revealed` (sin reach-in a `DoorTurnSystem`).
- `FloorGenerator.gd`, `DoorTurnSystem.gd`: solo docstrings (`room_revealed` = evento de discovery).

Sin señales, managers, autoloads ni estado persistente nuevos. Greps: `is_visited`, `set_revealed`, `is_revealed(`, `reveal_room`, `set_visibility` = 0; `fill_cells` solo en `FloorGenerator`/`RoomManager`; `is_room_visited` solo en `DoorTurnSystem`/`RoomManager`.

## Pendiente (verificar en editor)
1. Sin errores de parseo.
2. Log al iniciar: `validate_graph: OK` y `validate_visibility: OK`; tras abrir cada puerta, otro `validate_visibility: OK` (cualquier warn = divergencia real, o una celda de puerta que solapa una zona oculta).
3. Playtest completo: mover, 4 puertas, energizar, construir, Nexo, extracción, victoria; start room visible al arrancar; re-click en puerta abierta no hace nada.

## Observación no tocada
`open_room` emite `turn_advanced` antes que `room_revealed`: `EnemyManager` puede spawnear en la room recién descubierta un instante antes de presentarla (mismo frame). Reordenar cambiaría gameplay → fuera de M2.

# Goal sesión juego-22 — tests exhaustivos, movilidad y balance

Sesión autónoma de ~3 h sin supervisión en Quest (Godot 4.6.2, GDScript). Objetivo: tests exhaustivos de salas, movilidad de los personajes y balance de héroes/ítems, arreglar lo que salga roto. Trabajá solo, no preguntes nada: si hay dudas, elegí lo más conservador y anotalo.

## 0. Arranque (≤10 min)

- Leé CLAUDE.md, docs/PLAYTEST.md, docs/BALANCE.md, docs/ROOMS.md, docs/PERSONAJES.md, docs/ECONOMIA.md, docs/ENEMY_TARGETING.md y el último bloque de docs/archive/SESSIONS.md.
- Leé el informe https://claude.ai/artifact/SMkXyLGjaawxRk15PfnenM y comparalo con el estado real.
- Git: en session/juego-21 hay un diff en resources/tilesets/dungeon_tileset.tres y props_tileset.tres. Miralo; si es churn de uid/build, commit "chore: tilesets rebake" + push en juego-21 (incluí este archivo, docs/GOAL_juego-22.md). Después creá session/juego-22 desde ahí.
- Línea base: tools/run_tests.sh completo (test_door_roll tarda ~4.5 min, corrélo en background). Anotá fallos y tiempos antes de tocar nada.

## 1. Salas, exhaustivo (~45 min)

Un test nuevo tests/test_salas_exhaustivo.gd (estilo `extends SceneTree` como los demás; sin duplicar lo que ya cubren test_map_generator / test_map_flow / test_room_types* — revisá primero qué existe):

- `MapGenerator.generate_floor` para ≥200 semillas × pisos 1–5: `layout.validate()` ok, todas las salas alcanzables desde START, EXIT existe y no es START, cuotas de `RoomTypeRule` respetadas, corredores de loop sin brasas y sin sala, determinismo (misma semilla = mismo layout).
- Cada RoomType {COMBAT, START, EXIT, REST, LOOT, ELITE, WORKSHOP, PRISONER, ALTAR, SECRET}: abrir la puerta en un Main2d real → recompensa/efecto aplicado una sola vez (`FloorManager.on_room_discovered`), banner/hint, nada se duplica al reabrir/recargar. PRISONER → `PrisonerCage` → `recruit_hero` respeta máximo 4. ELITE/bosses (pisos 3 y 5) bloquean la salida mientras viven.
- Iluminación: costo `LIGHT_COST` + step, apagar reembolsa exactamente lo pagado, la sala inicial es gratis, sin brasas → rechazo sin gasto.
- Obras: construir/demoler/reparar en cada slot; `is_working` respeta `requires_light`; los Talleres producen solo en turno.
- Extracción: las puertas se bloquean, las oleadas por stage, la Reliquia (caída/recogida/destruida = derrota), victoria solo con el portador en la salida, DEAD/VICTORY nunca se pisan.
- Cada bug que aparezca: arreglo de causa raíz + aserción que lo cubra.

## 2. Movilidad de los personajes (~40 min)

Un test nuevo tests/test_movilidad.gd (revisá primero test_corridor_picking, test_downed, test_map_flow y lo que ya mueva héroes; no dupliques). Siempre por el camino real: `PlayerActionController._walk` / `NetCommands.request`, no seteando `current_zone_id` a mano.

- Pathing: `find_zone_path` solo sobre zonas reveladas; destino no revelado o sin camino → rechazo sin moverse; camino por corredores y loops; el héroe pasa por los centros de zona y `enter_zone()` se dispara en cada zona cruzada, en orden, sin saltear ni repetir; `current_zone_id` correcto al llegar.
- Velocidad: tiempo de recorrido ∝ distancia / (base × `move_speed_mult` de cada héroe); el portador de la Reliquia va a ×`carrier_speed_mult`; los bonos de ítems/perks de velocidad, si existen, se aplican y se quitan.
- Órdenes: re-ordenar a mitad de camino cambia de rumbo sin teletransporte ni doble tween; varios héroes seleccionados / grupos de control 1–3 se mueven todos; clic derecho sobre la zona actual = no-op; mover hacia una puerta cerrada no la atraviesa.
- Estados: un héroe caído no se mueve ni recibe órdenes, y revivido vuelve a moverse; pausa táctica (`Engine.time_scale` 0) congela el tween y al despausar sigue; la pausa de menú igual; mover durante la extracción sí se puede, abrir puertas no.
- Interacción con el mundo: varios héroes en la misma zona no se apilan en un solo punto (si hay offsets/slots); los enemigos (anillo de 8 slots, `EnemyMoveAction`) siguen al héroe que cambia de zona; recoger/soltar la Reliquia en `drop_zone_id` con cualquier héroe.
- Co-op: un cliente ENet (`--net=enet`, como test_net_commands) pide un movimiento → el host valida y el cliente ve la posición por snapshot; un movimiento a una zona inválida es rechazado por el host.
- Si sobra tiempo: una captura en ventana real (tests/tools/shot_*.gd o un shot nuevo) de un héroe a mitad de corredor, para revisar que no atraviese paredes.

## 3. Balance de héroes e ítems (~45 min)

- Extendé `BalanceSim` (tools/balance_sim / lo que use test_balance), sin reescribirlo: cada héroe solo y cada party de 2–4, cada dificultad, pisos 1–5, ≥50 corridas por config. Métricas: tasa de victoria por piso, DPS, HP perdido, Comida/Hierro/Saber/Brasas al final de cada piso, turnos hasta la salida.
- Ítems/perks: para cada ítem de resources/items y cada perk, verificá con `get_stat_breakdown` que el efecto se aplica, se apila bien y se quita al desequipar. Señalá ítems sin efecto o dominantes (>15 % mejor que la media de su rareza).
- Ajustes: solo números en `.tres`, máximo ±25 % por valor, sin cambiar mecánicas. Objetivo de referencia: ningún héroe con >10 pp de diferencia de victoria contra la media; piso 1 ganable por cualquier party de 2. Cada cambio con antes → después → motivo en docs/BALANCE.md; actualizá los umbrales de test_balance si corresponde. Las ideas de mecánica van en una sección "Propuestas" (no se implementan).

## 4. Soak de corrida completa (~25 min)

- test_full_run (o un tool en tests/tools/) con bot headless sobre ≥20 semillas, 5 pisos, offline + guardado/continuar entre pisos (test_run_save): sin ERROR/WARNING nuevos (`ErrorProbe`), sin cuelgues, sin fugas de nodos entre pisos. Medí el frame time en el piso con más enemigos (docs/RENDIMIENTO.md).

## 5. Arte (solo si hace falta)

- Si falta un ícono/VFX (docs/MISSING_ICONS.md o algo nuevo de esta sesión): arte propio vía tools/build_own_art.gd + tools/libresprite.sh (LibreSprite en E:/LibreSprite/libresprite.exe), fila nueva en docs/CREDITOS.md, test_licencias en verde. Nunca referenciar `_source` ni packs de licencia desconocida.

## Reglas

- Todo por los caminos del repo: `NetCommands.request`, `Player.take_hit`, `ManagerLocator`, `QuestLogger` (no `print`), `Area2D.input_event`. Si cambian comandos o claves de `RunState` → subir `application/config/version`.
- Texto visible en español medieval (test_vocabulario).
- Diffs mínimos, sin refactors no pedidos, sin dependencias nuevas.
- **Commit + push SIEMPRE juntos con cada actualización del artifact**: actualizar el informe = correr los tests tocados → commit (Conventional, en español) → push a session/juego-22 → recién ahí republicar el artifact con el hash del commit. Hacelo al cerrar cada fase y como mínimo cada ~45 min. Si un test está rojo en ese momento, commiteá igual con `wip:` y anotá el rojo en el informe.
- Sin merge a main, sin force push, sin tocar Steam real. Repo público: nada sin licencia al índice.
- Si algo te traba más de 20 min, anotalo y pasá a lo siguiente.

## Cierre (últimos 15 min)

- tools/run_tests.sh completo en verde (OK* = crash conocido de 4.6.2, no cuenta).
- Bloque de sesión en docs/archive/SESSIONS.md (qué cambió, qué NO se verificó en ventana real), CHANGELOG.md corto para jugadores, docs/BALANCE.md, docs/PLAYTEST.md y docs/PERSONAJES.md (movilidad) al día. CLAUDE.md solo si cambió algo estructural, editado en el lugar y ≤20 KB.
- Mover este archivo a docs/archive/ (ya cumplido) en el commit final.
- Último commit + push, artifact actualizado con ese hash, y al final de la respuesta: el resumen, cuándo conviene /clear y el próximo /goal listo para pegar.

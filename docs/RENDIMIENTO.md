# RENDIMIENTO.md — session/calidad-13

## Método

Banco `tests/tools/bench_floor5.gd` (peor caso de la run):

- Escenario: piso 5, Difícil, 4 héroes (fila de 4 jugadores de `PlayerScaling`), todas las salas reveladas y el tope de enemigos vivos lleno (24, se rellena cada segundo).
- Héroes y Reliquia tienen vida enorme: una derrota pausaría el árbol y la muestra mediría un juego quieto.
- Mide 30 s a 1x y 30 s a 2x tras 3 s de calentamiento:
  - tiempo de frame p50/p95/p99/máx y picos de más de 50 ms;
  - monitores de `Performance` (nodos, draw calls);
  - micro-bench de los helpers calientes, en µs por llamada.
- Ventana real, 1920×1080, GTX 1660 SUPER, GL Compatibility, sin VSync ni tope de FPS:
  `godot --path . --script res://tests/tools/bench_floor5.gd -- <tag>`
- Salida: `docs/perf/<tag>.csv`.
- El headless queda capado a ~120–145 fps y no dibuja: sirve solo para la lógica.

Nota: en la corrida "antes" la primera fase quedó con VSync activo (p50 16,7 ms). Por eso el número que compara es el **p99 y los picos**, no la media de FPS.

## Antes / después (ventana)

| caso | fps medio | p50 ms | p95 ms | p99 ms | máx ms | picos > 50 ms |
|---|---|---|---|---|---|---|
| antes 1x | 59,7 (VSync) | 16,68 | 17,12 | **36,95** | 61,15 | 6 |
| antes 2x | 357,5 | 2,39 | 4,99 | 9,10 | 29,06 | 0 |
| después 1x | 495,0 | 1,82 | 2,82 | **7,64** | 58,27 | 1 |
| después 2x | 515,6 | 1,76 | 2,90 | 5,14 | 15,58 | 0 |

Meta (60 FPS estables, p95 ≤ 16,7 ms): **cumplida** con mucho margen. Queda un pico aislado de 58 ms a 1x, sin explicar (posible carga en frío de un tipo de enemigo).

## Cuello de botella encontrado

`QuestLogger.info()` costaba entre **1 y 10 ms por línea** cuando la salida iba a archivo o pipe (el log a archivo de Godot está activo), y `push_warning()` entre 3 y 27 ms (captura el stack). Se llamaba en cada golpe a un héroe ("Hero took N damage") y en cada muerte o spawn de enemigo. Matar un enemigo costaba ~15 ms en el banco.

Arreglo: esos logs pasan a nivel DEBUG, que está apagado por defecto (`Player.gd`, `Enemy.gd`, `EnemyManager.gd`). Después de eso, matar un enemigo cuesta ~26 µs.

## Micro-bench (µs por llamada, antes del arreglo)

| helper | µs |
|---|---|
| `ManagerLocator.get_room_manager` / `get_relic` | 0,8 |
| `ManagerLocator.get_heroes` | 2,8 |
| `RoomManager.find_zone_path` | 47 |
| `EnemyManager.get_enemies` | 7,4 |
| `NetSync.capture_snapshot` | 50 |
| `FloatingTextManager.spawn_text` | 173 |
| `Projectile` new + add + free | 11 |
| `VfxManager.hit` | 23 |
| `QuestLogger.info` | ~1 000 (a archivo) |
| `Enemy.take_damage` con muerte | 1 100 → 26 después |

## Lo que NO se hizo, y por qué

Lo dejan sin hacer los números, no la falta de tiempo:

- **Caché de grupos en `ManagerLocator`**: menos de 1 µs por llamada; no aporta.
- **Pooling de proyectiles y enemigos**: crear y liberar cuesta 11 µs; el tope es de 24 enemigos.
- **Pooling de `FloatingText`** (173 µs por instancia): candidato si en una pelea masiva aparecen más de ~50 números por frame. Hoy no se ve en el p99.
- **`RoomLight`, `HeroPortrait._process` y señales de cooldown por frame**: no aparecen en el banco.

## Pendiente (prueba manual)

- Co-op real de 4 jugadores (el banco simula 4 héroes en un solo proceso, sin red).
- Hardware más modesto.
- El pico aislado de 58 ms.

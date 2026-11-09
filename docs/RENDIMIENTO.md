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

## Re-medición (session juego-22)

Ventana real, mismo banco (`bench_floor5.gd -- juego22`, `docs/perf/juego22.csv`), piso 5, Difícil, 4 héroes, ~24 enemigos vivos:

| caso | fps medio | p50 ms | p95 ms | p99 ms | máx ms | picos > 50 ms | draw calls |
|---|---|---|---|---|---|---|---|
| calidad-13 después 1x | 495,0 | 1,82 | 2,82 | 7,64 | 58,27 | 1 | 220 |
| juego-22 1x | 394,4 | 2,43 | 2,92 | **3,67** | 35,63 | 0 | 488 |
| juego-22 2x | 378,0 | 2,48 | 3,41 | 5,69 | 21,29 | 0 | 493 |

Meta (p95 ≤ 16,7 ms) cumplida con margen; el p99 y los picos mejoraron. Los draw calls se duplicaron desde calidad-13 (el mapa de juego-21 suma ladrillos gastados y el relleno detrás de las tapas): no pesa hoy, vigilar en hardware modesto.

Soak headless (`tests/tools/soak_runs.gd -- 20`): 20 semillas × 5 pisos con guardar → menú → continuar en cada piso desde el 2, ~46 s por semilla, 0 fallos, sin ERROR/WARNING, sin nodos huérfanos; nodos al empezar el piso 2: media 827 en las primeras 10 semillas y 834 en las últimas 10 (sin fuga; la diferencia son enemigos vivos). El piso con más enemigos fue el 5 (14 vivos): el headless está capado a 120 fps (8,33 ms por frame), así que esa medición solo sirve para la lógica.

## Soak (session juego-23)

`tests/tools/soak_runs.gd -- 20` sobre el código de juego-23 (ítems retocados; el simulador no corre en el juego): 20 semillas × 5 pisos con guardar → menú → continuar desde el piso 2, 0 fallos, sin ERROR/WARNING de juego, 44,9-48,7 s por semilla (media 46,7). Nodos al empezar el piso 2: media 827 en las primeras 10 semillas y 834 en las últimas 10, igual que juego-22 (sin fuga). Al salir, Godot avisa `ObjectDB instances leaked` (ruido conocido del cierre por `--script`).

Frame time en el pico (piso 5, 14 enemigos vivos, 240 frames a time_scale 1): frame medio 8,33 ms, p95 8,61 ms, máx 8,68 ms (el headless está capado a 120 fps: es el tope, no el costo); tiempo de `_process` + física (monitores de Godot, se suman aunque se solapen con el tope) medio 10,79 ms, p95 12,8 ms, máx 12,8 ms; juego-22 no anotó este número, queda como línea base. La medición en ventana real sigue siendo la de juego-22 (no cambió nada del render).


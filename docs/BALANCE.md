# BALANCE.md — estado actual

Números vigentes del balance (al cierre de juego-44). Salen de `tools/BalanceSim.gd` sobre los `.tres` y las fórmulas reales; `tests/test_balance.gd` los convierte en asserts. Historial por sesión (tablas, barridos, «qué pasaría si», decisiones del dueño): `docs/archive/BALANCE_HISTORIA.md`. CSV en `docs/balance/` (`.gdignore`).

```
godot --headless --path . --script res://tests/test_balance.gd                     # objetivos como asserts (~20 s)
godot --headless --path . --script res://tests/tools/sweep.gd -- [corridas] [tag] [play json] [columnas]
godot --headless --path . --script res://tools/balance_sim.gd -- after             # tablas por héroe/enemigo → docs/balance/after_*.csv
```

`sweep.gd`: pares (media de 6), tríos (co-op 3, media de 4) y los 4 (co-op 4), Normal y Difícil; 200 corridas por defecto (~1 min). `tag` escribe `docs/balance/<tag>_runs.csv` (`-` = no). El json acepta las claves de `BOSS_PLAY` más `"towers": false` y `"boss_near": x`. Columnas: `clave@pisos` separadas por coma (por defecto `win_rate@1/2/3/4/5`; p. ej. `win_rate@3/4/5,towers@1/3/5,dmg_by_towers_pct@1/3/5,relic_hp_end@3/5`).

## Victoria por piso (publicado, juego-42; igual en juego-44)

200 corridas, `sweep.gd` con el play por defecto (CSV `docs/balance/juego42_despues_runs.csv`; juego-44 lo repite con 0 puntos de diferencia, `juego44_despues_runs.csv`). % de corridas que ganan el piso 1 / 2 / 3 / 4 / 5:

| Dificultad | Grupo | Victoria 1/2/3/4/5 (%) |
|---|---|---|
| Normal | pares | 100 / 100 / 73 / 68 / 55 |
| Normal | tríos (co-op 3) | 100 / 100 / 100 / 95 / 72 |
| Normal | los 4 (co-op 4) | 100 / 100 / 100 / 100 / 85 |
| Difícil | pares | 100 / 100 / 73 / 63 / 32 |
| Difícil | tríos (co-op 3) | 100 / 100 / 98 / 83 / 30 |
| Difícil | los 4 (co-op 4) | 100 / 100 / 100 / 96 / 34 |

Obras (juego-41): 3-5 por piso; sacan el 17-22 % de la vida enemiga en el piso 1 y el 9-18 % en los pisos 3-5. La Reliquia termina la extracción con 96-100 % de vida.

## Datos que fija `test_balance`

| Dato | Valor | Dónde |
|---|---|---|
| Comida al matar al jefe (pisos 3 y 5) | 15 | `FloorConfig.boss_food_reward` |
| Comida al bajar | +30 desde el piso 4 | `food_bonus_on_descend` / `food_bonus_from_floor` |
| Comida extra al bajar por jugadores (1-4) | 0 / 0 / 10 / 20 | `PlayerScaling.descent_food` |
| Vida del Señor Demonio (piso 5) | 150 | `FloorTheme` del piso 5 |
| Difícil | daño ×1,1, recursos iniciales ×1, jefes sin multiplicadores (`scales_bosses` false) | `DifficultyConfig` |
| Nivel que la Comida no paga | Saber ×2 por cada Comida | `UpgradeConfig.alt_resource` / `alt_cost_mult` |
| Rescate de prisionero | 8 Comida / 10 Hierro / 15 Saber, +5 por piso | `RoomTypeRule.recruit_costs` |
| Cura del retrato | 0,15 Comida por punto | `UpgradeConfig.heal_cost_per_hp` |
| Sala de Descanso | 2 de vida/s, gratis; no con enemigos dentro ni en la extracción | `heal_per_tick`, `heal_food_per_tick` 0 |
| Vida de la Reliquia | 120 | `FloorConfig.relic_max_hp` |

## Umbrales de `test_balance` (50 corridas)

- **Combate base:** enemigo del piso 1 muere en 2-4 golpes (todo héroe × todo tipo); oleada del piso 1 quita ≤ 33,4 % de la vida; salto entre pisos ≤ 20 puntos y piso 5 ≤ 70 % de vida perdida; Reliquia: 1 saqueador la rompe en 15-45 s, 3 en ≥ 6 s; rompe-torres quitan 30-99,9 % a una Defensa sin ganarle; ningún héroe domina a otro (vida efectiva, DPS, rango) a nivel 0 y 5; roles de heroes-9 (Paladín aguanta más, Pícaro más frágil y más DPS).
- **Economía:** cada recurso tiene ingreso y gasto por piso; `run_ratio` final en [0,2; 3,0].
- **Escalado co-op:** paridad por héroe dentro de `[PARITY_MIN, PARITY_MAX]` de `BalanceSim`; el tope de enemigos crece con el grupo.
- **Corridas:** todo par gana el piso 1 ≥ 90 %; ningún héroe se aparta > 10 puntos de la media (grupos de 2-4); Difícil nunca gana más que Normal (pares).
  - Normal pares: pisos 3 / 4 / 5 ≥ 62 / 55 / 38 %, piso 3 ≤ 85 %; del que llega al 4 gana ≥ 50 %, al 5 ≥ 30 %.
  - Normal los 4 (co-op 4): piso 4 ≥ 60 %, piso 5 ≤ 90 %.
  - Difícil pares: piso 3 ≥ 55 %, piso 4 entre 40 y 70 %, piso 5 ≤ 35 %.
- **Obras (`_check_run_towers`, `_check_obras_model`):** con torres hay ≥ 1 en el piso 1 y sin torres 0; el jefe junto a las Obras gana > 20 puntos más que a oscuras (Normal y Difícil); las Obras sacan > 5 % del daño; vida de la Reliquia al final en (0, 1]; Ballesta a oscuras no tira, Catapulta crece con la oleada hasta `SPLASH_HITS`, Pinchos a oscuras sí, segundo precio de `BuildingCostCurve`, cura gratis con 0 de Comida llena la vida.
- **Jefe (`_check_boss_play`, Guerrero + Paladín, Difícil, junto a las Obras):** jefe antes de la extracción llega con más vida; curarse con Comida antes ≥ 0,8 de vida; esquivar todo gana más.
- **Rescate e Investigación (`_check_recruits`):** rescatar hasta 2 da > 2,3 héroes en el piso 3 y no pierde; pagar niveles con Saber no pierde; el «qué pasaría si» `research` compra > 4 entradas y deja menos Saber; por defecto se compra solo la Ballesta.

## Supuestos del jugador de referencia (`BalanceSim.BOSS_PLAY`)

Todos sin datos de gente; son lo primero a revisar con un playtest.

| Clave | Por defecto | Qué supone |
|---|---|---|
| `dodge` / `dodge_sec` | 0,5 / 2 s | sale de la mitad de las Embestidas del jefe; 2 s sin contacto por esquive (calibrado con `shot_jefe.gd esquiva`) |
| `heal` + `rest_first` | `"comida"` + true | antes del jefe y de la extracción descansa gratis si se reveló una sala de Descanso y después cura con el retrato lo que falte; no modela el tiempo de ir a la sala |
| `boss_first` | true | el jefe despierta al revelar la salida y se pelea antes de las oleadas de extracción |
| `items` | true | cofres, Altares y premio de fin de piso dan equipo (stream de RNG propio) |
| `research` / `lab_first` | [] / true | solo se investiga la Ballesta; `RESEARCH_ORDER` es el orden de un jugador si se pide |
| `level_lore` | −1 | niveles en Saber ×2 cuando falta Comida (`UpgradeConfig`) |
| `BOSS_NEAR_TOWERS` | 0,5 | la mitad de las veces lleva al jefe a la sala mejor defendida (lejos 52 %, cerca 90 % en Normal pares piso 3) |
| `SPLASH_HITS` | 3 | la Catapulta pega a hasta 3 enemigos |
| `ALTAR_KEEP_HP` | 0,5 | usa un Altar si el héroe más sano conserva la mitad de la vida |
| `relic_left` | 0 | chance por piso de que la Reliquia quede sola en la sala inicial mientras se explora: los saqueadores de cada oleada de puerta van a ella (`_raid_relic`), solo los frenan las Obras de esa sala y nadie vuelve a ayudar |

Obras: Defensa en la sala de la Reliquia y en cada sala que enciende; tras el jefe, Defensa (encendida) o Pinchos (a oscuras) en cada sala del camino a la salida. «Qué pasaría si» apagados por defecto: `free_food`, `no_doors`, `no_extr`, `no_boss`, `free_levels`, `players`, `extra_food*`, `recruit*`, `full_hp`.

## Reliquia sola durante la exploración (juego-44)

`sweep.gd -- 200 '{"relic_left": x}'`. Victoria por piso (%), `die_relic` (% de los que juegan el piso) y vida de la Reliquia al final:

| relic_left | Grupo | Victoria 1/2/3 | Victoria 3/4/5 | die_relic 3/5 | Reliquia 3/5 |
|---|---|---|---|---|---|
| 0 (publicado) | Normal pares | 100 / 100 / 73 | 73 / 68 / 55 | 0 / 0 | 1,0 / 1,0 |
| 0,5 | Normal pares | 61 / 34 / 14 | 14 / 6 / 3 | 43 / 46 | 0,6 / 0,5 |
| 0,5 | Normal los 4 | 55 / 31 / 14 | 14 / 7 / 4 | 56 / 43 | 0,4 / 0,6 |
| 0,5 | Difícil pares | 58 / 32 / 13 | 13 / 6 / 2 | 44 / 46 | 0,6 / 0,5 |
| 1 | Normal pares | 24 / 4 / 0 | 0 / 0 / 0 | 92 / 17 | 0,1 / 0,0 |
| 1 | Difícil pares | 16 / 2 / 0 | 0 / 0 / 0 | 100 / 0 | 0,0 / 0,0 |

Lectura: con la Reliquia sola, una oleada de puerta con un saqueador la rompe casi siempre en los pisos 1-2, porque todavía no hay Ballesta investigada y la sala inicial no tiene Defensa. Con dos Ballestas encendidas en la sala no la toca (`test_balance`). Es la cota pesimista: nadie vuelve a defenderla. El juego real depende de que el grupo vuelva a tiempo (1 saqueador tarda 15-45 s). Las tablas publicadas (`relic_left` 0) suponen que el grupo siempre la defiende. Falta medir en un playtest cuánto tarda en volver; el modelo no tiene ese tiempo.

## Catapulta (juego-44)

`sweep.gd -- 200 '{"research": ["catapulta"]}'` (la Catapulta reemplaza a la Ballesta en cada sala). Victoria 3/4/5 (%):

| Datos | Normal pares | Normal los 4 | Difícil pares | Difícil los 4 |
|---|---|---|---|---|
| Ballesta sola (sin investigar Catapulta) | 73 / 68 / 55 | 100 / 100 / 85 | 73 / 63 / 32 | 100 / 96 / 34 |
| Catapulta vieja (8 Hierro, 18 Saber, 25 daño) | 65 / 58 / 42 | 100 / 100 / 81 | 63 / 50 / 22 | 100 / 92 / 32 |
| A: 5 Hierro | 67 / 59 / 44 | 100 / 100 / 84 | 64 / 52 / 24 | 100 / 94 / 36 |
| B: 10 Saber | 68 / 60 / 44 | 100 / 100 / 82 | 66 / 53 / 22 | 100 / 92 / 32 |
| C: 35 daño | 65 / 59 / 44 | 100 / 100 / 83 | 63 / 52 / 24 | 100 / 93 / 36 |
| **A+B+C (aplicado)** | 69 / 64 / 50 | 100 / 100 / 88 | 68 / 58 / 29 | 100 / 95 / 44 |

El dueño eligió A+B+C (versión 1.11). En pares sigue 4-5 puntos debajo de la Ballesta: el Saber y el Scriptorium que pide la investigación pesan más que el daño. En co-op 3-4 y en Difícil los 4 ya la supera.

## Abierto

- **No modelado:** el tiempo que tarda el grupo en volver a la Reliquia (`relic_left` es la cota sin nadie que vuelva); enemigos más fuertes de las salas Élite; el Brasero; rompe-torres que tiran Obras; el tiempo de volver a la sala de Descanso.
- **Catapulta:** −4/−5 en pares tras juego-44; el costo que queda es la investigación (Saber + Scriptorium).
- **Playtest:** si un jugador lleva al jefe a sus Defensas la mitad de las veces, esquiva la mitad de las Embestidas y vuelve a descansar antes del jefe.

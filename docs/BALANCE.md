# BALANCE.md — session/balance-4

Balance de héroes, enemigos, pisos y Reliquia con **evidencia reproducible**. Todos los números salen del
simulador (`tools/BalanceSim.gd`, CLI `tools/balance_sim.gd`) sobre los `.tres` reales y
las fórmulas reales (`Enemy.resolved_*`, multiplicadores de `FloorConfig`, curvas de `UpgradeConfig`).
Los CSV viven en `docs/balance/{before,after}_*.csv` (`docs/balance/.gdignore`: Godot no los importa).
"Antes" = los `.tres` de `session/enemies-2` pasados por el mismo modelo.

```
godot --headless --path . --script res://tools/balance_sim.gd -- after    # regenera docs/balance/after_*.csv
godot --headless --path . --script res://tests/test_balance.gd            # objetivos como asserts
```

## Objetivos (y por qué)

| # | Objetivo | Umbral en `tests/test_balance.gd` | Justificación |
|---|---|---|---|
| 1 | Un enemigo básico del piso 1 muere en 2-4 golpes | cada héroe × cada tipo del piso 1: 2 ≤ golpes ≤ 4 | 1 golpe no da sensación de combate; más de 4 con ~1 s de intervalo es esperar |
| 2 | Un encuentro básico (oleada del piso 1) quita ≤ 1/3 de la vida del héroe | ≤ 33,4 % | deja margen para 2 encuentros seguidos + curación de salas Rest |
| 3 | Dificultad creciente sin saltos bruscos hasta el piso 5 | salto entre pisos ≤ 20 puntos, piso 5 ≤ 70 %, la media sube del piso 1 al 5 | el piso 5 debe exigir torres + 2 héroes, no ser inviable en solitario |
| 4 | La Reliquia da tiempo de reaccionar pero cae si se ignora | 1 saqueador lo destruye en 15-45 s; 3 en ≥ 6 s | alerta (borde rojo) + ~1,4 s por sala para llegar = ventana de reacción |
| 5 | Roles distintos, ninguno estrictamente mejor | ningún héroe ≥ en (vida efectiva, DPS, rango) y > en alguno, a nivel 0 y 5 | cada uno gana en un eje y pierde en otro |

## Modelo (qué mide el simulador)

- El AoE del héroe golpea a todo enemigo en rango cada `interval`. Timer libre: el primer golpe cae en un punto
  uniforme del intervalo, así que el enemigo está expuesto `(golpes − 0,5) × intervalo` en promedio.
- El enemigo golpea por contacto cada 1,0 s (`Enemy.CONTACT_HIT_INTERVAL`). El daño es la esperanza (sin redondear a ticks).
- *Encuentro* = la oleada de invasión del piso en el turno 5 (`1 + ⌊5/5⌋ + extra_por_piso`: antes 2, 2, 3, 3, 4 enemigos; ahora 2, 2, 2, 3, 3),
  todos a la vez en rango; se promedia por el peso del pool del piso. Un héroe, sin torres ni segundo héroe (peor caso).
- Nivel del héroe en el piso *f* = *f* − 1 (un nivel comprado por piso; el máximo de la run es 5).
- Saqueador → Reliquia: llegada = camino de salas hasta la sala inicial (30 semillas × `MapGenerator`) / velocidad, solo desde
  salas donde puede aparecer (≥ `raider_min_arrival_sec`); destrucción = `⌈vida_relic / daño⌉ × 1 s`.
- Pasivas incluidas: solo las siempre activas (Piel de Hierro −20 %). Muro Viviente (solo cerca de la Reliquia) no cuenta: conservador.
  Las activas se reportan aparte (`active_dps`, `active_ehp`: promedio con el uptime duración/enfriamiento).

## Héroes (nivel 0)

| Héroe | Rol | Vida | Daño | Intervalo | DPS | Rango | Vida efectiva |
|---|---|---|---|---|---|---|---|
| Guerrero | Bruiser: pega fuerte y lento, aguanta con Piel de Hierro | 22 → **26** | 3 → **4** | 1.0 → **1.2** | 3.0 → **3.33** | 160 → **150** | 22.0 → **32.5** |
| Mago | Alcance largo, frágil; economía (Saber) | 20 → **18** | 3 → **3** | 1.0 → **0.9** | 3.0 → **3.33** | 160 → **220** | 20.0 → **18.0** |
| Pícaro | DPS rápido de golpes chicos, corto alcance; economía (Brasas) | 20 → **18** | 3 → **2** | 1.0 → **0.5** | 3.0 → **4.0** | 160 → **130** | 20.0 → **18.0** |
| Paladín | Mucha vida, poco DPS; protege al grupo y a la Reliquia | 32 → **40** | 3 → **3** | 1.0 → **1.3** | 3.0 → **2.31** | 160 → **170** | 32.0 → **40.0** |

Nivel 5 (todas las mejoras; `hp +4`, `daño +1`, `intervalo −5 %` por nivel, mínimo 0,3 s — antes −10 % y mínimo 0,2 s):

| Héroe | Vida | DPS | DPS con activa | Vida efectiva | Vida efectiva con activa |
|---|---|---|---|---|---|
| Guerrero | 42 → **46** | 16.0 → **10.0** | 11.6 | 42.0 → **57.5** | 57.5 |
| Mago | 40 → **38** | 16.0 → **11.85** | 11.85 | 40.0 → **38.0** | 38.0 |
| Pícaro | 40 → **38** | 16.0 → **18.67** | 20.42 | 40.0 → **38.0** | 38.0 |
| Paladín | 52 → **60** | 16.0 → **8.21** | 8.21 | 52.0 → **60.0** | 66.67 |

Habilidades (números en `resources/abilities/*.tres`; la tecla **Q** lanza la activa de los héroes seleccionados):

| Héroe | Pasiva | Activa (duración / enfriamiento) |
|---|---|---|
| Guerrero | Piel de Hierro: −20 % de daño recibido | Grito de Guerra: aliados en su sala +50 % de daño (8 s / 25 s) |
| Mago | Mente Analítica: +2 Saber al descubrir una sala | Bendición de las Obras: torres de su sala ×2 de daño (8 s) y talleres pagan 1 turno extra (30 s) |
| Pícaro | Paso Ligero: +2 Brasas al descubrir una sala | Golpe Furtivo: ×3 de daño a todo enemigo en rango (12 s) |
| Paladín | Muro Viviente: hasta −50 % de daño cerca de la Reliquia (0 a 640 px) | Interposición: todo el grupo recibe −50 % (6 s / 30 s) |

## Piso 1: golpes para matar (nivel 0)

| Enemigo | HP | Guerrero | Mago | Pícaro | Paladín |
|---|---|---|---|---|---|
| goblin | 6 → **6** | 2 → **2** | 2 → **2** | 2 → **3** | 2 → **2** |
| skelet | 7 → **6** | 3 → **2** | 3 → **2** | 3 → **3** | 3 → **2** |
| tiny_zombie | 9 → **8** | 3 → **2** | 3 → **3** | 3 → **4** | 3 → **3** |

## Enemigos por piso (vida / daño de contacto con los multiplicadores de piso ya aplicados)

Crecimiento por piso: vida `+25 % → +15 %`, daño `+20 % → +10 %` (`default_floor_config.tres`). Los multiplicadores de los tipos
duros se comprimieron (HP ×`1+(m−1)·0,6`, daño ×`1+(m−1)·0,4`) y los pools de los pisos 4-5 pesan menos a los más duros.
Antes → después; "—" = el tipo no estaba en el pool de ese piso.

| Piso | Enemigo | Rol | HP | Contacto |
|---|---|---|---|---|
| 1 | goblin | saqueador | 6 → **6** | 2 → **2** |
| 1 | skelet | cazador | 7 → **6** | 2 → **2** |
| 1 | tiny_zombie | cazador | 9 → **8** | 1 → **1** |
| 2 | goblin | saqueador | 8 → **7** | 2 → **2** |
| 2 | skelet | cazador | 9 → **7** | 2 → **2** |
| 2 | tiny_zombie | cazador | 11 → **9** | 1 → **1** |
| 2 | imp | cazador | 6 → **6** | 3 → **2** |
| 2 | masked_orc | saqueador | 11 → **9** | 3 → **2** |
| 2 | tc_eyeball | cazador | 10 → **9** | 4 → **3** |
| 3 | skelet | cazador | 11 → **8** | 3 → **2** |
| 3 | imp | cazador | 7 → **7** | 3 → **2** |
| 3 | masked_orc | saqueador | 14 → **10** | 3 → **3** |
| 3 | orc_warrior | saqueador | 14 → **11** | 4 → **3** |
| 3 | orc_shaman | cazador | 12 → **10** | 6 → **4** |
| 3 | tc_wolf | cazador | 11 → **9** | 3 → **3** |
| 3 | tc_fire_skull | cazador | 15 → **13** | 2 → **1** |
| 4 | masked_orc | saqueador | 16 → **11** | 4 → **3** |
| 4 | orc_warrior | saqueador | 17 → **12** | 4 → **3** |
| 4 | chort | cazador | 19 → **13** | 4 → **3** |
| 4 | wogol | cazador | 21 → **15** | 7 → **5** |
| 4 | big_zombie | cazador | 53 → **32** | 2 → **2** |
| 4 | tc_ogre | cazador | 39 → **25** | 3 → **2** |
| 4 | tc_red_imp | cazador | 13 → **10** | 5 → **3** |
| 4 | tc_wolf | cazador | 13 → **10** | 4 → **3** |
| 5 | chort | cazador | 22 → **14** | 5 → **3** |
| 5 | orc_warrior | saqueador | 19 → **13** | 5 → **3** |
| 5 | ogre | cazador | 70 → **40** | 3 → **2** |
| 5 | big_demon | cazador | 48 → **28** | 11 → **6** |
| 5 | necromancer | cazador | 29 → **19** | 11 → **6** |
| 5 | tc_dragon | cazador | 40 → **24** | 11 → **6** |
| 5 | tc_demon | cazador | 24 → **15** | 6 → **4** |
| 5 | tc_ogre | cazador | 44 → **28** | 3 → **2** |

## Encuentro: % de la vida del héroe perdida (oleada del piso, un héroe, sin torres)

| Héroe | Piso 1 | Piso 2 | Piso 3 | Piso 4 | Piso 5 |
|---|---|---|---|---|---|
| Guerrero | 33.1 → **25.2** | 34.6 → **21.2** | 65.4 → **19.8** | 88.3 → **31.8** | 219.6 → **47.1** |
| Mago | 36.4 → **29.1** | 37.5 → **28.6** | 70.1 → **28.8** | 93.8 → **46.3** | 231.8 → **61.6** |
| Pícaro | 36.4 → **26.3** | 37.5 → **19.0** | 70.1 → **21.7** | 93.8 → **30.5** | 231.8 → **42.5** |
| Paladín | 22.7 → **18.9** | 25.0 → **20.7** | 49.1 → **22.5** | 68.2 → **38.6** | 173.8 → **54.0** |

## Reliquia: saqueadores (vida de la Reliquia 100 → **120**)

| Piso | Saqueador | Daño/s | Llegada mín. (s) | Llegada media (s) | Destruye 1 (s) | Destruye 3 (s) |
|---|---|---|---|---|---|---|
| 1 | goblin | 4 → **4** | 4.6 | 5.8 | 25.0 → **30.0** | 9.0 → **10.0** |
| 2 | goblin | 5 → **4** | 4.6 | 6.1 | 20.0 → **30.0** | 7.0 → **10.0** |
| 2 | masked_orc | 6 → **5** | 5.1 | 6.8 | 17.0 → **24.0** | 6.0 → **8.0** |
| 3 | masked_orc | 7 → **5** | 5.1 | 6.3 | 15.0 → **24.0** | 5.0 → **8.0** |
| 3 | orc_warrior | 7 → **5** | 4.9 | 6.0 | 15.0 → **24.0** | 5.0 → **8.0** |
| 4 | masked_orc | 8 → **6** | 5.1 | 6.5 | 13.0 → **20.0** | 5.0 → **7.0** |
| 4 | orc_warrior | 8 → **6** | 4.9 | 6.1 | 13.0 → **20.0** | 5.0 → **7.0** |
| 5 | orc_warrior | 9 → **6** | 4.9 | 6.1 | 12.0 → **20.0** | 4.0 → **7.0** |

## Qué se tocó (solo datos salvo lo indicado)

- `resources/characters/*.tres`: `base_hp`, `attack_damage`, `attack_interval`, `attack_range` (campo nuevo: radio del AoE), `passive`/`active`, `vfx_color`.
- `resources/enemies/*.tres`: `hp_mult` / `damage_mult` comprimidos. Campos nuevos en `EnemyType` (`base_hp`, `base_speed`, `contact_damage`,
  `building_damage`; −1 = el valor del comportamiento en `Enemy.VARIANT_CONFIG`): permiten afinar sin tocar código, hoy sin usar.
- `resources/floors/default_floor_config.tres`: `enemy_hp_growth` 0,25 → 0,15; `enemy_damage_growth` 0,2 → 0,1; `extra_invasion_enemies_per_floor` 0,5 → 0,34; `relic_max_hp` 100 → 120.
- `resources/floors/enemy_pool_f4/f5.tres`: pesos de los tipos duros bajados.
- `resources/upgrades/run_upgrade_config.tres`: `attack_speed_per_level` 0,10 → 0,05, `min_attack_interval` 0,2 → 0,3 (el Pícaro, con intervalo 0,5, escalaba sin techo).
- Código mínimo para que "solo `.tres`" sea cierto: `DefenseBuilding` lee daño/cadencia de `Building.CATALOG` (antes el catálogo solo era texto y divergía del export),
  la ralentización de la trampa lee `slow_factor` del catálogo (antes 0,5 fijo).
- `tools/build_characters.gd`: tablas sincronizadas (re-ejecutarlo pisa los `.tres` de enemigos: no hornea roles ni campos base).

## Pendiente de playtest

- El modelo es un héroe solo sin torres; en partida hay 2 héroes, torres, trampas, salas Rest y curación: la dificultad real será menor. Confirmar que el piso 5 sigue siendo tenso.
- **Pícaro a nivel alto**: 18,7 DPS a nivel 5 frente a 8-12 de los demás (daño plano +1 por nivel sobre base 2). Si domina, bajar `damage_per_level` o subir su `attack_interval` base.
- Saqueadores: la ventana de reacción depende del mapa (llegada mínima ~4,6-5,1 s); revisar con partidas reales si 20-30 s para destruir la Reliquia alcanzan para volver.
- Muro Viviente solo actúa cerca de la Reliquia: comprobar que se siente (no entra en la simulación).
- Tres saqueadores del piso 5 destruyen la Reliquia en 7 s: comprobar que no es injusto sin torres cerca.
- La sala Elite (×1,5 vida, ×1,25 daño) no está en el simulador.

## Perfiles de objetivo (session impl-6)
`TargetProfile` reparte los 20 enemigos en 5 perfiles (ver `docs/ENEMY_TARGETING.md`). Línea base `docs/balance/impl6_before_*.csv`; tras 3A (refactor puro) los 4 CSV son **idénticos** (`Get-FileHash`); tras 3B (`impl6_after_3b_*.csv`) los 4 siguen idénticos y se añade `towers`.

Nuevo modelo `BalanceSim.tower_rows()`: rompe-torres contra **una** ballesta 1v1 (15 PV, 15 de daño por s). La ballesta mata al enemigo en `⌈vida/15⌉ s`; el enemigo la destruye en `⌈15/daño_módulo⌉ s`. `defense_hp_lost_pct` = parte de la ballesta que pierde antes de morir. Objetivo (`tests/test_balance.gd`): **30 – 99,9 %** (hace daño real, pero la torre gana el 1v1).

| Piso | Enemigo | `building_damage` | Antes | Después |
|---|---|---|---|---|
| 3 | tc_fire_skull | −1 (3 del behavior Sapper) → **5** | 25 % | **33,3 %** |
| 5 | big_demon | −1 (2 del behavior Hunter) → **3** | 50 % | **66,7 %** |

Intento descartado: `big_demon` con `building_damage` 4 daba 100 % (la torre moría a la vez que el enemigo).
Asesinos: sin cambios de números; la tabla de encuentros (un héroe recibe toda la oleada) ya cubre el caso "todos contra el más débil". Pendiente de playtest: presión sobre el portador durante la extracción (la oleada de 5 s con asesinos rápidos persiguiendo al portador a 75 % de velocidad).

## Tope de vida 60 → 120 (session impl-6, fase 2A)
`StatBalance.PLAYER_MAX_HP` pasa de 60 a 120 para que las armaduras (+20…+30) y los perks de vida no queden anulados por el recorte. BalanceSim (`impl6_after_cap_*`, regenerado y comparado con `impl6_before_*` con `Get-FileHash`): los 4 CSV son **idénticos**, porque el simulador calcula `base_hp + hp_por_nivel × nivel` sin recorte y ningún héroe supera 60 por niveles (Paladín: 40 + 5 × 4 = 60, justo en el tope viejo). El cambio solo se nota en partida cuando se suman perks/equipo: Paladín + Coraza (+6) pasaba de 66 → recortado a 60; ahora llega a 66. Sin impacto en `test_balance`.

## Bucle de puertas, luz y extracción (session bucle-7)
Nuevos datos: `DoorRollConfig` (`resources/floors/door_roll_config.tres`), `FloorConfig` "Enemy cap" (6/8/10/12/14), `light_cost_step` 2, `carrier_speed_mult` 0,85 y las etapas de extracción (4 etapas de 20 s). Corrida: `godot --headless --path . --script res://tools/balance_sim.gd -- bucle7` (una pasada da los 5 pisos). Las 5 tablas de combate (`heroes`, `duels`, `encounters`, `relic`, `towers`) salen **idénticas** a `impl6_after_3b_*` (`Get-FileHash`: el balance de combate no cambió), así que solo se guardan `bucle7_doors.csv` y `bucle7_extraction.csv`.

Modelo `BalanceSim.door_rows()`: se abren las `salas − 1` puertas de cada piso. `threats` = suma de `threat_chance(n, piso)` (puertas con amenaza esperadas); `enemies` = suma de `chance × min(enemy_count, tope)`; `lit_rooms` = salas que se pueden encender con 20 de Brasas iniciales + el Brasas de las puertas y el costo creciente (10 + 2 por sala ya encendida).

| Piso | Salas | Chance puerta 1 / 5 / última | Amenazas | Enemigos | Tope | Brasas | Extra por puerta | Salas encendibles |
|---|---|---|---|---|---|---|---|---|
| 1 | 8 | 0,16 / 0,40 / 0,52 | 2,4 | 3,8 | 6 | 28 | 2 | 3 |
| 2 | 9 | 0,21 / 0,45 / 0,63 | 3,4 | 5,5 | 8 | 32 | 2 | 4 |
| 3 | 10 | 0,26 / 0,50 / 0,74 | 4,5 | 7,6 | 10 | 45 | 3 | 4 |
| 4 | 11 | 0,31 / 0,55 / 0,85 | 5,8 | 16,6 | 12 | 50 | 3 | 5 |
| 5 | 12 | 0,36 / 0,60 / 0,85 | 7,1 | 21,2 | 14 | 66 | 4 | 5 |

Lectura: la probabilidad crece con cada puerta y el piso 1 es tranquilo (2,4 amenazas en 7 puertas); a partir del piso 4 las últimas puertas llegan al máximo (0,85). Un piso enciende 3-5 salas de 8-12 (la intención de session 7: iluminar algunas, no todas). El tamaño de oleada por puerta no cambió respecto de la fórmula anterior en el punto de referencia del simulador (turno 5: 2 enemigos en el piso 1), por eso `encounters` no se movió.

`extraction_rows()` (extracción, por piso y etapa; `enemies_per_min` = `oleada × 60 / pausa`): en el piso 1 pasa de 12 a 68,6 enemigos/min entre la etapa 0 y la 3; en el piso 5 de 20 a 120 (la pausa baja hasta el mínimo de 2 s). El tope de enemigos vivos (6-14) es lo que evita acumulación: la presión real depende de cuánto tardan los héroes en matarlos.

Cambios de valores respecto del bucle anterior: la base plana por puerta (Hierro 2, Comida 2, Saber 1) pasa a 0 y se reemplaza por Brasas (4 + 0,5/piso) + un recurso al azar ponderado por piso (2 + 0,5/piso). `FloorConfig.embers_per_discovery*` se movió a `DoorRollConfig` (mismo valor). La amenaza por puerta ya no depende de las salas oscuras ni del turno global: `0,10 + 0,06 × puertas + 0,05 × (piso − 1)`, tope 0,85 (antes `0,05 + 0,08 × oscuras + 0,015 × turno + 0,05 × (piso − 1)`). Cantidad: `1 + puertas / 5 + ⌊0,34 × (piso − 1)⌋` (antes `1 + turno / 5 + ⌊0,34 × (piso − 1)⌋`; con `0,34` por el override del `.tres`).

Pendiente de playtest: que la curva de amenaza no resulte demasiado suave al principio ni demasiado dura desde el piso 4; que 3-5 salas encendibles alcancen para proteger el camino a la Reliquia; que el tope por piso no deje las oleadas de extracción tan cortas que se vuelvan triviales (etapa 3 pide 4 enemigos cada 2-3,5 s contra un tope de 6-14).

## Economía, obras e Investigación (session economia-8)
Datos nuevos: `resources/buildings/*.tres` (`BuildingDef`: Forja/Granja/Scriptorium 6, Ballesta 4, Brasero 3, Catapulta 8, Pinchos 3), `building_cost_curve.tres` (`step` 0,25, reembolso 50 %, reparación 0,5 × base), `UpgradeConfig.heal_cost_per_hp` 0,15 Comida, investigación de obras (Ballesta 8, Brasero 6, Catapulta 18). Corrida: `godot --headless --path . --script res://tools/balance_sim.gd -- economia8` (tabla `economy`, `docs/balance/economia8_economy.csv`; las otras 7 tablas se regeneran con el mismo tag). Los stats de la Ballesta no cambiaron, así que `towers` sigue en rango (`test_balance`).

Modelo `BalanceSim.economy_rows()` (jugador de referencia): cada sala encendida (+ la inicial) pone su mayor repartido entre Forja/Granja/Scriptorium y 2 menores entre Ballesta/Pinchos, comprados con el costo creciente; los mayores trabajan la mitad de las puertas del piso; investigación completa y niveles repartidos parejo en los 5 pisos; Comida cura a 2 héroes 30 HP por piso; Brasas energiza las salas encendibles. `run_ratio` = ingreso acumulado / gasto acumulado (> 1 sobra, < 1 falta).

| Recurso | Ingreso piso 1 → 5 | Gasto planificable piso 1 → 5 | run_ratio al final | Lectura |
|---|---|---|---|---|
| Hierro | 36 → 46 | 86 → 120 | 0,33 | Falta: no se construye todo, se elige (intencional) |
| Comida | 34 → 46 | 45 | 0,77 | Niveles + curas absorben casi todo |
| Saber | 26 → 52 | 23 | 1,57 | Sobra algo al final, ver abajo |
| Brasas | 48 → 66 | 36 → 70 | 0,86 | Equilibrado |

`test_balance._check_economy`: todo recurso con ingreso > 0 y gasto > 0 en cada piso, y `run_ratio` final dentro de [0,2; 3,0] (ninguno inútil ni acumulándose sin límite). Hierro tiene sumidero tardío real (el costo crece con lo ya construido y las reparaciones no están en el modelo); Comida ganó la cura. Saber sigue siendo un árbol finito (97 − 14 + 32 = 115 con la nueva Catapulta y sin `lore_workshop`): el excedente del piso 4-5 (~1,4-1,6) es la deuda ya anotada en `docs/INVESTIGACION_AUDITORIA.md` I-09; se acepta mientras no haya un tier 3 de investigación (el campo `tier` ya admite 1-3).

Pendiente de playtest: que el costo creciente (+25 % de la base por obra) no frene tanto la Hierro que el jugador nunca llegue al segundo Brasero/Ballesta; que 8 de Saber por Ballesta + exigir un Scriptorium (6 Hierro) no trabe el inicio con 15 Hierro; valor real de `heal_cost_per_hp`.

## Héroes vs enemigos: objetivo único (session heroes-9)
Corrida: `godot --headless --path . --script res://tools/balance_sim.gd -- heroes9_after` (tablas `matchups`, `encounters`, `heroes`... en `docs/balance/heroes9_after_*.csv`).

**Cambio de modelo.** El héroe ya no golpea a todo lo que está en su radio: golpea solo al enemigo **más cercano** (`HitboxComponent.single_target`), y el Mago dispara un `Projectile` (el daño entra al impactar). `BalanceSim.encounter_loss` pasó de "la oleada entera muere junta por AoE" a "la oleada se reparte entre los 2 héroes del grupo inicial (`PARTY_SIZE`) y cada uno mata a los suyos de a uno". El enemigo `i` queda vivo `(golpes − 0,5 + i × golpes) × intervalo`. Un héroe a distancia descuenta el tiempo de aproximación `(alcance − 40) / velocidad del enemigo`. Medido con el modelo viejo de "un héroe solo contra toda la oleada", el objetivo único daba 42 % de vida perdida en el piso 1 y más de 100 % en el piso 5. Con el reparto queda dentro de los objetivos de siempre (≤ 33,4 % en el piso 1, ≤ 70 % en el piso 5, saltos ≤ 20 puntos).

**Roles (nuevo, `test_balance._check_hero_roles`, en cada piso 1-5, nivel = piso − 1).** El Paladín tiene el mayor TTD (tiempo hasta caer contra 1 enemigo medio del pool) y el TTK más lento. El Pícaro tiene la menor vida, el mayor DPS y la mayor velocidad.

| Piso | Guerrero TTK / TTD | Mago TTK / TTD | Pícaro TTK / TTD · vida | Paladín TTK / TTD · vida |
|---|---|---|---|---|
| 1 | 2,40 s / 14,3 s | 1,96 / 9,9 | 1,59 / 8,8 · 16 | 2,84 / 22,0 · 40 |
| 2 | 2,28 / 16,2 | 2,08 / 11,4 | 1,32 / 10,4 · 20 | 3,00 / 24,9 · 48 |
| 3 | 2,29 / 17,0 | 1,86 / 9,8 | 1,30 / 9,1 · 24 | 2,68 / 21,2 · 56 |
| 4 | 2,38 / 18,0 | 2,00 / 10,0 | 1,28 / 9,3 · 28 | 2,89 / 21,3 · 64 |
| 5 | 2,82 / 15,0 | 2,40 / 9,6 | 1,63 / 9,1 · 32 | 3,47 / 20,4 · 72 |

Velocidad de movimiento (`CharacterData.move_speed_mult` × 420 px/s): Pícaro 504, Guerrero y Mago 420, Paladín 378.

**Ajustes.**
- **Paladín**: curva propia `resources/upgrades/tank_upgrade_config.tres` (`CharacterData.upgrade_override`, que ya existía): **+8 de vida por nivel** (la global da +4). Sin esto, el Guerrero lo superaba en TTD desde el piso 3: su −20 % siempre activo crece con la vida de cada nivel, mientras que el −50 % del Paladín solo cuenta junto a la Reliquia y el modelo no lo incluye. El daño y el intervalo por nivel son los globales, así que sigue siendo el que más tarda en matar.
- **Pícaro**: vida base **18 → 16**, para que sea el más frágil sin empatar con el Mago.
- **Mago**: `attack_style` RANGED (dispara; la aproximación le ahorra golpes).
- **Pícaro / Paladín**: velocidad ×1,2 / ×0,9 (antes no había velocidad por héroe).

Lo que no se tocó: el daño, el intervalo y el alcance de los cuatro; los enemigos; los umbrales de `test_balance`.

**Pendiente de playtest.**
- El reparto 50/50 de la oleada es optimista: en el juego, los HUNTER persiguen al héroe más cercano y pueden cargarle todo a uno.
- La Catapulta y el Golpe Furtivo siguen siendo de área: con objetivo único, sus picos se notan más.
- El grupo de 3-4 (reclutas) reparte todavía más y puede hacer los pisos 1-3 demasiado fáciles.
- La cura en Descanso (2 de vida/s por 1 de Comida) y el costo de reanimar (15 + 5 por piso).

## Escalado por jugadores (session calidad-13, cerrado en estabilizar-14)

`PlayerScaling` (`resources/floors/player_scaling.tres`), aplicado por `FloorManager` sobre curva y dificultad. `players` se fija al empezar el piso: una caída a mitad de piso no lo cambia.

| Jugadores | Oleada | Tope de enemigos | Vida de la Reliquia | Amenaza de puerta |
|---|---|---|---|---|
| 1 | ×1 | +0 | ×1 | ×1 |
| 2 | ×1 | +0 | ×1 | ×1,05 |
| 3 | ×1,5 | +4 | ×1,15 | ×1 |
| 4 | ×2 | +8 | ×1,3 | ×1 |

`BalanceSim.scaling_rows()` (5 pisos × 2 dificultades × 1–4 jugadores) da paridad 1,00–1,18 frente a jugar solo; `docs/balance/calidad13_scaling.csv`, `test_balance._check_scaling`.

La tabla ya asumía oleadas escaladas en puertas y extracción, pero hasta estabilizar-14 las puertas ignoraban el multiplicador (`EnemyManager` usaba `DoorRollConfig.enemy_count`): con 3–4 jugadores el co-op real era más fácil que la tabla. No cambió ningún número ni el juego con 1–2 jugadores. Todo esto sigue sin validar con personas.

## Mejoras de gameplay propuestas (session juego-21, sin hacer)
El dueño eligió no tocar mecánicas ni balance en juego-21. Lista para decidir después (costo = trabajo + riesgo):

| Mejora | A favor | En contra | Costo |
|---|---|---|---|
| **Botín al matar**: 1 Brasa con 25 % (élite 50 %) | el combate deja algo, premia defender | infla la luz; re-correr `BalanceSim` | bajo, sin bump (la Brasa la suma el host) |
| **Reparar la Reliquia** en la sala inicial: 10 Hierro = +20 vida, solo en exploración | uso para el Hierro, decisión antes de extraer | extracción más fácil | medio, comando nuevo → bump `config/version` 1.2 |
| **Chamán y Nigromante a distancia**: proyectil cada 2 s desde 200 px | variedad, obliga a moverse | más difícil en pisos 3–5, retocar balance | medio, sin bump (proyectil visual por el evento `fx`) |
| **Armadura plana** en ítems (stat nuevo) | da sentido a las 7 armaduras | toca `CharacterStats`, `RunState`, guardado | alto, bump |

## Corridas completas Monte Carlo (session juego-22)
Corrida: `godot --headless --path . --script res://tools/balance_sim.gd -- juego22 runs` (solo la tabla nueva, ~7 s; `docs/balance/juego22_runs.csv`). Las otras 11 tablas no cambiaron (no se tocó ningún `.tres`).

**Modelo `BalanceSim.run_rows()`** (50 corridas por configuración; 15 grupos: cada héroe solo, los 6 pares, los 4 tríos y los 4; Normal y Difícil; pisos 1-5). Por piso: mapa real (`MapGenerator`), puertas en orden de revelado al azar hasta ver la salida (= turnos), cada puerta paga Brasas de descubrimiento + su recurso al azar + pasivas (Mente Analítica, Paso Ligero) y tira la amenaza (`DoorRollConfig` × piso × dificultad × `PlayerScaling`, con tope). La oleada sale del pool del piso y se reparte en ronda entre los héroes en pie; cada uno mata los suyos de a uno con el mismo modelo de exposición de `encounter_loss` (golpe único, aproximación del Mago). Después el portador camina inicio → salida bajo las oleadas de la etapa 0 de extracción; en los pisos 3 y 5 todo el grupo pega al jefe, que pega a un héroe (contacto + Embestida cada `charge_cooldown`). Gasto de Comida al empezar cada piso: reanimar, subir a cada héroe hasta el nivel piso − 1, curar con lo que sobra; tras cada pelea se reanima a un caído si queda alguien en pie. Cada sala descubierta se enciende si alcanzan las Brasas y recibe un Taller (Forja/Granja/Scriptorium en ronda) si alcanza el Hierro. Activas por uptime: Golpe Furtivo en el DPS del Pícaro, Grito de Guerra × el DPS del grupo, Interposición × el daño recibido. **No modela**: torres y trampas, salas Rest/Elite/Loot, ítems, perks, saqueadores sobre la Reliquia. `hp_lost_pct` puede pasar de 100 % (cuenta lo perdido antes de reanimar).

| Dificultad | Grupo | Victoria por piso 1/2/3/4/5 (%) | Vida perdida piso 1 / 2 (%) | DPS piso 1 | Turnos hasta la salida (piso 1) | Comida / Hierro / Saber / Brasas al final del piso 1 |
|---|---|---|---|---|---|---|
| Normal | Guerrero | 96 / 90 / 0 / 0 / 0 | 53 / 65 | 3,3 | 6,8 | 34 / 16 / 20 / 11 |
| Normal | Mago | 76 / 40 / 0 / 0 / 0 | 68 / 71 | 3,3 | 6,7 | 34 / 16 / 34 / 11 |
| Normal | Pícaro | 66 / 48 / 0 / 0 / 0 | 76 / 73 | 4,0 | 6,4 | 32 / 9 / 22 / 10 |
| Normal | Paladín | 92 / 74 / 0 / 0 / 0 | 46 / 67 | 2,3 | 6,5 | 33 / 15 / 20 / 10 |
| Normal | Guerrero + Mago | 100 / 100 / 0 / 0 / 0 | 19 / 22 | 6,7 | 6,4 | 32 / 15 / 32 / 10 |
| Normal | Mago + Pícaro | 100 / 100 / 0 / 0 / 0 | 26 / 34 | 7,3 | 6,7 | 34 / 10 / 35 / 10 |
| Normal | Pícaro + Paladín | 100 / 100 / 0 / 0 / 0 | 18 / 24 | 6,3 | 6,6 | 34 / 10 / 21 / 9 |
| Normal | los 4 | 100 / 100 / 52 / 4 / 0 | 17 / 21 | 13,0 | 6,7 | 34 / 10 / 35 / 9 |
| Difícil | Guerrero | 90 / 40 / 0 / 0 / 0 | 60 / 83 | 3,3 | 6,5 | 32 / 16 / 20 / 10 |
| Difícil | Mago | 12 / 0 / 0 / 0 / 0 | 96 / 98 | 3,3 | 5,7 | 30 / 12 / 29 / 7 |
| Difícil | Pícaro | 20 / 2 / 0 / 0 / 0 | 93 / 94 | 4,0 | 5,9 | 30 / 7 / 20 / 9 |
| Difícil | Paladín | 34 / 12 / 0 / 0 / 0 | 88 / 82 | 2,3 | 5,9 | 30 / 13 / 18 / 8 |
| Difícil | Guerrero + Mago | 100 / 100 / 0 / 0 / 0 | 33 / 40 | 6,7 | 6,7 | 33 / 16 / 34 / 11 |
| Difícil | Mago + Pícaro | 100 / 82 / 0 / 0 / 0 | 68 / 73 | 7,3 | 6,6 | 23 / 9 / 35 / 9 |
| Difícil | Pícaro + Paladín | 100 / 100 / 0 / 0 / 0 | 45 / 41 | 6,3 | 6,7 | 26 / 9 / 22 / 9 |
| Difícil | los 4 | 100 / 94 / 0 / 0 / 0 | 36 / 47 | 13,0 | 6,6 | 30 / 8 / 36 / 9 |

Victoria media por héroe en grupos de 2-4 (todos los pisos) contra la media de los cuatro: Normal ±0,9 pp, Difícil ±1,1 pp. Solo: Normal Guerrero +8,1, Mago −5,9, Pícaro −6,3, Paladín +4,1; Difícil **Guerrero +15,5**, Mago −8,1, Pícaro −6,1, Paladín −1,3.

`test_balance._check_runs`: todo par gana el piso 1 en ≥ 90 % de las corridas en las dos dificultades, y en grupos de 2-4 ningún héroe se aleja más de 10 pp de la media (por dificultad).

**Lectura.**
- Piso 1 ganable por cualquier par (100 % en Normal y Difícil). Objetivo cumplido.
- Grupos de 2-4: ningún héroe sobresale (±1 pp). El único caso fuera de los 10 pp es el **Guerrero solo en Difícil** (Piel de Hierro −20 % siempre activa + 26 de vida). Un héroe solo no es un modo de juego (offline siempre son 2; co-op, uno por jugador, mínimo 2): queda como dato, sin ajuste.
- **El jefe del piso 3 es una pared en el modelo**: sin jefe, cualquier par gana el piso 3 el 100 % de las veces (el piso 4 el 30-65 %, el 5 el 0-10 %). El Jefe orco (156 de vida en Normal, 5 de contacto, Embestida de 7 cada 6 s) tarda 11-13 s en caer frente a un par y tumba al héroe al que pega en ~6 s. Una sola Ballesta (15 de daño por s, más que el par entero) cambia el resultado: 156 / (13,6 + 15) ≈ 5,5 s. Es decir, **el modelo sin torres no sirve para juzgar los pisos 3-5**. No se tocó el jefe por eso: bajarle la vida con un modelo que ignora las torres lo dejaría trivial en partida. Nadie peleó todavía con un jefe con vida real (`test_full_run` usa vida enorme).
- Recursos al final del piso 1: Comida ~33 (las subidas de nivel la gastan desde el piso 2), Saber 20-35 (alto con el Mago; sin sumidero en el modelo porque no investiga), Hierro 9-16, Brasas 9-11.

**Ajustes: ninguno.** Los objetivos de la sesión se cumplen en grupos de 2-4; lo que no se cumple está fuera de un modo real (héroe solo) o del alcance del modelo (pisos con jefe, sin torres).

**Pendiente de playtest.**
- Jefe del piso 3 con un par de nivel 2 y vida real: ¿hace falta pelearlo junto a una Ballesta? Si es así, que el juego lo insinúe (la ayuda del jefe) o bajar `boss_ogre_chief` (ver Propuestas).
- Pisos 4-5 sin torres caen al 0-60 %: confirmar que en partida las torres y la Rest equilibran.

## Ítems y perks (session juego-22)
`tests/test_equipo_efectos.gd`: cada ítem equipable (15) en cada héroe que puede llevarlo pone exactamente sus modificadores en la columna "equipo" de `PlayerStats.get_stat_breakdown`, el total los sigue (vida con el tope de 120) y al desequipar vuelve a lo de antes; arma + armadura + talismán en el Mago se suman; los 16 perks ponen sus modificadores en la columna "perks" y una corrida nueva la limpia. Ningún ítem sin efecto (los 3 consumibles tienen el suyo).

Poder = ganancia de DPS + ganancia de vida efectiva (+ la mitad de la de alcance) contra los números de nivel 0, promediada sobre los héroes que lo pueden llevar; se compara dentro de cada rareza **y hueco** (arma y armadura se llevan juntas, no compiten):

| Ítem | Rareza | Hueco | Modificadores | Poder | vs media de rareza y hueco |
|---|---|---|---|---|---|
| sword_bronze | Común | arma | +1 daño | 35 % | — |
| sword_iron | Poco común | arma | +2 daño | 71 % | −20 % |
| **sword_steel** | Poco común | arma | +3 daño | 106 % | **+20 % (dominante)** |
| sword_ember | Rara | arma | +3 daño, −0,1 s | 136 % | −2 % |
| sword_jade | Rara | arma | +4 daño | 142 % | +2 % |
| sword_gold | Épica | arma | +5 daño, −0,1 s | 218 % | — |
| armor_leather | Común | armadura | +5 vida | 23 % | — |
| armor_robe | Poco común | armadura | +1 daño, +6 vida (Mago, Pícaro) | 77 % | +26 % (otros héroes: ver abajo) |
| armor_iron | Poco común | armadura | +10 vida | 45 % | −26 % |
| armor_copper | Rara | armadura | +14 vida | 64 % | — |
| armor_steel | Épica | armadura | +20 vida (Guerrero, Paladín) | 64 % | −11 % |
| armor_gold | Épica | armadura | +25 vida (Guerrero, Paladín) | 79 % | +11 % |
| armor_jade | Legendaria | armadura | +2 daño, +30 vida | 207 % | — |
| book_embers | Poco común | talismán | +2 daño (Mago) | 67 % | — |
| book_tides | Rara | talismán | −0,15 s (Mago) | 20 % | — |

- `sword_steel` es estrictamente mejor que `sword_iron` (misma rareza, mismos héroes). Con daño entero no hay ajuste dentro de ±25 %: queda en Propuestas.
- `armor_robe` contra `armor_iron` compara grupos distintos: sobre el Mago y el Pícaro la de hierro da ~58 % y la túnica 77 % (+15 %, en el límite). Sin cambio.
- Rarezas invertidas: `book_tides` (rara) rinde un tercio de `book_embers` (poco común); `armor_steel` (épica) rinde lo mismo que `armor_copper` (rara). Ninguna se arregla con ±25 %.
- El daño plano pesa más en el Pícaro (2 de daño base): las espadas le duplican el DPS. Es la deuda ya anotada en "Pícaro a nivel alto".

## Propuestas (juego-22, sin hacer)
| Propuesta | Por qué | Costo |
|---|---|---|
| `sword_steel` pasa a Rara (o `sword_iron` a Común) | dos espadas poco comunes y una es siempre mejor | bajo, `.tres` (rareza) |
| `book_tides` −0,15 → −0,3 s | la rara rinde un tercio de la poco común | bajo, fuera de ±25 % |
| `armor_steel` 20 → 23 de vida, o pasarla a Rara | una épica igual a una rara | bajo |
| Ayuda del jefe: "pelealo junto a tus Ballestas" | el modelo dice que sin torres el jefe del piso 3 tumba a cualquier par | bajo, texto |
| Re-orden a mitad de camino (cambiar el rumbo en vez de rechazar) | sensación de RTS; hoy responde "Ya hay una orden en curso" | medio: `PlayerActionController` corta el tween y re-planifica desde la zona actual; revisar co-op |
| Torres en `BalanceSim.run_rows` (Ballesta en salas encendidas, peleas cerca) | sin eso el modelo no juzga los pisos 3-5 | medio, solo herramienta |

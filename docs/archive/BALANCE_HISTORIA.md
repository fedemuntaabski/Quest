# BALANCE_HISTORIA.md — historial de balance por sesión

Copia íntegra del `docs/BALANCE.md` de `session/juego-42` (34260bf), sin cambios salvo esta cabecera. El estado vigente está en `docs/BALANCE.md`; acá queda cada sesión con sus tablas y lecturas.

**Barridos de un solo uso** (`tests/tools/sweep_juego25.gd`, `sweep_juego26.gd`, `sweep_juego27.gd`, `sweep_juego27_levers.gd`, `sweep_juego27_levers2.gd`, `sweep_juego28.gd`, `sweep_juego28_final.gd`, `sweep_juego28_levers.gd`, `sweep_juego28_levers2.gd`, `sweep_juego29.gd`, `sweep_juego29_levers.gd`, `sweep_juego30.gd`, `sweep_juego41.gd`): borrados en herramientas-43. Para reproducir sus tablas: `git show 34260bf:tests/tools/<archivo>` (o `git checkout 34260bf -- tests/tools/<archivo>`) y correrlo como dice su sección. Lo de `sweep_juego41.gd` lo hace hoy `tests/tools/sweep.gd`.

---

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
| Mago | Mente Analítica: +2 Saber al descubrir una sala; la Investigación cuesta −10 % mientras está en pie (juego-36) | Bendición de las Obras: solo Obras que funcionan de su sala: torres ×2 de daño (8 s) y talleres pagan 1 turno extra (20 s) |
| Pícaro | Paso Ligero: +2 Brasas al descubrir una sala | Golpe Furtivo: ×3 de daño a todo enemigo en rango (8 s) |
| Paladín | Muro Viviente: hasta −50 % de daño cerca de la Reliquia (0 a 10 casillas = 640 px) | Interposición: todo el grupo recibe −50 % (6 s / 30 s) |

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
- La cura en Descanso (2 de vida/s, gratis desde juego-42) y el costo de reanimar (15 + 5 por piso).

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

## Mejoras de gameplay propuestas (session juego-21; decididas en juego-24)
El dueño eligió no tocar mecánicas ni balance en juego-21. En juego-24 eligió **solo la armadura plana** (ver «Armadura plana»); las otras tres quedan sin hacer. Costo = trabajo + riesgo:

| Mejora | A favor | En contra | Costo |
|---|---|---|---|
| **Botín al matar**: 1 Brasa con 25 % (élite 50 %) | el combate deja algo, premia defender | infla la luz; re-correr `BalanceSim` | bajo, sin bump (la Brasa la suma el host) |
| **Reparar la Reliquia** en la sala inicial: 10 Hierro = +20 vida, solo en exploración | uso para el Hierro, decisión antes de extraer | extracción más fácil | medio, comando nuevo → bump `config/version` 1.2 |
| **Chamán y Nigromante a distancia**: proyectil cada 2 s desde 200 px | variedad, obliga a moverse | más difícil en pisos 3–5, retocar balance | medio, sin bump (proyectil visual por el evento `fx`) |
| **Armadura plana** en ítems (stat nuevo) | da sentido a las 7 armaduras | toca `CharacterStats`, `RunState`, guardado | alto, bump · **hecha en juego-24**: no tocó `RunState` ni el guardado (sale de los ids de ítems); bump a 1.2 igual |

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

## Propuestas (juego-22; decididas en juego-23)
| Propuesta | Decisión (juego-23) |
|---|---|
| `sword_steel` pasa a Rara (o `sword_iron` a Común) | **hecho**: `sword_steel` Rara (poder 106 %, −17 % de la media de las raras, ya no domina a nadie) |
| `book_tides` −0,15 → −0,3 s | **hecho**: poder 20 → 50 % (`book_embers` 67 %; de un tercio a tres cuartos) |
| `armor_steel` 20 → 23 de vida, o pasarla a Rara | **hecho**: 23 de vida, poder 73 % (`armor_copper` 64 %, `armor_gold` 79 %) |
| Ayuda del jefe: "pelealo junto a tus Ballestas" | no (el dueño eligió no tocar el jefe ni su texto) |
| Re-orden a mitad de camino | no, se queda el rechazo hasta un playtest con gente. **juego-35: hecho** tras el reporte del dueño ("el clic derecho a veces no mueve a ninguna sala"): por clic el rechazo era mudo (`_can_act` cortaba antes del comando, la tarjeta nunca salía). Volver al rechazo = revertir 45d0b39 y mostrar la tarjeta en el clic |
| Torres en `BalanceSim.run_rows` | **hecho** (ver «Torres en las corridas») |

## Torres en las corridas (session juego-23)
Corrida: `godot --headless --path . --script res://tools/balance_sim.gd -- juego23 runs` (~10 s; `docs/balance/juego23_runs.csv`). Las otras 11 tablas no cambian (son iguales a las de progresion10/calidad13).

**Supuestos nuevos de `run_rows`** (`towers` = true por defecto):
- La Ballesta pide la investigación «Planos de ballesta» (8 Saber + un Scriptorium funcionando; dura toda la corrida). Hasta tenerla, el primer Taller del piso es un Scriptorium y se investiga apenas alcanza el Saber.
- Investigada: la sala inicial recibe una Ballesta al empezar el piso y cada sala encendida después recibe una **antes** de su Taller (4 Hierro, +25 % por cada una del piso; las obras no pasan de piso). Las torres no caen.
- Una oleada de puerta o de extracción se pelea junto a una Ballesta con probabilidad (salas con Ballesta / salas reveladas); la Ballesta suma 15 de daño por s a la velocidad con que el grupo mata.
- El jefe nace en la sala de salida, apagada; el grupo lo lleva hasta una Ballesta con probabilidad `BOSS_NEAR_TOWERS` = **0,5** (supuesto, sin datos de playtest).
- **Corrección del jefe**: su contacto y su Embestida pegan a **todos** los héroes vivos (están juntos), no a uno. Se vio en la ventana real (`tests/tools/shot_jefe.gd`: Guerrero y Mago de nivel 2 pierden vida a la vez). Con esa corrección, el modelo reproduce la pelea real: con vida llena y una Ballesta, el jefe muere y el Guerrero queda con 5 de vida (real: 4); sin Ballesta, caen los dos (real: el jefe queda con 90 de 156).
- Sigue sin modelar: esquivar la Embestida, alejarse del jefe, trampas, salas Rest/Elite/Loot, ítems, perks.

| Dificultad | Grupo | Victoria por piso 1/2/3/4/5 (%) | juego-22 (sin torres) | Vida perdida piso 1 / 3 (%) | Ballestas piso 1 / 3 | Comida / Hierro / Saber / Brasas al final del piso 1 |
|---|---|---|---|---|---|---|
| Normal | Guerrero | 100 / 98 / 0 / 0 / 0 | 96 / 90 / 0 / 0 / 0 | 36 / 98 | 1,7 / 1,6 | 24 / 6 / 21 / 11 |
| Normal | Mago | 94 / 62 / 0 / 0 / 0 | 76 / 40 / 0 / 0 / 0 | 50 / 93 | 1,8 / 1,4 | 23 / 6 / 34 / 10 |
| Normal | Pícaro | 86 / 70 / 0 / 0 / 0 | 66 / 48 / 0 / 0 / 0 | 55 / 95 | 2,3 / 1,3 | 22 / 3 / 20 / 9 |
| Normal | Paladín | 96 / 94 / 6 / 0 / 0 | 92 / 74 / 0 / 0 / 0 | 35 / 91 | 1,9 / 1,4 | 23 / 5 / 21 / 10 |
| Normal | Guerrero + Mago | 100 / 100 / 0 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 16 / 97 | 1,8 / 1,5 | 22 / 6 / 34 / 10 |
| Normal | Guerrero + Pícaro | 100 / 100 / 2 / 2 / 0 | 100 / 100 / 10 / 0 / 0 | 15 / 96 | 2,1 / 1,4 | 24 / 3 / 21 / 9 |
| Normal | Guerrero + Paladín | 100 / 100 / 12 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 11 / 96 | 1,9 / 1,7 | 23 / 6 / 21 / 11 |
| Normal | Mago + Pícaro | 100 / 100 / 0 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 20 / 93 | 2,4 / 1,5 | 22 / 3 / 34 / 9 |
| Normal | Mago + Paladín | 100 / 100 / 6 / 2 / 0 | 100 / 100 / 0 / 0 / 0 | 15 / 97 | 1,7 / 1,3 | 24 / 5 / 35 / 11 |
| Normal | Pícaro + Paladín | 100 / 100 / 4 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 15 / 96 | 2,4 / 1,4 | 23 / 2 / 20 / 9 |
| Normal | los 4 | 100 / 100 / 4 / 0 / 0 | 100 / 100 / 52 / 4 / 0 | 13 / 89 | 2,3 / 1,5 | 23 / 3 / 34 / 9 |
| Difícil | Guerrero | 92 / 58 / 0 / 0 / 0 | 90 / 40 / 0 / 0 / 0 | 51 / 92 | 1,8 / 1,4 | 23 / 6 / 21 / 10 |
| Difícil | Mago | 30 / 6 / 0 / 0 / 0 | 12 / 0 / 0 / 0 / 0 | 86 / 76 | 1,8 / 1,7 | 22 / 5 / 31 / 8 |
| Difícil | Pícaro | 26 / 2 / 0 / 0 / 0 | 20 / 2 / 0 / 0 / 0 | 85 / 98 | 2,2 / 1,0 | 22 / 3 / 18 / 10 |
| Difícil | Paladín | 48 / 20 / 0 / 0 / 0 | 34 / 12 / 0 / 0 / 0 | 80 / 92 | 1,7 / 1,3 | 23 / 6 / 20 / 9 |
| Difícil | Guerrero + Mago | 100 / 100 / 0 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 27 / 91 | 1,8 / 1,4 | 22 / 6 / 34 / 10 |
| Difícil | Guerrero + Pícaro | 100 / 100 / 0 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 29 / 93 | 2,3 / 1,5 | 22 / 3 / 21 / 9 |
| Difícil | Guerrero + Paladín | 100 / 100 / 0 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 23 / 94 | 1,8 / 1,5 | 22 / 5 / 21 / 10 |
| Difícil | Mago + Pícaro | 98 / 74 / 0 / 0 / 0 | 100 / 82 / 0 / 0 / 0 | 55 / 88 | 2,2 / 1,1 | 18 / 3 / 34 / 9 |
| Difícil | Mago + Paladín | 100 / 92 / 0 / 0 / 0 | 100 / 88 / 0 / 0 / 0 | 34 / 89 | 1,8 / 1,4 | 21 / 5 / 34 / 10 |
| Difícil | Pícaro + Paladín | 100 / 96 / 0 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 30 / 88 | 2,4 / 1,4 | 20 / 3 / 21 / 9 |
| Difícil | los 4 | 100 / 98 / 0 / 0 / 0 | 100 / 94 / 0 / 0 / 0 | 28 / 68 | 2,2 / 1,3 | 23 / 3 / 35 / 9 |

Media por héroe en grupos de 2-4 contra la media de los cuatro: Normal ±0,4 pp, Difícil ±1,3 pp (`test_balance._check_runs` sigue en verde).

Sensibilidad del piso 3 (pares, Normal; victoria media, rango entre pares): sin torres 0 %; torres pero el jefe siempre a oscuras 0 %; `boss_near` 0,5 → 4 % (0-12); siempre junto a la Ballesta → 8 % (0-28). Difícil: 0 % en todos los casos. Grupo de 4: 4-8 % en Normal.

**Lectura: el jefe del piso 3 sigue siendo una pared.**
- Las torres ayudan donde el jefe no está: solos y pisos 1-2 suben (Mago solo Normal 76/40 → 94/62), pero el piso 3 no.
- La pelea contra el jefe solo se gana si el grupo llega con casi toda la vida **y** lo pelea junto a una Ballesta (la captura: el Guerrero gana con 4 de vida). El modelo llega al jefe con ~90 % de la vida del piso ya perdida (**corregido en juego-24**: ese número era la vida perdida en todo el piso, contando la pelea contra el jefe; al llegar al jefe le quedaba ~60 %, ver «El jefe como se juega») (oleadas de puerta y de extracción; solo cura con Comida al empezar el piso), así que pierde.
- El grupo de 4 cae de 52 % a 4 %: la corrección (el jefe pega a todos) le pega más al que tiene más héroes juntos.
- Lo que el modelo no tiene y podría cambiarlo en partida: esquivar la Embestida y salir del contacto (de los ~6 de daño por s que recibe cada héroe, 5 son contacto y ~1,2 la carga), curarse en una sala Rest antes de abrir la salida, separar al grupo. Barrido de juego-23 (sin aplicar, el dueño eligió no tocar el jefe): vida 120 → 90 sube los pares en Normal de 19 a 32 % con el modelo de un solo blanco; con el modelo corregido haría falta re-medir.

**Ajustes de juego-23:** solo los tres ítems (arriba). `test_balance._check_run_towers`: hay Ballestas en el piso 1, sin torres no se construye ninguna, y el jefe junto a una Ballesta gana > 20 pp más que a oscuras (Guerrero + Paladín, Normal). `test_equipo_efectos._check_rarity_picks`: una sola arma poco común, `book_tides` ≥ 70 % de `book_embers`, `armor_steel` > 1,1 × `armor_copper`.

## El jefe como se juega (session juego-24)
Corrida: `godot --headless --path . --script res://tools/balance_sim.gd -- juego24 runs` (~20 s; `docs/balance/juego24_runs.csv`, columnas nuevas `boss_hp_in` y `boss_win`). Las otras 11 tablas no cambian.

**Supuestos nuevos de `run_rows`** (`play`, valores por defecto en `BalanceSim.BOSS_PLAY`):
- `boss_first` = true: el jefe se despierta al revelar la sala de salida (`EnemyManager._on_room_revealed`) y caza al grupo (perfil cazador), así que se pelea **antes** de las oleadas de extracción. juego-23 lo peleaba después.
- `heal` = "comida": antes del jefe, cada héroe vivo se cura con la Comida que queda, por el retrato (0,15 Comida por punto de vida; se puede en cualquier momento). Con "rest" solo se cura si se reveló una sala Rest, a su precio: 1 Comida cada 2 de vida (0,5 por punto). **Rest es más cara que el retrato**, así que no suma nada (gratis desde juego-42: ver «La sala de Descanso gratis»). Con "none" solo se cura al empezar el piso.
- `dodge` = **0,5**: la parte de las Embestidas que se esquiva. Es un supuesto, sin datos de gente; el script de la ventana esquiva todas. Una esquivada no daña a nadie.
- `dodge_sec` = **2,0**: por cada esquive, el grupo pasa 2 s fuera del contacto (ni pega ni recibe) y la Ballesta sigue tirando. Con 2 s se reproduce la ventana.
- Se arregló un cuelgue: `_boss_fight` podía repetir pasos cada vez más chicos por restos de coma flotante en la vida del jefe. Ahora corta en 0,001, como ya hacía con los héroes.

**Calibración** (`tests/tools/shot_jefe.gd`, ventana real; piso 3, jefe con 156 de vida, Guerrero + Mago de nivel 2 con vida llena). El modo `esquiva` mueve a los dos a la otra sala vecina en cuanto el jefe se pone rojo:

| Modo | Ventana real | Modelo |
|---|---|---|
| `sin` | caen a los 9 s, al jefe le quedan 90 | caen los dos |
| `esquiva` | caen a los 12 s, al jefe le quedan 68 | caen los dos |
| `ballesta` | muere el jefe, Guerrero con 4 | muere el jefe, Guerrero con 5 |
| `esquiva_ballesta` | muere el jefe, Guerrero con 18 y Mago con 6 | Guerrero con 17 y Mago con 5 |

En la ventana, el contacto pega 4 por s a cada héroe y la Embestida ~6 a cada uno, una cada ~6 s. La Embestida es ~20 % del daño; el resto es contacto.

| Dificultad | Grupo | Victoria por piso 1/2/3/4/5 (%) | juego-23 | Vida al llegar al jefe del piso 3 (%) | Peleas contra el jefe ganadas (%) |
|---|---|---|---|---|---|
| Normal | Guerrero | 100 / 98 / 40 / 4 / 0 | 100 / 98 / 0 / 0 / 0 | 98 | 52 |
| Normal | Mago | 94 / 62 / 0 / 0 / 0 | 94 / 62 / 0 / 0 / 0 | 98 | 0 |
| Normal | Pícaro | 86 / 70 / 0 / 0 / 0 | 86 / 70 / 0 / 0 / 0 | 95 | 0 |
| Normal | Paladín | 96 / 94 / 22 / 0 / 0 | 96 / 94 / 6 / 0 / 0 | 97 | 41 |
| Normal | Guerrero + Mago | 100 / 100 / 18 / 2 / 0 | 100 / 100 / 0 / 0 / 0 | 98 | 34 |
| Normal | Guerrero + Pícaro | 100 / 100 / 40 / 8 / 0 | 100 / 100 / 2 / 2 / 0 | 97 | 54 |
| Normal | Guerrero + Paladín | 100 / 100 / 34 / 12 / 0 | 100 / 100 / 12 / 0 / 0 | 97 | 34 |
| Normal | Mago + Pícaro | 100 / 100 / 0 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 88 | 0 |
| Normal | Mago + Paladín | 100 / 100 / 26 / 0 / 0 | 100 / 100 / 6 / 2 / 0 | 95 | 36 |
| Normal | Pícaro + Paladín | 100 / 100 / 46 / 6 / 0 | 100 / 100 / 4 / 0 / 0 | 94 | 48 |
| Normal | los 4 | 100 / 100 / 28 / 0 / 0 | 100 / 100 / 4 / 0 / 0 | 78 | 46 |
| Difícil | Guerrero | 92 / 58 / 0 / 0 / 0 | 92 / 58 / 0 / 0 / 0 | 98 | 0 |
| Difícil | Mago | 30 / 6 / 0 / 0 / 0 | 30 / 6 / 0 / 0 / 0 | 99 | 0 |
| Difícil | Pícaro | 26 / 2 / 0 / 0 / 0 | 26 / 2 / 0 / 0 / 0 | — | — |
| Difícil | Paladín | 48 / 20 / 0 / 0 / 0 | 48 / 20 / 0 / 0 / 0 | 84 | 0 |
| Difícil | Guerrero + Mago | 100 / 100 / 0 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 77 | 0 |
| Difícil | Guerrero + Pícaro | 100 / 100 / 0 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 85 | 0 |
| Difícil | Guerrero + Paladín | 100 / 100 / 2 / 0 / 0 | 100 / 100 / 0 / 0 / 0 | 92 | 6 |
| Difícil | Mago + Pícaro | 98 / 74 / 0 / 0 / 0 | 98 / 74 / 0 / 0 / 0 | 76 | 0 |
| Difícil | Mago + Paladín | 100 / 92 / 0 / 0 / 0 | 100 / 92 / 0 / 0 / 0 | 81 | 0 |
| Difícil | Pícaro + Paladín | 100 / 96 / 0 / 0 / 0 | 100 / 96 / 0 / 0 / 0 | 71 | 0 |
| Difícil | los 4 | 100 / 98 / 0 / 0 / 0 | 100 / 98 / 0 / 0 / 0 | 62 | 0 |

**Sensibilidad del piso 3** (pares, juego por defecto; victoria media de los 6 pares):

| Cambio | Normal, jefe a oscuras | Normal, `boss_near` 0,5 | Normal, siempre junto a Ballesta | Difícil, `boss_near` 0,5 |
|---|---|---|---|---|
| ninguno | 0 % | 27 % | 60 % | 0 % |
| sin curar antes ni esquivar (juego-23) | 0 % | 4 % | — | 0 % |
| esquivar todo (`dodge` 1) | — | 36 % | — | 7 % |
| vida del jefe 120 → 90 | 0 % | 36 % | — | 7 % |
| Embestida 6 → 3 | 0 % | 31 % | — | 0 % |

**Lectura: el jefe del piso 3 es una pared solo a oscuras y en Difícil.**
- Si el grupo se cura con Comida y esquiva la mitad de las Embestidas, en Normal llega con ~97 % de la vida. Junto a una Ballesta lo mata en 84-92 % de las peleas. A oscuras no lo mata nunca: 0 %, con cualquier vida o Embestida. Cuando se gana, la Ballesta es lo que decide la pelea.
- Mago + Pícaro: 0 % siempre. Es el único par sin un héroe que aguante el contacto.
- En Difícil sigue siendo una pared (0-2 %). En Normal, la próxima pared es el piso 4 (≤ 12 %); el piso 5 está en 0 % en todos los casos.
- **Decisión del dueño (juego-24): no se toca el jefe** (ni texto ni números), igual que en juego-23.

## Armadura plana (session juego-24)
Es un modificador de ítem nuevo, `armor` (`ItemData.MODIFIER_KEYS`). La suma la da `PartyInventory.get_equipment_bonus`, llega a `CharacterStats.armor` y aparece como fila «Armadura» en la hoja del héroe. `HeroAbilities.incoming_damage` la resta de cada golpe **después** de Piel de Hierro e Interposición, y el golpe nunca baja de 1. No toca `RunState` ni el guardado: las dos máquinas la calculan desde los ids de ítems y el daño lo aplica el host. Igual se subió `config/version` a 1.2, porque dos versiones distintas calcularían distinta la vida de las corazas.

Con 1 punto de armadura, el daño de contacto recibido baja 45 % en el piso 1, 44 % en el 2, 33 % en el 3 y el 4, y 28 % en el 5 (`BalanceSim.armor_ehp_mult`). Con 2 puntos baja hasta 63 %, así que solo se usa 1.

**Decisión del dueño:** las tres corazas pesadas cambian vida por 1 de armadura, con el mismo poder en el piso 3. Las otras cuatro (cuero, túnica, hierro, cobre) siguen dando solo vida.

| Ítem | Antes | Ahora | Poder antes → ahora (piso 3) |
|---|---|---|---|
| `armor_steel` (Épica, Guerrero/Paladín) | +23 vida | +5 vida, +1 armadura | 73 → 74 % |
| `armor_gold` (Épica, Guerrero/Paladín) | +25 vida | +7 vida, +1 armadura | 79 → 83 % |
| `armor_jade` (Legendaria) | +2 daño, +30 vida | +2 daño, +12 vida, +1 armadura | 207 → 202 % |

Rinden más contra muchos golpes chicos (pisos 1-2) y menos en el piso 5. `run_rows` sigue sin modelar ítems, así que la tabla de corridas no cambia por la armadura. Tests: `test_abilities` (armadura 1: 10 → 7, 2 → 1, `take_hit` resta 7), `test_inventory` (coraza de acero: +5 de vida y armadura 1, también después de subir de nivel), `test_equipo_efectos` (columna «equipo» de la armadura, poder con `armor_ehp_mult`; `armor_steel` > 1,1 × `armor_copper` sigue en verde).


## Piso 4 por causa e ítems (session juego-25)
Corrida: `godot --headless --path . --script res://tools/balance_sim.gd -- juego25 runs` (`docs/balance/juego25_runs.csv`; un tercer argumento `noitems` da la tabla sin equipo, idéntica a `juego24_runs.csv` en Normal). Barrido por causa: `tests/tools/sweep_juego25.gd` (200 corridas; lento, > 15 min).

**Supuestos nuevos de `run_rows`** (`play`, valores por defecto en `BalanceSim.BOSS_PLAY`):
- `items` = true. Cada sala revelada tira su cofre con la probabilidad real de su tipo (`FloorConfig.loot_chance`: Loot 1,0; Élite 0,7; Taller 0,15; Rest 0,1; común 0,08) y la tabla del piso (`LootTable`). El Altar se usa si el héroe con más vida se queda con ≥ 50 % después de pagar (`ALTAR_KEEP_HP`, supuesto). Cada piso ganado da su botín de fin de piso. El ítem va al héroe vivo al que más le sube DPS + vida efectiva (la armadura plana cuenta con `armor_ehp_mult`). No se modelan los consumibles ni pasar un ítem reemplazado a otro héroe (subestima). Los ítems usan su propio RNG: prenderlos no mueve mapas ni oleadas.
- La armadura plana entra en `duel` y en el jefe (contacto y Embestida, mínimo 1).
- **Corrección:** Difícil empieza con los recursos × 0,75 (`Main._begin_new_run`); el modelo no lo aplicaba.
- Columnas nuevas por piso: `die_door` / `die_boss` / `die_extr` (parte de las corridas que mueren en cada fase), `heroes` (vivos al empezar), `lvl_gap` (niveles que faltan contra piso − 1), `food_short` (Comida que faltó para reanimar, subir y curar al empezar), `hp_start`, `hp_exit` (vida al ver la salida), `door_fights`, `dmg_door_pct` / `dmg_boss_pct` / `dmg_extr_pct`, `items` (equipados).
- «Qué pasaría si» (apagados): `free_food`, `no_doors` = piso, `no_extr` = piso.

**Pares en Normal, 200 corridas** (victoria por piso 3 / 4; el piso 5 es 0 % en todos):

| Grupo | Sin ítems (juego-24) | Con ítems | Piso 4 con ítems: vivos / niveles que faltan / Comida que falta / vida al empezar | Muere en puertas / extracción (piso 4) |
|---|---|---|---|---|
| Guerrero + Mago | 24 / 1 | 48 / 23 | 1,8 / 1,6 / 43 / 60 % | 50 % / 3 % |
| Guerrero + Pícaro | 35 / 3 | 63 / 34 | 1,7 / 1,7 / 41 / 63 % | 43 % / 2 % |
| Guerrero + Paladín | 41 / 10 | 52 / 29 | 1,9 / 1,7 / 50 / 65 % | 40 % / 4 % |
| Mago + Pícaro | 0 / 0 | 39 / 14 | 1,7 / 1,7 / 42 / 58 % | 64 % / 1 % |
| Mago + Paladín | 29 / 1 | 44 / 18 | 1,7 / 1,7 / 44 / 62 % | 54 % / 6 % |
| Pícaro + Paladín | 43 / 3 | 56 / 23 | 1,8 / 1,7 / 46 / 64 % | 56 % / 4 % |
| los 4 | 30 / 1 | 78 / 7 | 3,3 / 2,3 / 106 / 35 % | 85 % / 6 % |

Difícil con ítems: piso 3 en 1-22 % (pares), piso 4 ≤ 1 %; se llega al piso 3 con 1,1-1,3 niveles de menos y ~24 de Comida de menos.

**Qué pasaría si** (media de los 6 pares, Normal, con ítems; victoria piso 3 / 4 / 5):

| Cambio | Piso 3 | Piso 4 | Piso 4 entre los que llegan | Piso 5 |
|---|---|---|---|---|
| ninguno | 50 % | 24 % | 47 % | 0 % |
| Comida infinita | 100 % | 100 % | 100 % | 99 % |
| sin oleadas de puerta en el piso 4 | 50 % | 50 % | 99 % | 0 % |
| sin oleadas de extracción en el piso 4 | 50 % | 25 % | 50 % | 0 % |

**Lectura.**
- **El piso 4 lo decide la Comida.** Se muere en las oleadas de puerta (40-64 %), pero porque se llega mal: después del jefe del piso 3 no alcanza para reanimar, subir de nivel y curar (faltan ~40-50 de Comida; 1,7 héroes vivos de 2, 1,6 niveles de menos, 60 % de vida). Con Comida infinita la corrida entera pasa a 99-100 %. La extracción no decide nada (1-6 % de las muertes, 1-2 % de la vida).
- **Mago + Pícaro no gana nunca solo en el modelo sin ítems** (95 % de sus corridas mueren contra el jefe). Con ítems gana el piso 3 en 39 % (los otros pares 44-63 %): el daño plano de las espadas y talismanes casi duplica su DPS.
- Los 4: el piso 3 sube a 78 %, pero el piso 4 cae a 7 % (faltan 106 de Comida para cuatro héroes).
- El piso 5 sigue en 0 % en todos los casos sin Comida infinita.

**Decisiones del dueño (juego-25):** ajustar la **Comida** (bono al bajar de piso o al matar al jefe, o nivel más barato; valores a barrer en juego-26, con test). Par sin tanque: nada. No se tocó balance en esta sesión.

## Comida tras el jefe (session juego-26)
Palancas en `FloorConfig`: `food_bonus_on_descend` (al bajar, piso 2+) y `boss_food_reward` (al morir el jefe de los pisos 3 y 5). Barrido: `tests/tools/sweep_juego26.gd -- <corridas> <normal|hard> <bajar> <jefe> <base_cost> <cost_growth>` (un proceso por combinación; 6 pares, con ítems; costo de nivel aplicado también al Paladín). Columnas: victoria en los pisos 3 / 4 / 5 (media de los pares), piso 4 entre los que ganan el 3, Comida que falta al empezar el piso 4, piso 4 de Mago + Pícaro entre los que llegan.

**200 corridas:**

| Dificultad | Bajar | Jefe | Nivel (base × crecimiento) | Pisos 3 / 4 / 5 (%) | Piso 4 entre los que llegan | Comida que falta | Mago + Pícaro |
|---|---|---|---|---|---|---|---|
| Difícil | 0 | 0 | 8 × 1,4 | 10 / 1 / 0 | 7 % | 35 | 0 % |
| Difícil | 0 | 10 | 6 × 1,35 | 14 / 1 / 0 | 9 % | 13 | 100 % |
| Difícil | 0 | 10 | 8 × 1,4 | 10 / 1 / 0 | 12 % | 25 | 0 % |
| Difícil | 0 | 15 | 8 × 1,4 | 10 / 2 / 0 | 15 % | 24 | 0 % |
| Difícil | 0 | 20 | 8 × 1,4 | 11 / 1 / 0 | 11 % | 29 | 0 % |
| Difícil | 5 | 0 | 6 × 1,35 | 24 / 3 / 0 | 12 % | 17 | 17 % |
| Difícil | 5 | 10 | 8 × 1,4 | 18 / 3 / 0 | 14 % | 17 | 100 % |
| Normal | 0 | 0 | 8 × 1,4 | 50 / 24 / 0 | 47 % | 44 | 36 % |
| Normal | 0 | 10 | 6 × 1,35 | 61 / 37 / 1 | 61 % | 17 | 47 % |
| Normal | 0 | 10 | 8 × 1,4 | 50 / 29 / 0 | 58 % | 35 | 36 % |
| Normal | 0 | 15 | 8 × 1,4 | 51 / 31 / 0 | 61 % | 33 | 50 % |
| Normal | 0 | 20 | 8 × 1,4 | 51 / 35 / 1 | 69 % | 32 | 55 % |
| Normal | 5 | 0 | 6 × 1,35 | 71 / 50 / 2 | 71 % | 14 | 62 % |
| Normal | 5 | 10 | 8 × 1,4 | 62 / 43 / 2 | 70 % | 22 | 57 % |

En Difícil, Mago + Pícaro llega al piso 4 en 0-2 corridas de 200: su 0 / 17 / 100 % es ruido.

**Grilla gruesa, Normal, 60 corridas:**

| Bajar | Jefe | Nivel | Pisos 3 / 4 / 5 (%) | Piso 4 entre los que llegan |
|---|---|---|---|---|
| 0 | 0 | 8 × 1,4 | 48 / 22 / 0 | 45 % |
| 0 | 0 | 6 × 1,35 | 59 / 25 / 0 | 43 % |
| 0 | 0 | 5 × 1,3 | 64 / 33 / 0 | 52 % |
| 0 | 20 | 8 × 1,4 | 49 / 36 / 1 | 74 % |
| 0 | 20 | 6 × 1,35 | 59 / 46 / 3 | 77 % |
| 0 | 20 | 5 × 1,3 | 64 / 53 / 5 | 84 % |
| 0 | 40 | 8 × 1,4 | 49 / 42 / 4 | 86 % |
| 0 | 40 | 6 × 1,35 | 60 / 55 / 9 | 93 % |
| 0 | 40 | 5 × 1,3 | 64 / 61 / 13 | 94 % |
| 10 | 0 | 8 × 1,4 | 69 / 49 / 2 | 71 % |
| 10 | 0 | 6 × 1,35 | 74 / 59 / 7 | 79 % |
| 10 | 0 | 5 × 1,3 | 75 / 63 / 14 | 84 % |
| 10 | 20 | 8 × 1,4 | 70 / 63 / 9 | 89 % |
| 10 | 20 | 6 × 1,35 | 75 / 71 / 17 | 94 % |
| 10 | 20 | 5 × 1,3 | 77 / 74 / 27 | 96 % |
| 10 | 40 | 8 × 1,4 | 70 / 69 / 17 | 98 % |
| 10 | 40 | 6 × 1,35 | 75 / 75 / 31 | 100 % |
| 10 | 40 | 5 × 1,3 | 77 / 77 / 39 | 100 % |
| 20 | 0 | 8 × 1,4 | 79 / 70 / 15 | 88 % |
| 20 | 0 | 6 × 1,35 | 84 / 77 / 28 | 92 % |
| 20 | 0 | 5 × 1,3 | 84 / 79 / 37 | 93 % |
| 20 | 20 | 8 × 1,4 | 80 / 76 / 23 | 95 % |
| 20 | 20 | 6 × 1,35 | 85 / 82 / 38 | 97 % |
| 20 | 20 | 5 × 1,3 | 86 / 84 / 47 | 98 % |
| 20 | 40 | 8 × 1,4 | 81 / 81 / 32 | 100 % |
| 20 | 40 | 6 × 1,35 | 85 / 84 / 49 | 99 % |
| 20 | 40 | 5 × 1,3 | 86 / 85 / 56 | 99 % |

**Lectura.** El bono al bajar y los niveles baratos también suben el piso 3 (con bajar 20 pasa de 48 a 80-86 %). El bono del jefe solo mueve lo que viene después del jefe: el piso 3 no cambia y Difícil casi no se mueve, porque ahí casi nadie mata al jefe.

**Elegido (dueño): jefe +15 Comida**, sin bono al bajar y sin tocar el costo de los niveles. Normal: piso 4 entre los que llegan 47 → 61 %. `test_balance._check_food_floor4` fija el valor y estos umbrales: Normal ≥ 50 % del piso 4 entre los que llegan, piso 3 ≤ 65 %, Difícil piso 4 ≤ 10 %. El piso 5 sigue en 0-1 %.

## Piso 5 por causa (session juego-27)
Barridos: `tests/tools/sweep_juego27.gd -- <corridas>` (tabla por causa de los pisos 4 y 5, Normal y Difícil, 6 pares + los 4, y «qué pasaría si» del piso 5; ~2,5 min a 200 corridas) y `tests/tools/sweep_juego27_levers.gd` / `sweep_juego27_levers2.gd -- <corridas>` (palancas en memoria: `FloorTheme` del piso 5, vida del Señor Demonio, Comida al bajar desde un piso). «Qué pasaría si» nuevo en `BOSS_PLAY`: `no_boss` = piso sin jefe.

**Simulador 20× más rápido, mismos números.** `ItemCatalog`/`LootTable`/`PlayerScaling.get_default()` hacen `load()` de un `.tres` que nadie retenía: cada cofre volvía a leer el catálogo de ítems (~13 ms). `run_rows` ahora retiene esos recursos mientras corre (`BalanceSim._keep`). Tabla de corridas con ítems: 184 → 9 s; `test_balance` ~4 min → 19 s. Comparado fila por fila contra la copia vieja (con y sin ítems, 150 filas cada una) y, con el jefe en 0 de Comida, contra `juego25_runs.csv`: 0 diferencias. `sweep_juego26` usa el mismo `run_rows`.

**Antes (jefe +15 de juego-26), Normal, 200 corridas, piso 5:**

| Grupo | Vivos al empezar | Niveles que faltan | Comida que falta | Vida al empezar | Muere en puertas / jefe / extracción | Vida al llegar al jefe | Gana al jefe |
|---|---|---|---|---|---|---|---|
| Guerrero + Mago | 1,8 | 2,1 | 66 | 75 % | 51 / 49 / 0 % | 79 % | 0 % |
| Guerrero + Pícaro | 1,6 | 2,1 | 59 | 73 % | 65 / 35 / 0 % | 78 % | 0 % |
| Guerrero + Paladín | 1,8 | 2,1 | 69 | 62 % | 64 / 35 / 0 % | 61 % | 4 % |
| Mago + Pícaro | 1,7 | 2,1 | 60 | 70 % | 57 / 43 / 0 % | 74 % | 0 % |
| Mago + Paladín | 1,7 | 2,1 | 63 | 67 % | 75 / 25 / 0 % | 59 % | 0 % |
| Pícaro + Paladín | 1,8 | 2,1 | 70 | 70 % | 64 / 36 / 0 % | 71 % | 0 % |
| los 4 | 2,7 | 2,9 | 129 | 38 % | 94 / 6 / 0 % | 26 % | 0 % |

**Qué pasaría si** (media de los 6 pares; pisos 3 / 4 / 5, piso 5 entre los que ganan el 4):

| Cambio | Normal antes | Normal con lo elegido | Difícil antes | Difícil con lo elegido |
|---|---|---|---|---|
| ninguno | 51 / 31 / 0 (1 %) | 51 / 42 / 19 (46 %) | 10 / 2 / 0 (0 %) | 10 / 3 / 0 (6 %) |
| Comida infinita | 100 / 100 / 99 (99 %) | igual | 100 / 93 / 76 (82 %) | igual |
| sin oleadas de puerta en el 5 | 51 / 31 / 1 (4 %) | 51 / 42 / 30 (71 %) | 10 / 2 / 0 | 10 / 3 / 1 (19 %) |
| sin extracción en el 5 | 51 / 31 / 0 (1 %) | 51 / 42 / 20 (48 %) | 10 / 2 / 0 | 10 / 3 / 0 (6 %) |
| sin jefe en el 5 | 51 / 31 / 11 (34 %) | 51 / 42 / 28 (68 %) | 10 / 2 / 0 | 10 / 3 / 0 (13 %) |
| sin puertas ni jefe en el 5 | 51 / 31 / 31 (100 %) | 51 / 42 / 42 (100 %) | 10 / 2 / 0 (89 %) | 10 / 3 / 3 (100 %) |

**Lectura.** Al piso 5 se llega con 2,1 niveles de menos (de 4) y faltan ~60-70 de Comida: el mismo déficit del piso 4, acumulado. Se muere en las puertas (51-75 %) y el resto contra el jefe (25-49 %), que con 220 de vida no lo gana casi nadie aunque llegue con 60-80 % de vida. Hacen falta los dos: sin jefe gana el 34 % de los que llegan, sin puertas el 4 %. La extracción no decide. Los 4 quedan en 0 %: su muro es el piso 4 (faltan ~90 de Comida para cuatro). En Difícil casi nadie pasa del piso 3, así que nada del piso 5 lo mueve.

**Palancas barridas** (200 corridas; pisos 3 / 4 / 5 de los pares, piso 5 entre los que llegan, los 4 en el piso 5):

| Cambio | Normal | Difícil | Los 4 (Normal) |
|---|---|---|---|
| ninguno | 51 / 31 / 0 (1 %) | 10 / 2 / 0 (0 %) | 0 % |
| piso 5 con vida y daño del 4 (1,45 / 1,3) | 51 / 31 / 1 (4 %) | 10 / 2 / 0 | 1 % |
| piso 5 amenaza × 0,7 | 51 / 31 / 1 (2 %) | 10 / 2 / 0 | 1 % |
| piso 5 amenaza × 0,5 | 51 / 31 / 1 (2 %) | 10 / 2 / 0 | 1 % |
| Señor Demonio 220 → 150 de vida | 51 / 31 / 3 (9 %) | 10 / 2 / 0 | 0 % |
| Señor Demonio 220 → 110 | 51 / 31 / 6 (19 %) | 10 / 2 / 0 | 0 % |
| Comida +20 al bajar al 4 y al 5 | 51 / 40 / 4 (11 %) | 10 / 2 / 0 | 1 % |
| Comida +30 al bajar al 4 y al 5 | 51 / 42 / 9 (21 %) | 10 / 3 / 0 | 0 % |
| Comida +40 al bajar al 4 y al 5 | 51 / 44 / 13 (30 %) | 10 / 2 / 0 | 0 % |
| Comida +40 al bajar al 5 | 51 / 31 / 3 (10 %) | 10 / 2 / 0 | 0 % |
| Comida +20 (4 y 5) + jefe 150 | 51 / 40 / 12 (29 %) | 10 / 2 / 0 | 1 % |
| Comida +20 (4 y 5) + jefe 110 | 51 / 40 / 17 (43 %) | 10 / 2 / 0 | 1 % |
| **Comida +30 (4 y 5) + jefe 150 (elegido)** | **51 / 42 / 19 (46 %)** | **10 / 3 / 0 (6 %)** | 0 % |
| Comida +30 (4 y 5) + jefe 110 | 51 / 42 / 24 (57 %) | 10 / 3 / 0 (6 %) | 1 % |
| Comida +40 (4 y 5) + jefe 150 | 51 / 44 / 24 (56 %) | 10 / 2 / 0 (7 %) | 1 % |
| Comida +30 (4 y 5) + jefe 150 + piso 5 como el 4 | 51 / 42 / 26 (62 %) | 10 / 3 / 0 (13 %) | 2 % |
| amenaza 0,7 + jefe 150 | 51 / 31 / 5 (15 %) | 10 / 2 / 0 | 2 % |
| Comida +20 (4 y 5) + amenaza 0,7 | 51 / 40 / 7 (17 %) | 10 / 2 / 0 | 1 % |

La amenaza del piso 5 casi no mueve nada (no se investigó por qué; candidato: el tope `max_chance` de `DoorRollConfig`).

**Elegido (dueño): +30 Comida al bajar a los pisos 4 y 5** (`food_bonus_on_descend = 30`, `food_bonus_from_floor = 4` nuevo en `FloorConfig`, lo paga `FloorManager`) **y el Señor Demonio con 150 de vida** (`boss_demon_lord.tres` `base_hp` 220 → 150). El piso 3 no cambia. Con eso, al piso 5 se llega con 0,6 niveles de menos y ~15 de Comida faltante (antes 2,1 y ~65); se muere 23-35 % en puertas y 15-34 % contra el jefe. `test_balance._check_food_floor4` fija los valores y estos umbrales: Normal ≥ 30 % del piso 5 entre los que llegan (0,43 a 50 corridas), Difícil piso 5 ≤ 5 %; siguen los de juego-26.

## Difícil en el piso 3 y los 4 en co-op, por causa (session juego-28)
Barridos: `tests/tools/sweep_juego28.gd -- <corridas>` (causas de Difícil pisos 1-3 en los 6 pares, de los 4 en Normal pisos 3-5 y sus «qué pasaría si»; ~2 min a 200 corridas), `sweep_juego28_levers.gd` / `_levers2.gd` (palancas en memoria) y `sweep_juego28_final.gd` (pares, tríos y los 4 con los datos que se publican). «Qué pasaría si» nuevos en `BalanceSim.BOSS_PLAY`: `free_levels` (los niveles no cuestan Comida), `players` (escalado de N jugadores sea cual sea el grupo; 1 con los 4 = sin conexión con reclutas, todos desde el piso 1) y `extra_food` / `extra_food_to` (Comida extra en cada bajada).

**Difícil, piso 3 (antes, 200 corridas):** se llega con 1,1-1,3 niveles de menos y ~22-26 de Comida faltante, y con 75-90 % de vida al jefe. Muere contra el Jefe Ogro el 65-82 % de los que juegan el piso 3 (gana el jefe solo el 1-34 %); en las puertas muere el 1-6 % de los grupos con Guerrero y el 17-29 % de los otros tres. La extracción, 0-13 %.

| Qué pasaría si (Difícil, media de los 6 pares) | Pisos 1 / 2 / 3 / 4 | Piso 3 entre los que llegan |
|---|---|---|
| ninguno | 100 / 96 / 10 / 3 | 11 % |
| Comida infinita | 100 / 100 / 100 / 93 | 100 % |
| niveles gratis | 100 / 98 / 37 / 27 | 38 % |
| sin oleadas de puerta en el 3 | 100 / 96 / 15 / 3 | 15 % |
| sin jefe en el 3 | 100 / 96 / 81 / 26 | 85 % |
| sin extracción en el 3 | 100 / 96 / 16 / 3 | 16 % |
| recursos de inicio ×1 | 100 / 99 / 17 / 5 | 17 % |
| vida de los enemigos ×1 | 100 / 100 / 32 / 14 | 32 % |
| daño de los enemigos ×1 | 100 / 100 / 24 / 10 | 24 % |
| amenaza ×1 | 100 / 98 / 12 / 5 | 13 % |
| sin tope extra | 100 / 96 / 10 / 3 | 11 % |

**Lectura.** La pared de Difícil es el jefe del piso 3 con la vida (×1,35) y el daño (×1,25) de Difícil encima de la curva: sin jefe pasa el 81 %. Puertas, Comida de inicio y amenaza mueven poco.

**Los 4, Normal (antes, 200 corridas):**

| Grupo | Piso | Gana | Héroes | Niveles que faltan | Comida que falta | Vida al empezar | Muere en puertas / jefe / extracción |
|---|---|---|---|---|---|---|---|
| co-op 4 | 3 | 78 % | 4,0 | 1,3 | 57 | 86 % | 1 / 17 / 5 % |
| co-op 4 | 4 | 31 % | 3,3 | 1,5 | 63 | 58 % | 55 / 0 / 5 % |
| co-op 4 | 5 | 0 % | 2,4 | 2,0 | 63 | 40 % | 89 / 10 / 2 % |
| sin conexión (escalado de 1) | 3 | 90 % | 4,0 | 1,3 | 53 | 95 % | 0 / 9 / 2 % |
| sin conexión | 4 | 85 % | 3,6 | 1,4 | 71 | 61 % | 4 / 0 / 1 % |
| sin conexión | 5 | 43 % | 3,3 | 1,9 | 103 | 58 % | 19 / 25 / 5 % |

| Qué pasaría si (los 4, Normal) | Pisos 3 / 4 / 5 | Piso 4 entre los que llegan |
|---|---|---|
| co-op 4 | 78 / 31 / 0 | 40 % |
| co-op 4, Comida infinita | 100 / 100 / 100 | 100 % |
| co-op 4, niveles gratis | 100 / 100 / 93 | 100 % |
| co-op 4, sin oleadas de puerta en el 4 | 78 / 78 / 5 | 100 % |
| co-op 4, sin jefe en el 5 | 78 / 31 / 3 | 40 % |
| co-op 4 con el escalado de 2 jugadores | 92 / 86 / 37 | 93 % |
| sin conexión (escalado de 1) | 90 / 85 / 43 | 94 % |

**Lectura.** Sin conexión, los 4 ya pasan a los pares. El muro es co-op de 4: `PlayerScaling` duplica las oleadas (×2, tope +8), así que cada héroe pelea lo mismo que en un par, pero la Comida de las puertas no crece con el grupo y hay que subir de nivel y curar a cuatro (falta ~60 desde el piso 3). Con niveles gratis pasan todos.

**Palancas barridas** (200 corridas; pisos 3 / 4 / 5; pares = media de los 6, los 4 = co-op 4):

| Cambio | Normal pares | Difícil pares | Normal los 4 | Difícil los 4 |
|---|---|---|---|---|
| ninguno | 51 / 42 / 19 | 10 / 3 / 0 | 78 / 31 / 0 | 4 / 1 / 0 |
| Jefe Ogro −25 % de vida | 70 / 58 / 27 | 24 / 7 / 0 | 93 / 51 / 3 | 11 / 0 / 0 |
| Jefe Ogro −40 % de vida | 87 / 73 / 34 | 33 / 11 / 0 | 97 / 57 / 2 | 19 / 1 / 0 |
| jefes sin la vida de Difícil | igual | 24 / 7 / 0 | igual | 11 / 0 / 0 |
| **jefes sin la vida ni el daño de Difícil (elegido)** | igual | **33 / 11 / 1** | igual | 18 / 1 / 0 |
| lo anterior + recursos de inicio ×1 | igual | 41 / 17 / 1 | igual | 26 / 2 / 0 |
| jefes sin la vida de Difícil + daño de Difícil 1,1 | igual | 34 / 18 / 2 | igual | 19 / 1 / 0 |
| Jefe Ogro −15 % + jefes sin la vida de Difícil | 62 / 51 / 24 | 31 / 10 / 1 | 88 / 43 / 1 | 16 / 1 / 0 |
| Difícil daño 1,25 → 1,1 | igual | 20 / 9 / 1 | igual | 9 / 0 / 0 |
| Difícil recursos de inicio ×1 | igual | 17 / 5 / 0 | igual | 7 / 1 / 0 |
| co-op 4: oleada ×2 → ×1,5 | igual | igual | 79 / 52 / 6 | 12 / 2 / 0 |
| co-op 4: oleada ×2 → ×1,75 | igual | igual | 78 / 41 / 1 | 4 / 1 / 0 |
| co-op 4: tope +8 → +4 | igual | igual | 78 / 31 / 0 | 4 / 1 / 0 |
| co-op 4: Comida al bajar ×2 (60 en los pisos 4-5) | igual | igual | 78 / 43 / 6 | 4 / 1 / 0 |
| co-op 4: +15 Comida en cada bajada (2-5) | igual | igual | 98 / 68 / 10 | 18 / 1 / 0 |
| **co-op 4: +20 Comida en cada bajada (2-5) (elegido)** | igual | igual | **99 / 83 / 25** | 28 / 3 / 0 |
| co-op 4: +30 Comida al bajar a los pisos 2-3 | igual | igual | 100 / 93 / 26 | 56 / 8 / 0 |
| co-op 4: +20 por bajada + oleada ×1,75 | igual | igual | 99 / 93 / 38 | 28 / 4 / 0 |
| co-op 4: +15 por bajada + oleada ×1,5 | igual | igual | 100 / 85 / 26 | 44 / 8 / 0 |

**Elegido (dueño): D1 + C1.** `DifficultyLevel.scales_bosses` nuevo (Difícil = false): los jefes toman solo la curva del piso, sin el ×1,35 / ×1,25 de Difícil (`FloorManager.enemy_hp_multiplier(boss)`, lo pide `EnemyManager._spawn_enemy`; los refuerzos que invoca el jefe siguen con Difícil). `PlayerScaling.descent_food` nuevo = 0 / 0 / 10 / 20 de Comida en cada bajada (piso 2 en adelante) con 1 / 2 / 3 / 4 jugadores, además de los +30 de los pisos 4 y 5 (`FloorManager.descent_food()`). Al bajar, la tarjeta del HUD dice «Provisiones — Al bajar al piso N: +X Comida.» (cada par la muestra local). Versión 1.5.

**Con lo elegido** (`sweep_juego28_final.gd`, 200 corridas; pisos 3 / 4 / 5):

| Dificultad | Pares | Tríos (co-op 3) | Los 4 (co-op 4) | Los 4 sin conexión |
|---|---|---|---|---|
| Normal | 51 / 42 / 19 (igual) | 84 / 59 / 14 (antes 64 / 32 / 3) | 99 / 83 / 25 (antes 78 / 31 / 0) | 90 / 85 / 43 (igual) |
| Difícil | 33 / 11 / 1 (antes 10 / 3 / 0) | 47 / 6 / 1 | 67 / 11 / 0 (antes 4 / 1 / 0) | 70 / 38 / 3 |

`test_balance` (50 corridas) fija los datos y estos umbrales: Normal pares ≥ 45 / 36 / 14 % en los pisos 3 / 4 / 5 (piso de 51 / 42 / 19 a 200 corridas, con margen de ruido), los 4 en co-op Normal piso 4 ≥ 60 % y piso 5 ≤ 50 %, Difícil pares piso 3 ≥ 25 %, piso 4 ≤ 20 % (antes 10 %) y piso 5 ≤ 5 %. `test_difficulty_curve` comprueba que un jefe recibe solo la curva en las dos dificultades, la Comida al bajar por jugadores y el aviso en el HUD.

Sin conexión con reclutas no se tocó: el simulador lo aproxima con los 4 desde el piso 1 (sin pagar el rescate y sin la espera hasta la sala de prisioneros), así que es una cota alta. En Difícil, el piso 4 (11 %) pasa a ser la pared siguiente.

## Difícil en el piso 4 y el rescate sin conexión (session juego-29)
Barridos: `tests/tools/sweep_juego29.gd -- <corridas> [1|2]` (1 = Difícil pisos 3-5 por causa en los 6 pares y los 4 en co-op, con «qué pasaría si» en el piso 4; 2 = pares sin conexión que rescatan prisioneros; ~4 min las dos a 200 corridas) y `sweep_juego29_levers.gd -- <corridas> [palancas separadas por ;]` (palancas en memoria; la fila «base» son los datos publicados). «Qué pasaría si» nuevos en `BalanceSim.BOSS_PLAY`: `recruit` (rescata hasta N prisioneros), `recruit_levels` (el recluta entra con piso − 1 niveles gratis), `recruit_cost_mult` (precio ×), `full_hp` (vida completa gratis al empezar ese piso) y `extra_food_from` (primer piso de `extra_food`). Todos apagados por defecto: las tablas anteriores no cambian.

**Difícil, piso 4 (antes, 200 corridas).** Pares: gana el 4-19 % (media 11 %, el 32 % de los que llegan). Entre los que juegan el piso 4, muere en las puertas el 59-77 % (no hay jefe; extracción 0-7 %); las oleadas de puerta se llevan el 77-80 % de la vida del grupo. Se llega con 0,7-0,9 niveles de menos, 7-14 de Comida faltante, 71-80 % de vida y ~4 ítems. Los 4 en co-op: 11 %, el 81 % muere en las puertas, llegan 2,8 héroes de 4 con el 56 % de vida.

| Qué pasaría si (Difícil) | Pares 3 / 4 / 5 | Piso 4 entre los que llegan | Los 4 en co-op 3 / 4 / 5 | Piso 4 entre los que llegan |
|---|---|---|---|---|
| ninguno | 33 / 11 / 1 | 32 % | 67 / 11 / 0 | 16 % |
| Comida infinita | 100 / 93 / 77 | 93 % | 100 / 98 / 89 | 98 % |
| niveles gratis | 70 / 59 / 32 | 85 % | 100 / 87 / 37 | 87 % |
| vida completa al empezar el 4 | 33 / 13 / 1 | 40 % | 67 / 16 / 1 | 24 % |
| sin oleadas de puerta en el 4 | 33 / 33 / 4 | 100 % | 67 / 67 / 2 | 100 % |
| sin extracción en el 4 | 33 / 12 / 1 | 35 % | 67 / 13 / 1 | 19 % |
| sin ítems | 7 / 0 / 0 | 5 % | 23 / 1 / 0 | 4 % |
| recursos de inicio ×1 | 41 / 17 / 1 | 42 % | 79 / 16 / 1 | 20 % |
| vida de los enemigos ×1 | 42 / 21 / 4 | 49 % | 89 / 25 / 3 | 28 % |
| daño de los enemigos ×1 | 39 / 21 / 4 | 54 % | 84 / 23 / 3 | 27 % |
| amenaza ×1 | 37 / 17 / 2 | 47 % | 80 / 20 / 1 | 25 % |
| sin tope extra | 33 / 11 / 1 | 32 % | 67 / 11 / 0 | 16 % |

**Lectura.** La pared del piso 4 son las oleadas de puerta (en el 4 se esperan 16,6 enemigos contra 7,6 en el 3) contra héroes que llegan un nivel por detrás. La vida al empezar casi no importa. Los ítems son imprescindibles (sin ellos, 0 %). Dar Comida al bajar solo a los pisos 4 y 5 casi no mueve nada (+20: 33 / 14 / 3), porque el déficit de niveles viene de los pisos 2-3. Darla desde el piso 2 (+10: 58 / 33 / 8) deja a Difícil por encima de Normal en el piso 3.

**Rescate modelado** (`BalanceSim._recruit`, `recruit` > 0). Al revelarse una sala de prisioneros (una por piso con 50 %, `RoomTypeRule` por defecto), si el grupo tiene menos de 4 y queda alguien fuera, la celda se puede pagar el resto del piso. Mientras espera no se construyen Obras (se ahorra el Hierro). Se intenta pagar tras cada puerta y otra vez al aparecer la salida, con el primer precio que alcance en el orden Saber, Hierro, Comida (`recruit_costs_at`). El recluta lo elige el mismo sorteo que `PrisonerSpawner.pick_candidate` y entra con nivel 1 y vida completa. Se le compran niveles hasta piso − 1 con la Comida que haya, y después pelea, se reanima y se sube de nivel como los demás. No se modela: el rescate en co-op, la caminata hasta la celda ni el Saber gastado en Investigación (más allá de la Ballesta).

| Sin conexión, pares (antes: 15 Comida / 20 Hierro, +5 por piso) | Normal 3 / 4 / 5 | Difícil 3 / 4 / 5 | Héroes en el piso 3 / 4 / 5 (Normal) |
|---|---|---|---|
| sin rescatar | 51 / 42 / 19 | 33 / 11 / 1 | 2,00 / 1,84 / 1,83 |
| hasta 1 | 49 / 41 / 17 | 29 / 9 / 0 | 2,49 / 2,15 / 2,06 |
| hasta 2 | 48 / 40 / 16 | 28 / 9 / 1 | 2,49 / 2,17 / 2,06 |
| hasta 2, entra con el nivel del grupo | 49 / 41 / 17 | 28 / 9 / 1 | 2,49 / 2,16 / 2,06 |
| hasta 2, gratis | 74 / 67 / 31 | 52 / 30 / 3 | 2,90 / 2,87 / 2,97 |
| los 4 desde el piso 1 (aproximación de juego-28) | 90 / 85 / 43 | 70 / 38 / 3 | 4,00 / 3,63 / 3,34 |

**Lectura.** Con los precios de antes, rescatar empeoraba la partida. Solo se pagaba el prisionero del piso 1 (15 Comida, la de inicio). Después el precio (25-40) no se alcanzaba: sin Forjas entran 5-10 de Hierro por piso y la Comida se va en niveles. El recluta entra con nivel 1, se lleva su parte de cada oleada y cuesta Comida en niveles y reanimaciones. La aproximación de juego-28 era una cota muy alta.

**Palancas barridas** (200 corridas; pisos 3 / 4 / 5; Normal sin rescates no cambia con ninguna):

| Cambio | Difícil pares | Difícil tríos | Difícil los 4 (co-op) | Normal pares que rescatan | Difícil pares que rescatan |
|---|---|---|---|---|---|
| ninguno | 33 / 11 / 1 | 47 / 6 / 1 | 67 / 11 / 0 | 48 / 40 / 16 | 28 / 9 / 1 |
| **Difícil: daño 1,25 → 1,1 + inicio ×1 (A1, elegido)** | **45 / 28 / 3** | 68 / 24 / 2 | 83 / 29 / 1 | igual | 40 / 23 / 3 |
| Difícil: daño 1,25 → 1,1 + amenaza 1,25 → 1,1 (A2) | 37 / 23 / 4 | 59 / 18 / 1 | 83 / 32 / 2 | igual | 34 / 20 / 3 |
| Difícil: vida 1,35 → 1,2 + daño 1,1 (A3) | 38 / 22 / 5 | 61 / 17 / 2 | 83 / 26 / 3 | igual | 34 / 20 / 4 |
| Difícil: daño 1,25 → 1,1 | 35 / 19 / 3 | 53 / 12 / 1 | 74 / 23 / 2 | igual | 30 / 15 / 3 |
| Difícil: amenaza 1,25 → 1,1 | 35 / 14 / 2 | 54 / 9 / 0 | 73 / 14 / 1 | igual | 32 / 13 / 2 |
| Difícil: vida 1,35 → 1,2 | 35 / 14 / 2 | 54 / 9 / 1 | 75 / 16 / 1 | igual | 32 / 13 / 2 |
| Difícil: inicio ×1 | 41 / 17 / 1 | 64 / 14 / 1 | 79 / 16 / 1 | igual | 38 / 15 / 1 |
| Difícil: +5 Comida al bajar (2-5) | 44 / 19 / 3 | 65 / 13 / 2 | 81 / 16 / 1 | igual | 42 / 20 / 3 |
| Difícil: +10 Comida al bajar (2-5) | 58 / 33 / 8 | 76 / 28 / 4 | 91 / 25 / 1 | igual | 55 / 33 / 8 |
| Difícil: +15 Comida al bajar (2-5) | 68 / 48 / 13 | 86 / 42 / 5 | 99 / 44 / 5 | igual | 68 / 51 / 12 |
| Difícil: +20 Comida al bajar a 4 y 5 | 33 / 14 / 3 | 47 / 11 / 1 | 67 / 16 / 2 | igual | 28 / 13 / 3 |
| **rescate a mitad de precio: 8 Comida / 10 Hierro (B, elegido)** | igual | igual | igual | **54 / 46 / 20** | 35 / 13 / 1 |
| B + entra con el nivel del grupo | igual | igual | igual | 55 / 48 / 22 | 35 / 13 / 1 |
| rescate sin +5 por piso | igual | igual | igual | 49 / 41 / 16 | 28 / 9 / 1 |
| rescate también por 15 Saber (+5 por piso) (C) | igual | igual | igual | 67 / 59 / 27 | 48 / 25 / 3 |
| C + entra con el nivel del grupo | igual | igual | igual | 75 / 69 / 43 | 57 / 35 / 9 |

La opción en Saber está inflada: el simulador solo gasta Saber en la Ballesta.

**Elegido (dueño): A1 + B.** `difficulty_config.tres`: Difícil `damage_mult` 1,25 → 1,1 y sin `start_resource_mult` (×0,75 → ×1); la descripción pierde «menos recursos al empezar». `default_floor_config.tres`: `recruit_costs` 15 Comida / 20 Hierro → 8 / 10 (+5 por piso igual). Versión 1.6.

**Con lo elegido** (`sweep_juego29_levers.gd -- 200 base` y `sweep_juego29.gd -- 200 2`; pisos 3 / 4 / 5):

| Dificultad | Pares | Tríos (co-op 3) | Los 4 (co-op 4) | Pares sin conexión, hasta 2 rescates | Héroes en el piso 3 / 4 / 5 |
|---|---|---|---|---|---|
| Normal | 51 / 42 / 19 (igual) | 84 / 59 / 14 (igual) | 99 / 83 / 25 (igual) | 54 / 46 / 20 (antes 48 / 40 / 16) | 2,54 / 2,25 / 2,20 |
| Difícil | 45 / 28 / 3 (antes 33 / 11 / 1) | 68 / 24 / 2 (antes 47 / 6 / 1) | 83 / 29 / 1 (antes 67 / 11 / 0) | 46 / 28 / 5 (antes 28 / 9 / 1) | 2,52 / 2,08 / 2,00 |

Con lo elegido, rescatar uno da casi lo mismo que dos (Normal 55 / 47 / 21): el segundo rescate cuesta 13-30 según el piso y casi nunca alcanza. Que el recluta entre con el nivel del grupo suma 1-2 puntos.

`test_balance` (50 corridas) fija los datos (Difícil daño 1,1 e inicio ×1, rescate 8 / 10 + 5) y: Difícil pares piso 3 ≥ 35 % (antes 25), piso 4 entre 18 y 40 % (antes ≤ 20), piso 5 ≤ 5 %; Difícil no gana a Normal en ningún piso (pares); los pares de Normal que rescatan hasta 2 tienen más de 2,3 héroes en el piso 3 y ganan los pisos 3-5 al menos tanto como sin rescatar (a 50 corridas: 1,26 contra 1,11). `test_difficulty_curve`: Difícil empieza con ×1.

## La Investigación en el simulador y el piso 5 (session juego-30)
Barrido: `tests/tools/sweep_juego30.gd -- <corridas> [1|2|3|4 [0|1]]` (1 = órdenes de Investigación; 2 = rescate también por Saber, con y sin Investigación; 3 = piso 5 por causa y «qué pasaría si»; 4 = palancas en memoria, el tercer argumento enciende la Investigación). «Qué pasaría si» nuevos en `BalanceSim.BOSS_PLAY`:
- `research` = entradas de `research_config.tres` que se compran después de la Ballesta, en ese orden y con el Saber que haya. Hace falta un Scriptorium en ese piso y los requisitos previos. Si la siguiente no alcanza, se ahorra para ella. El efecto se lee como `ResourceManager.get_bonus`: rendimiento de Talleres, daño de Defensas, costo de luz y Brasas por sala. `BalanceSim.RESEARCH_ORDER` es el orden del modelo (Virotes, Cartografía, Yesca, Herramientas, Fuelles). Brasero y Catapulta no se compran: el simulador no construye trampas ni catapultas.
- `lab_first` (por defecto sí): con Saber para la siguiente entrada y sin Scriptorium en el piso, la próxima sala encendida recibe el Scriptorium en lugar de su Ballesta.
- `level_lore`: Saber por Comida para un nivel que la Comida no alcanza (−1 = `UpgradeConfig`; 0 = solo Comida, la regla anterior).

`research` está apagado por defecto: las tablas publicadas siguen comprando solo la Ballesta.

**Gastar el Saber como un jugador (antes de lo elegido, 200 corridas; pisos 3 / 4 / 5).**

| Orden | Dificultad | Pares | Tríos (co-op 3) | Los 4 (co-op 4) | Pares que rescatan hasta 2 | Saber al final del 3 / 4 / 5 (pares) | Investigaciones (pares) |
|---|---|---|---|---|---|---|---|
| solo Ballesta (publicado) | Normal | 51 / 42 / 19 | 84 / 59 / 14 | 99 / 83 / 25 | 54 / 46 / 20 | 58 / 77 / 102 | 1 / 1 / 1 |
| solo Ballesta (publicado) | Difícil | 45 / 28 / 3 | 68 / 24 / 2 | 83 / 29 / 1 | 46 / 28 / 5 | 58 / 74 / 96 | 1 / 1 / 1 |
| Virotes primero (el modelo) | Normal | 44 / 37 / 17 | 81 / 56 / 15 | 97 / 82 / 18 | 51 / 44 / 20 | 22 / 32 / 50 | 3,9 / 4,9 / 5,6 |
| Virotes primero (el modelo) | Difícil | 41 / 27 / 5 | 63 / 23 / 2 | 87 / 38 / 5 | 45 / 30 / 6 | 23 / 29 / 45 | 3,8 / 4,9 / 5,5 |
| economía primero | Normal | 44 / 36 / 16 | 81 / 54 / 14 | 98 / 78 / 16 | 50 / 43 / 18 | 22 / 35 / 53 | 4,5 / 5,1 / 5,6 |
| economía primero | Difícil | 40 / 24 / 4 | 61 / 20 / 2 | 79 / 29 / 1 | 43 / 28 / 5 | 22 / 31 / 46 | 4,4 / 5,1 / 5,5 |
| economía primero, la Ballesta antes que el Scriptorium | Normal | 51 / 42 / 19 | 85 / 59 / 16 | 100 / 84 / 20 | 54 / 46 / 20 | 37 / 56 / 76 | 3,4 / 3,5 / 3,7 |
| solo economía | Normal | 43 / 35 / 13 | 82 / 53 / 12 | 98 / 77 / 15 | 50 / 42 / 17 | 30 / 45 / 67 | 4,1 / 4,6 / 4,8 |
| solo Virotes | Normal | 49 / 42 / 20 | 84 / 61 / 19 | 99 / 86 / 31 | 54 / 48 / 22 | 41 / 59 / 82 | 1,8 / 2 / 2 |
| solo Virotes | Difícil | 45 / 29 / 5 | 71 / 27 / 3 | 86 / 36 / 2 | 47 / 32 / 6 | 40 / 57 / 77 | 1,8 / 2 / 2 |

**Lectura.** Comprar toda la Investigación no mejora la partida; la baja hasta 7 puntos en el piso 3. La de economía no paga lo que cuesta: +1 Brasa por sala, −3 a la luz y +25 % de 3 por Taller (= +1). Lo que falta es Hierro y Comida, no Brasas. Además, el Scriptorium de cada piso ocupa la sala de una Ballesta o de una Granja. Si la Ballesta va primero, casi no se construye Scriptorium después del piso 1 y el resultado queda como el publicado. Solo los Virotes (+10 de daño a la Ballesta, +67 %) suman: los 4 en co-op pasan de 25 a 31 % en el piso 5. Aun gastándolo todo sobran 20-50 de Saber al final del piso 5, y más con el Mago (75-80, por su pasiva).

**Rescate también por 15 Saber (+5 por piso), pares sin conexión, hasta 2 (antes de lo elegido; pisos 3 / 4 / 5).**

| Caso | Dificultad | Sin Investigación | Con Investigación |
|---|---|---|---|
| precio publicado (8 Comida / 10 Hierro) | Normal | 54 / 46 / 20 | 51 / 44 / 20 |
| precio publicado | Difícil | 46 / 28 / 5 | 45 / 30 / 6 |
| también 15 Saber | Normal | 71 / 63 / 31 | 65 / 59 / 29 |
| también 15 Saber | Difícil | 63 / 47 / 9 | 57 / 42 / 9 |

Sigue valiendo la pena con el Saber gastado en Investigación: +14 / +15 / +9 en Normal (antes +17 / +17 / +11). La inflación que temía juego-29 era chica, porque el Saber sobra igual.

**Piso 5 por causa (con Investigación, antes de lo elegido).** Pares en Normal: gana el 47 % de los que llegan; muere en las puertas el 27 % y contra el jefe el 23 % (extracción 3 %). Llegan con 0,5 niveles de menos y les faltan 14-18 de Comida. Pares en Difícil: el 63 % muere en las puertas. Los 4 en co-op: Normal 64 % en las puertas, 3,3 héroes de 4, 0,8 niveles de menos, 43 de Comida faltante y 64 % de vida; Difícil 87 % en las puertas.

| Qué pasaría si (con Investigación) | Normal pares 4 / 5 | 5 entre los que llegan | Difícil pares 4 / 5 | Normal los 4 4 / 5 | Difícil los 4 4 / 5 |
|---|---|---|---|---|---|
| ninguno | 37 / 17 | 47 % | 27 / 5 | 82 / 18 | 38 / 5 |
| Comida infinita | 100 / 98 | 98 % | 99 / 88 | 100 / 100 | 100 / 98 |
| niveles gratis | 74 / 69 | 94 % | 68 / 48 | 100 / 100 | 99 / 74 |
| vida completa al empezar el 5 | 37 / 19 | 52 % | 27 / 7 | 82 / 37 | 38 / 5 |
| sin oleadas de puerta en el 5 | 37 / 27 | 72 % | 27 / 17 | 82 / 75 | 38 / 31 |
| sin extracción en el 5 | 37 / 19 | 51 % | 27 / 6 | 82 / 22 | 38 / 5 |
| sin jefe en el 5 | 37 / 26 | 70 % | 27 / 9 | 82 / 28 | 38 / 5 |

**Lectura.** La pared del piso 5 es la misma que la del 4: Comida para niveles contra las oleadas de puerta. Al mismo tiempo sobra Saber, así que la palanca natural es convertir el Saber que sobra en niveles.

**Palancas barridas** (200 corridas, sin Investigación, antes de lo elegido; pisos 3 / 4 / 5):

| Cambio | Normal pares | Difícil pares | Normal tríos | Normal los 4 | Difícil los 4 | Normal / Difícil pares que rescatan |
|---|---|---|---|---|---|---|
| ninguno | 51 / 42 / 19 | 45 / 28 / 3 | 84 / 59 / 14 | 99 / 83 / 25 | 83 / 29 / 1 | 54 / 46 / 20 · 46 / 28 / 5 |
| **A. niveles también con Saber, 2 por Comida (elegido)** | 66 / 57 / 31 | 62 / 43 / 9 | 96 / 82 / 32 | 100 / 86 / 33 | 92 / 33 / 6 | 73 / 67 / 42 · 69 / 52 / 17 |
| niveles también con Saber, 1 por Comida | 71 / 62 / 36 | 68 / 51 / 13 | 96 / 85 / 38 | 100 / 86 / 36 | 93 / 31 / 6 | 83 / 79 / 59 · 80 / 67 / 34 |
| **B. rescate también por 15 Saber (elegido)** | igual | igual | igual | igual | igual | 71 / 63 / 31 · 63 / 47 / 9 |
| **A + B** | 66 / 57 / 31 | 62 / 43 / 9 | 96 / 82 / 32 | 100 / 86 / 33 | 92 / 33 / 6 | 81 / 75 / 48 · 75 / 62 / 17 |
| Virotes 25 → 15 Saber y +10 → +20 (C) | igual | igual | igual | igual | igual | igual |
| +10 Comida al bajar al 5 | 51 / 42 / 21 | 45 / 28 / 5 | 84 / 59 / 20 | 99 / 83 / 19 | 83 / 29 / 2 | 54 / 46 / 22 · 46 / 28 / 6 |
| amenaza del piso 5 ×0,85 | 51 / 42 / 21 | 45 / 28 / 4 | 84 / 59 / 19 | 99 / 83 / 30 | 83 / 29 / 2 | 54 / 46 / 22 · 46 / 28 / 5 |

C solo se nota con Investigación (los 4 en co-op en el piso 5: 18 → 25).

**Elegido (dueño): A + B.** `run_upgrade_config.tres`: `alt_resource = "lore"`, `alt_cost_mult = 2.0`. Un nivel que la Comida no alcanza se paga con el doble en Saber (`PlayerStats._level_payment`: primero Comida, después Saber). El popup muestra el precio que se va a pagar, y si no alcanza ninguno dice «Faltan N Comida o M Saber». `default_floor_config.tres`: `recruit_costs` 8 Comida / 10 Hierro / **15 Saber** (+5 por piso). Versión 1.7.

**Con lo elegido** (`sweep_juego30.gd -- 200 4 0` y `4 1`, fila «ninguno»; pisos 3 / 4 / 5):

| Dificultad | Pares | Tríos (co-op 3) | Los 4 (co-op 4) | Pares que rescatan hasta 2 | Pares con Investigación | Los 4 con Investigación |
|---|---|---|---|---|---|---|
| Normal | 66 / 57 / 31 (antes 51 / 42 / 19) | 96 / 82 / 32 (antes 84 / 59 / 14) | 100 / 86 / 33 (antes 99 / 83 / 25) | 81 / 75 / 48 (antes 54 / 46 / 20) | 54 / 46 / 23 | 99 / 84 / 31 |
| Difícil | 62 / 43 / 9 (antes 45 / 28 / 3) | 81 / 45 / 5 (antes 68 / 24 / 2) | 92 / 33 / 6 (antes 83 / 29 / 1) | 75 / 62 / 17 (antes 46 / 28 / 5) | 49 / 34 / 8 | 89 / 39 / 5 |

Difícil queda por debajo de Normal en todos los grupos y pisos. Con Saber para niveles, la Investigación sigue costando unos 10 puntos en los pisos 3-4: compite por el mismo Saber.

`test_balance` (50 corridas) fija los datos (Saber ×2 para niveles, rescate 8 / 10 / 15 + 5) y además comprueba:
- Normal pares: piso 3 entre 58 y 80 % (antes 45-65), piso 4 ≥ 50 % y piso 5 ≥ 25 %.
- Difícil pares: piso 3 ≥ 50 %, piso 4 entre 30 y 55 %, piso 5 ≤ 15 %.
- Los niveles con Saber no son una pérdida (pisos 3-5: 1,54 contra 1,11 solo con Comida).
- El «qué pasaría si» `research` compra más de 4 entradas hasta el piso 5 y deja menos Saber que la partida por defecto (4,9 entradas, 36 de Saber contra 66).

## Ajuste de habilidades (session juego-36)

Aplicadas las propuestas de juego-35 (`PERSONAJES.md` «Revisión de habilidades»), con el OK del dueño. Tablas: `docs/balance/juego36_antes_{heroes,runs}.csv` (sin los cambios) y `juego36_{heroes,runs}.csv` (con ellos), 50 corridas por fila.

| Habilidad | Antes | Ahora | Efecto en BalanceSim |
|---|---|---|---|
| Golpe Furtivo (Pícaro) | enfriamiento 12 s | **8 s** | DPS con la activa: nivel 0 4,50 → 4,75; nivel 5 20,42 → 21,29. Victoria con Pícaro +0 a +8 puntos (Normal Pícaro solo piso 2: 0,88 → 0,92; Pícaro+Paladín piso 5: 0,30 → 0,38; Difícil Pícaro piso 2: 0,50 → 0,58), 1-6 puntos menos de vida perdida. Grupos sin Pícaro: igual |
| Mente Analítica (Mago) | +2 Saber por sala | +2 Saber por sala **y −10 % al costo de la Investigación mientras está en pie** (`ResourceManager.research_cost`, un solo punto de lectura; el panel muestra el precio real) | las corridas compran una sola Investigación (la Ballesta, 10 → 9): +1 Saber al final; victoria igual. Con más Investigación el ahorro crece (10 % de cada compra) |
| Bendición de las Obras (Mago) | enfriamiento 30 s, contaba Obras de salas apagadas | **20 s**, solo Obras que funcionan (`Building.is_working()`) | no modelada en BalanceSim (como antes): una Forja encendida rinde +3 Hierro cada 20 s en vez de 30 |
| Muro Viviente (Paladín) | texto «640 px» | «10 casillas» (`{radius_cells}` = radio / `ArtConfig.CELL_PX`) | sin cambio de números |

`test_abilities` chequea cada uno (enfriamientos 20 y 8 s; Forja y Ballesta apagadas no reciben la Bendición; precio con el Mago en pie y caído, también en `ResearchPanel`; el texto del Muro). `test_balance` sigue verde sin tocar umbrales. Versión 1.9 → **1.10** (cambian números que calcula el host y el texto que arman los dos).

## Obras en las corridas (session juego-41)
Barrido: `godot --headless --path . --script res://tests/tools/sweep_juego41.gd -- <corridas> <tag> [play json]` (pares = media de los 6, tríos co-op 3, los 4 co-op 4; Normal y Difícil; ~50 s a 200 corridas). Tablas: `docs/balance/juego41_antes_runs.csv` (modelo de juego-36) y `juego41_despues_runs.csv`. El json acepta las claves de `BOSS_PLAY` más `"towers": false` y `"boss_near": x`.

**Qué se agregó a `run_rows` (siempre encendido; no cambia ningún dato del juego, no hay subida de versión):**
- **Obras por sala.** Cada sala lleva cuántas Ballestas, Catapultas y Pinchos tiene y si está encendida. El costo es `Building.get_cost` (`BuildingCostCurve` sobre las del mismo tipo en el piso). Una Defensa solo tira con la sala encendida (`requires_light`); los Pinchos no lo piden.
- **El jugador de referencia** pone una Defensa en la sala de la Reliquia al empezar el piso y en cada sala que enciende (como juego-23). Después del jefe, cada sala revelada del camino a la salida sin Obra recibe una Defensa si está encendida, o Pinchos (3 de Hierro) si está a oscuras. La Catapulta reemplaza a la Ballesta solo si se investigó (`{"research": ["catapulta"]}`).
- **Dónde se pelea.** Una oleada de puerta, en una sala revelada al azar. Una de extracción, en una sala del camino a la salida. El jefe, con `BOSS_NEAR_TOWERS` = 0,5, en la sala mejor defendida del camino (la de la Reliquia incluida); si no, sin Obras.
- **Cómo pegan.** La Ballesta pone `damage / fire_rate` (15/s, +10 con Virotes) como antes. La Catapulta, 25 cada 3 s a `min(enemigos, SPLASH_HITS = 3)` blancos (supuesto: el radio de 70 px cubre el anillo alrededor de un héroe). Los Pinchos, 10 una vez a cada enemigo que llega (no se apilan, como `Enemy`).
- **`dmg_by_towers_pct`** = vida de enemigos que sacaron las Obras / vida de enemigos sacada (puertas, extracción y jefe). **`towers`** ahora cuenta todas las Obras defensivas del piso (antes, solo Ballestas).
- **Salas.** Recompensa al descubrir según su `RoomTypeRule` (Botín +6 Hierro, Élite +8 Saber, +1 por piso; `heal_on_discovery` si lo hubiera). El cofre ya estaba (juego-25). La cura (`heal`) corre también **antes de la extracción**, no solo antes del jefe. Con `"rest"`, la cura de la sala de Descanso se cobra a su precio (`heal_food_per_tick` / `heal_per_tick` = 0,5 Comida por punto).
- **Saqueadores.** En las oleadas de extracción, cada RAIDER quita `damage_vs_relic` por segundo de contacto (`RELIC_TICK_SEC`) a la Reliquia que lleva el portador (vida de `FloorManager.relic_max_hp`). Si llega a 0 se pierde el piso (`die_relic`). `relic_hp_end` = vida que le queda al terminar el piso.

**Antes / después** (200 corridas; victoria por piso 1 / 2 / 3 / 4 / 5 en %; Obras, daño de Obras y vida de la Reliquia, después):

| Dificultad | Grupo | Victoria juego-41 | Antes (juego-36) | Obras piso 1 / 3 / 5 | Daño de Obras piso 1 / 3 / 5 (%) | Reliquia al final del 3 / 5 (%) |
|---|---|---|---|---|---|---|
| Normal | pares | 100 / 100 / 72 / 66 / 49 | 100 / 100 / 67 / 59 / 32 | 3,0 / 3,4 / 5,0 | 22 / 18 / 13 | 99 / 100 |
| Normal | tríos (co-op 3) | 100 / 100 / 100 / 93 / 66 | 100 / 100 / 96 / 84 / 35 | 3,0 / 3,8 / 4,8 | 20 / 14 / 11 | 98 / 99 |
| Normal | los 4 (co-op 4) | 100 / 100 / 100 / 100 / 83 | 100 / 100 / 100 / 89 / 45 | 3,1 / 3,9 / 5,3 | 17 / 11 / 9 | 98 / 100 |
| Difícil | pares | 100 / 100 / 71 / 57 / 25 | 100 / 100 / 64 / 44 / 10 | 3,1 / 3,4 / 4,2 | 21 / 17 / 12 | 98 / 100 |
| Difícil | tríos (co-op 3) | 100 / 100 / 97 / 78 / 24 | 100 / 100 / 83 / 47 / 5 | 3,0 / 3,9 / 3,6 | 19 / 13 / 10 | 96 / 100 |
| Difícil | los 4 (co-op 4) | 100 / 100 / 100 / 95 / 34 | 100 / 100 / 97 / 45 / 5 | 3,1 / 3,8 / 3,8 | 17 / 11 / 9 | 96 / 99 |

**Qué pasaría si** (200 corridas; pares, pisos 3 / 4 / 5):

| Caso | Normal | Difícil |
|---|---|---|
| juego-41 (publicado) | 72 / 66 / 49 | 71 / 57 / 25 |
| sin Obras defensivas (`towers` = false; el Hierro va a Talleres) | 71 / 62 / 48 | 67 / 56 / 30 |
| el jefe siempre lejos de las Obras (`boss_near` 0) | 52 / 42 / 27 | 50 / 35 / 14 |
| el jefe siempre junto a las Obras (`boss_near` 1) | 90 / 87 / 72 | 91 / 80 / 41 |
| Catapulta investigada (18 Saber + Scriptorium) | 62 / 52 / 36 | 59 / 43 / 16 |

**Lectura.**
- **El piso 3 en Difícil no es una pared en el modelo actual: 71 % para los pares** (64 % antes de esta sesión, 62 % publicado en juego-30). El «0-2 %» era la tabla de juego-23/24, antes de juego-28 (jefes sin los multiplicadores de Difícil), juego-29 y juego-30. No hace falta palanca: no se corrió el barrido de palancas.
- La suba (+5 a +15 puntos en los pisos 3-5) viene casi toda de **curarse antes de la extracción y de las recompensas de sala**: sin Obras defensivas da casi lo mismo (71 / 62 / 48). Las Obras sacan el 17-22 % de la vida de los enemigos en el piso 1 y el 9-18 % en los pisos 3-5, pero el Hierro que cuestan ya no va a Talleres, y en promedio queda casi igual.
- **Lo que decide es dónde se pelea al jefe**: lejos de las Obras, Difícil cae al 50 %; junto a ellas sube al 91 %. `BOSS_NEAR_TOWERS` = 0,5 sigue siendo un supuesto sin datos de gente.
- **La Catapulta no conviene en el modelo** (−10 puntos): cuesta 18 Saber, pide un Scriptorium en el piso (ocupa la sala de una Ballesta) y vale 8 de Hierro contra 4. Con 2-3 enemigos por oleada, su golpe en área apenas pasa a la Ballesta.
- **Los saqueadores casi no tocan la Reliquia en la extracción** (le queda 96-100 %). Los matan rápido porque van al portador, que pelea con el grupo. No se modela la Reliquia tirada en la sala inicial mientras el grupo explora (ahí los saqueadores llegan sin oposición).
- **La sala de Descanso no aporta nada**: cura a 0,5 Comida por punto y el retrato a 0,15 (`UpgradeConfig.heal_cost_per_hp`), así que el jugador de referencia nunca la usa. Resuelto en juego-42: la sala cura gratis (ver «La sala de Descanso gratis»).
- Sigue sin modelar: los enemigos más fuertes de las salas Élite (`enemy_hp_mult` / `enemy_damage_mult`), el Brasero (frena) y los rompe-torres que tiran Obras.

**Calibración con la ventana real** (`tests/tools/shot_jefe.gd`, piso 3, Guerrero + Mago de nivel 2 con vida llena, una Ballesta en la sala; capturas en `capturas/juego-41/`): `ballesta`, el jefe muere a los 9 s y el Guerrero queda con 4 (modelo: 5); `esquiva_ballesta`, Guerrero 18 y Mago 6 (modelo: 17 y 5). Es la misma pelea que en juego-24: la fórmula de `_boss_fight` no cambió, solo de dónde sale el DPS de las Obras.

`test_balance` (50 corridas): umbrales nuevos. Normal pares ≥ 62 / 55 / 38 % en los pisos 3 / 4 / 5 y piso 3 ≤ 85 %; los 4 en co-op Normal piso 5 ≤ 90 %; Difícil pares piso 3 ≥ 55 %, piso 4 entre 40 y 70 % y piso 5 ≤ 35 %. `_check_run_towers` agrega: en Difícil, el jefe junto a las Obras gana > 20 puntos más que lejos de ellas; con torres las Obras sacan > 5 % del daño (0 sin torres); la vida de la Reliquia al final está en (0, 1]. `_check_obras_model` nuevo comprueba que una Ballesta a oscuras no tira, que el área de la Catapulta crece con la oleada, que los Pinchos funcionan a oscuras, el segundo precio de `BuildingCostCurve`, y que en una pelea de saqueadores del piso 3 dos Ballestas con Pinchos se llevan el daño y salvan la Reliquia y al héroe.

## La sala de Descanso gratis (session juego-42)

**Cambio de juego.** La sala de Descanso cura 2 de vida por segundo de juego a cada héroe herido que está dentro, **sin gastar Comida** (`heal_food_per_tick` 1 → 0 en `default_floor_config.tres`). Ahora no cura si hay un enemigo vivo en la sala ni durante la extracción (`FloorManager.rest_tick`). Antes cobraba 0,5 Comida por punto de vida y el retrato 0,15, así que no tenía uso. Ahora el retrato es la cura inmediata que cuesta Comida y la sala de Descanso la cura gratis que pide tiempo y una sala sin enemigos.

**Modelo.** `BOSS_PLAY.rest_first` (por defecto true): con `heal` = "comida", antes del jefe y antes de la extracción el grupo descansa gratis si se reveló una sala de Descanso, y después paga el retrato por lo que falte. No se modela el tiempo de ir hasta la sala ni lo que pasa mientras tanto (amenaza, saqueadores contra la Reliquia tirada). "Antes" = `{"rest_first": false}`, igual al modelo de juego-41.

Barrido `tests/tools/sweep_juego41.gd` (200 corridas; CSV en `docs/balance/juego42_antes_runs.csv` y `juego42_despues_runs.csv`):

| Dificultad | Grupo | Victoria 1/2/3/4/5 (%), antes | después |
|---|---|---|---|
| Normal | pares | 100 / 100 / 72 / 66 / 49 | 100 / 100 / 73 / 68 / 55 |
| Normal | tríos (co-op 3) | 100 / 100 / 100 / 93 / 66 | 100 / 100 / 100 / 95 / 72 |
| Normal | los 4 (co-op 4) | 100 / 100 / 100 / 100 / 83 | 100 / 100 / 100 / 100 / 85 |
| Difícil | pares | 100 / 100 / 71 / 57 / 25 | 100 / 100 / 73 / 63 / 32 |
| Difícil | tríos (co-op 3) | 100 / 100 / 97 / 78 / 24 | 100 / 100 / 98 / 83 / 30 |
| Difícil | los 4 (co-op 4) | 100 / 100 / 100 / 95 / 34 | 100 / 100 / 100 / 96 / 34 |

**Lectura.**
- La suba aparece en los pisos 4 y 5 (+2 a +7 puntos). Ahí es donde se acaba la Comida: con la sala de Descanso, la Comida que antes iba al retrato queda para niveles y reanimar. En los pisos 1-3 casi no cambia, porque ya sobraba Comida para curarse.
- Difícil pares piso 5: 25 → 32 %. Los 4 en Difícil no cambian (34 %): con cuatro héroes la Comida no es lo que falta.
- Una sala de Descanso aparece con chance 0,6 por piso (cupo 1). Sin ella, el modelo es el de antes.
- `test_balance` no necesitó umbrales nuevos (Normal pares 75 / 70 / 56, Difícil pares 69 / 61 / 30, todo dentro). `_check_obras_model` agrega que una cura gratis llena la vida con 0 de Comida (`_heal_with_food` con `per_hp` 0 no curaba nada si no quedaba Comida).

**Pendiente de playtest:** que un jugador de verdad vuelva a la sala de Descanso antes del jefe o de la extracción, y si 2 de vida/s es lento o rápido con los enemigos que entran a la sala.

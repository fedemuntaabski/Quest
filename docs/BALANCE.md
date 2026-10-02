# BALANCE.md — session/balance-4

Balance de héroes, enemigos, pisos y Nexo con **evidencia reproducible**. Todos los números salen del
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
| 4 | El Nexo da tiempo de reaccionar pero cae si se ignora | 1 saqueador lo destruye en 15-45 s; 3 en ≥ 6 s | alerta (borde rojo) + ~1,4 s por sala para llegar = ventana de reacción |
| 5 | Roles distintos, ninguno estrictamente mejor | ningún héroe ≥ en (vida efectiva, DPS, rango) y > en alguno, a nivel 0 y 5 | cada uno gana en un eje y pierde en otro |

## Modelo (qué mide el simulador)

- El AoE del héroe golpea a todo enemigo en rango cada `interval`. Timer libre: el primer golpe cae en un punto
  uniforme del intervalo, así que el enemigo está expuesto `(golpes − 0,5) × intervalo` en promedio.
- El enemigo golpea por contacto cada 1,0 s (`Enemy.CONTACT_HIT_INTERVAL`). El daño es la esperanza (sin redondear a ticks).
- *Encuentro* = la oleada de invasión del piso en el turno 5 (`1 + ⌊5/5⌋ + extra_por_piso`: antes 2, 2, 3, 3, 4 enemigos; ahora 2, 2, 2, 3, 3),
  todos a la vez en rango; se promedia por el peso del pool del piso. Un héroe, sin torres ni segundo héroe (peor caso).
- Nivel del héroe en el piso *f* = *f* − 1 (un nivel comprado por piso; el máximo de la run es 5).
- Saqueador → Nexo: llegada = camino de salas hasta la sala inicial (30 semillas × `MapGenerator`) / velocidad, solo desde
  salas donde puede aparecer (≥ `raider_min_arrival_sec`); destrucción = `⌈vida_nexo / daño⌉ × 1 s`.
- Pasivas incluidas: solo las siempre activas (Piel de Hierro −20 %). Muro Viviente (solo cerca del Nexo) no cuenta: conservador.
  Las activas se reportan aparte (`active_dps`, `active_ehp`: promedio con el uptime duración/enfriamiento).

## Héroes (nivel 0)

| Héroe | Rol | Vida | Daño | Intervalo | DPS | Rango | Vida efectiva |
|---|---|---|---|---|---|---|---|
| Guerrero | Bruiser: pega fuerte y lento, aguanta con Piel de Hierro | 22 → **26** | 3 → **4** | 1.0 → **1.2** | 3.0 → **3.33** | 160 → **150** | 22.0 → **32.5** |
| Mago | Alcance largo, frágil; economía (Ciencia) | 20 → **18** | 3 → **3** | 1.0 → **0.9** | 3.0 → **3.33** | 160 → **220** | 20.0 → **18.0** |
| Pícaro | DPS rápido de golpes chicos, corto alcance; economía (Polvo) | 20 → **18** | 3 → **2** | 1.0 → **0.5** | 3.0 → **4.0** | 160 → **130** | 20.0 → **18.0** |
| Tanque | Mucha vida, poco DPS; protege al grupo y al Nexo | 32 → **40** | 3 → **3** | 1.0 → **1.3** | 3.0 → **2.31** | 160 → **170** | 32.0 → **40.0** |

Nivel 5 (todas las mejoras; `hp +4`, `daño +1`, `intervalo −5 %` por nivel, mínimo 0,3 s — antes −10 % y mínimo 0,2 s):

| Héroe | Vida | DPS | DPS con activa | Vida efectiva | Vida efectiva con activa |
|---|---|---|---|---|---|
| Guerrero | 42 → **46** | 16.0 → **10.0** | 11.6 | 42.0 → **57.5** | 57.5 |
| Mago | 40 → **38** | 16.0 → **11.85** | 11.85 | 40.0 → **38.0** | 38.0 |
| Pícaro | 40 → **38** | 16.0 → **18.67** | 20.42 | 40.0 → **38.0** | 38.0 |
| Tanque | 52 → **60** | 16.0 → **8.21** | 8.21 | 52.0 → **60.0** | 66.67 |

Habilidades (números en `resources/abilities/*.tres`; la tecla **Q** lanza la activa de los héroes seleccionados):

| Héroe | Pasiva | Activa (duración / enfriamiento) |
|---|---|---|
| Guerrero | Piel de Hierro: −20 % de daño recibido | Grito de Guerra: aliados en su sala +50 % de daño (8 s / 25 s) |
| Mago | Mente Analítica: +2 Ciencia al descubrir una sala | Sobrecarga de Módulo: torres de su sala ×2 de daño (8 s) y generadores pagan 1 turno extra (30 s) |
| Pícaro | Paso Ligero: +2 Polvo al descubrir una sala | Golpe Furtivo: ×3 de daño a todo enemigo en rango (12 s) |
| Tanque | Muro Viviente: hasta −50 % de daño cerca del Nexo (0 a 640 px) | Interposición: todo el grupo recibe −50 % (6 s / 30 s) |

## Piso 1: golpes para matar (nivel 0)

| Enemigo | HP | Guerrero | Mago | Pícaro | Tanque |
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
| Tanque | 22.7 → **18.9** | 25.0 → **20.7** | 49.1 → **22.5** | 68.2 → **38.6** | 173.8 → **54.0** |

## Nexo: saqueadores (vida del Nexo 100 → **120**)

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
  `module_damage`; −1 = el valor del comportamiento en `Enemy.VARIANT_CONFIG`): permiten afinar sin tocar código, hoy sin usar.
- `resources/floors/default_floor_config.tres`: `enemy_hp_growth` 0,25 → 0,15; `enemy_damage_growth` 0,2 → 0,1; `extra_invasion_enemies_per_floor` 0,5 → 0,34; `nexo_max_hp` 100 → 120.
- `resources/floors/enemy_pool_f4/f5.tres`: pesos de los tipos duros bajados.
- `resources/upgrades/run_upgrade_config.tres`: `attack_speed_per_level` 0,10 → 0,05, `min_attack_interval` 0,2 → 0,3 (el Pícaro, con intervalo 0,5, escalaba sin techo).
- Código mínimo para que "solo `.tres`" sea cierto: `TurretModule` lee daño/cadencia de `Module.CATALOG` (antes el catálogo solo era texto y divergía del export),
  la ralentización de la trampa lee `slow_factor` del catálogo (antes 0,5 fijo).
- `tools/build_characters.gd`: tablas sincronizadas (re-ejecutarlo pisa los `.tres` de enemigos: no hornea roles ni campos base).

## Pendiente de playtest

- El modelo es un héroe solo sin torres; en partida hay 2 héroes, torres, trampas, salas Rest y curación: la dificultad real será menor. Confirmar que el piso 5 sigue siendo tenso.
- **Pícaro a nivel alto**: 18,7 DPS a nivel 5 frente a 8-12 de los demás (daño plano +1 por nivel sobre base 2). Si domina, bajar `damage_per_level` o subir su `attack_interval` base.
- Saqueadores: la ventana de reacción depende del mapa (llegada mínima ~4,6-5,1 s); revisar con partidas reales si 20-30 s para destruir el Nexo alcanzan para volver.
- Muro Viviente solo actúa cerca del Nexo: comprobar que se siente (no entra en la simulación).
- Tres saqueadores del piso 5 destruyen el Nexo en 7 s: comprobar que no es injusto sin torres cerca.
- La sala Elite (×1,5 vida, ×1,25 daño) no está en el simulador.

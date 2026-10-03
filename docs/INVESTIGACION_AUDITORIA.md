# Auditoría de Investigación y Ciencia

Rama `session/impl-6`. Análisis estático (Read/Grep) contrastado después con Godot headless: `tools/run_tests.sh` completo en verde (incluye los `_check_research*` de `test_hud_ui.gd`), `roundi(4.5) == 5` y costo total del árbol = 97 comprobados con un script. Lo marcado **[NV]** sigue sin verificar (requiere jugar, ver sección 6). Se corrigieron solo I-01 e I-07 (ver sección 5); el resto queda abierto a propósito (no rediseñar todavía).

## Resumen

- La Ciencia tiene 1 sumidero (investigación, 7 entradas, **costo total 97, no 146**) y 4 fuentes: base 1/puerta, Gen. Ciencia (+3/puerta, bloqueado hasta investigar), pasiva del Mago (+2 por sala descubierta) y recompensa de sala Elite (8 +1/piso).
- Los 5 tipos de efecto (UNLOCK_MODULE, GENERATOR_YIELD_PCT, TURRET_DAMAGE, POWER_COST, DISCOVERY_DUST) tienen consumidor real y se aplican donde dice; prerrequisitos e ids son coherentes; el reset por run y la persistencia entre pisos son correctos. No encontré ningún bug ROTO.
- Sin Mago ni Gen. Ciencia, un jugador junta ~90 Ciencia en toda la run (no llega a 97 hasta el final del piso 5); con cualquiera de los dos, el árbol completo se alcanza hacia el piso 3-4; con ambos, hacia el piso 2.
- La primera compra es posible en el turno 0 (se empieza con 10 Ciencia y todo T1 cuesta 6-10), pero nada le dice al jugador que lo primero es "Instrumental arcano"; puede gastar los 10 en algo que no rinde sin generadores.
- Los problemas son de UX: no hay feedback al investigar (ni texto, ni sonido, ni VFX), no hay atajo de teclado, las tarjetas del menú de construcción muestran números base sin el bonus investigado, y el "+N" de Ciencia en el HUD no incluye al Mago ni a las salas Elite.

## 1. Generación de Ciencia

Doors por piso = salas-1 puertas del árbol (+ las de bucles, 0..`max_loops`). `FloorConfig` (`scripts/core/floors/FloorConfig.gd:19-21,116`): 8/9/10/11/12 salas en pisos 1-5 -> 7/8/9/10/11 descubrimientos, 45 en la run. Cada puerta (también las de bucle) llama `open_room` -> `advance_turn` (`DoorTurnSystem.gd:42-54,31-37`).

| Fuente | Cantidad | Condición | Evidencia |
|---|---|---|---|
| Inicial | 10 una sola vez por run (no por piso) | `reset_resources()` desde `Main._begin_new_run` | `ResourceManager.gd:85`, `Main.gd:137` |
| Base por puerta | +1 por puerta abierta (incl. bucles) | siempre | `ResourceManager.gd:18,71-72,80-82`, `DoorTurnSystem.gd:37` |
| Gen. Ciencia | +3 por turno por generador (x(1+bonus) sobre el total del recurso) | investigar `science_generator` (6 Ciencia), 6 Industria, slot MAJOR en sala encendida y `is_working()`. Se pierde al cambiar de piso (módulos son por `Main2d`) | `Module.gd:20`, `ResourceManager.gd:61-66`, `GeneratorModule.gd:18-26` |
| Mago, Mente Analítica | +2 por sala descubierta (+3 con perk Estudio Profundo, nivel 3). No paga en puertas de bucle ni sin Mago en el equipo (2 de 4 héroes) | héroe vivo con la pasiva | `mage_passive.tres:8-9`, `HeroAbilities.gd:105-114`, `FloorManager.gd:62-63,68,75-81`, `estudio_profundo.tres:12-14` |
| Sala Elite | 8 +1 por piso (8/9/10/11/12), una vez al descubrirla | sala tipo ELITE (chance 0.3 +0.1/piso, cupo 1 +floor(0.25*(piso-1))) | `default_floor_config.tres:28-38`, `RoomTypeRule.gd:35-45`, `FloorManager.gd:114-120`, `MapGenerator.gd:124-144` |
| Sobrecarga de Módulo (Mago, activa) | +`yield_amount` (3, sin bonus de investigación) por Gen. Ciencia de la sala, por lanzamiento, cooldown 30 s | lanzar la activa en la sala del generador | `HeroAbilities.gd:208-217`, `mage_active.tres:8-11` |
| Otras | ninguna: no hay Ciencia en items, Loot (da Industria), Pickup ni guardado | | grep `"science"` en `scripts/`, `resources/` |

Estimación de Ciencia acumulada (sin gastar; fin de cada piso). Elite esperada por piso 2.4/3.6/5.0/6.6/16.8 = ~34 en la run (el piso 5 tiene 2 cupos al 70 %); es estimación probabilística **[NV]**. No cuento bucles (+1 Ciencia c/u, máx. ~9 en la run).

| Escenario | Piso 1 | Piso 2 | Piso 3 | Piso 4 | Piso 5 |
|---|---|---|---|---|---|
| A: sin Mago, sin Gen. Ciencia (10 + puertas + Elite) | ~19 | ~31 | ~45 | ~62 | ~90 |
| B: A + 1 Gen. Ciencia en sala de inicio desde el turno 0 de cada piso (+3/puerta) | ~40 | ~76 | ~117 | ~164 | ~225 |
| C: A + Mago (+2/descubrimiento) | ~33 | ~61 | ~93 | ~130 | ~180 |
| D: A + Mago + Gen. Ciencia | muy por encima de 97 desde el piso 2 | | | | |

Notas: la sala de inicio se enciende gratis (`Main2d.gd:262`) y tiene 1 slot MAJOR, que compite con generadores de Industria/Comida; la sala GENERATOR da 2 MAJOR (`RoomTypeRule.extra_major_slots`). El Gen. Ciencia cuesta 6 Industria por piso (hay que reconstruirlo).

## 2. Gasto de Ciencia

Único sumidero: `ResourceManager.research()` (`ResourceManager.gd:125-131`). La subida de nivel de héroe usa Comida (`UpgradeConfig.cost_resource = "food"`, `UpgradeConfig.gd:16`, `PlayerStats.gd:272`); construir usa Industria, encender Polvo. No hay otro uso de Ciencia, así que **pasado el árbol completo la Ciencia no sirve para nada** (incluida la pasiva del Mago).

Árbol (`resources/research/research_config.tres`), 7 entradas, ids únicos, `effect` 0..4 = enum de `ResearchEntry.gd:8-14`:

| id | Nombre | Costo | Prerrequisito | Efecto | Consumidor |
|---|---|---|---|---|---|
| science_generator | Instrumental arcano | 6 | - | UNLOCK_MODULE (module 2 = GENERATOR_SCIENCE) | `ResourceManager.is_unlocked` `:135-138` -> `BuildingMenu.get_lock_reason` `:107-111` |
| turret_plans | Planos de ballesta | 8 | - | UNLOCK_MODULE (module 3 = TURRET) | idem |
| generator_tuning | Engranajes afinados | 10 | - | GENERATOR_YIELD_PCT +0.25 | `ResourceManager._calculate_module_bonus` `:66` (-> `get_turn_yield` `:72`, `process_turn_production` `:82`) |
| dust_lenses | Lentes de polvo | 10 | - | POWER_COST -3 | `RoomZone.get_power_cost` `RoomZone.gd:235-237` |
| cartography | Cartografía | 8 | - | DISCOVERY_DUST +1 | `FloorManager.on_room_discovered` `FloorManager.gd:64` |
| generator_overclock | Sobrecarga | 30 | generator_tuning | GENERATOR_YIELD_PCT +0.25 (acumula: +50 %) | idem generator_tuning |
| turret_rifling | Virotes estriados | 25 | turret_plans | TURRET_DAMAGE +10 | `TurretModule.get_damage` `TurretModule.gd:69-71` |

Total = 6+8+10+10+8+30+25 = **97** (T1 = 42, T2 = 55). El "146" del encargo no coincide con el `.tres` actual.

Alcanzabilidad (ver tabla de la sección 1): A llega a ~90 al final del piso 5 (insuficiente para 97 y además llega tarde); B y C alcanzan 97 hacia el piso 3 (C: borde piso 3-4); D hacia el piso 2. **Primera compra: turno 0** (10 Ciencia iniciales, todo T1 cuesta 6-10, solo cabe una de 8-10 o una de 6 con 4 de sobra). T2 (30 y 25) recién se ve hacia el piso 2-3 sin Mago/Gen.

Rentabilidad aproximada: `cartography` (+7..11 Polvo/piso por 8) y `dust_lenses` (-3 por encendido, 30 %) son baratas y útiles; `generator_tuning` rinde solo con generadores construidos; `generator_overclock` (30) da +1 Ciencia/turno con 1 o 2 generadores del mismo recurso (4->5; 8->9), solo +3 con 3 (11->14), flojo; `turret_rifling` (+10 sobre 15 = +67 %, 33 con su prerrequisito) es razonable.

## 3. Verificación de cada efecto

- **UNLOCK_MODULE (OK).** `get_unlock_entry` (`ResearchConfig.gd:18-22`) busca por `effect==UNLOCK_MODULE and module==...`; `is_unlocked` es true si no hay entrada (Industria/Comida/Trampa nunca bloqueadas). Bloqueo aplicado en: botón "Elegir" deshabilitado (`BuildingMenu.gd:188`), teclas 1-9 (usan los botones, `:327-330`), `_arm` (`:199`), `get_block_reason` (`:92-94`). **Matiz:** `BuildingSlot.build()` (`BuildingSlot.gd:56`) no valida el bloqueo; solo hay una llamada en producción (`BuildingMenu.gd:251`) y pasa por `get_block_reason`, así que hoy no hay rodeo. El test lo cubre (`test_hud_ui.gd:237-243`).
- **GENERATOR_YIELD_PCT (OK, con redondeo).** `roundi(total * (1+bonus))` se aplica a la **suma** de generadores *de ese recurso* y no a la base (`ResourceManager.gd:61-66`), nunca da 0 extra con total > 0: 1 gen (3): +25 % -> 3.75 -> **4** (+1, es +33 %), +50 % -> 4.5 -> **5** (+67 %) (`roundi` redondea .5 hacia arriba **[NV]**, el test `test_hud_ui.gd:313-314` asume 4 y 5). 2 gens (6): 8 y 9. Los dos tiers suman (`get_bonus` suma `value`, `:141-146`). El número del HUD (`get_turn_yield` + `production_changed` emitido en `research()` `:130`) coincide con lo que paga el turno. Excepción menor: el extra de Sobrecarga de Módulo (`HeroAbilities.gd:217`) usa `yield_amount` sin bonus.
- **TURRET_DAMAGE (OK).** `get_damage()` se lee en cada disparo, así que alcanza a torretas ya construidas; el bonus se suma antes de `damage_mult` (Sobrecarga del Mago x2 lo duplica también). Test cubre 15 -> 25 (`test_hud_ui.gd:326-329`).
- **POWER_COST (OK).** Piso mínimo 1 (`maxi(1, ...)`, `RoomZone.gd:237`; el comentario `ResearchEntry.gd:12` "(floor 1)" significa "mínimo 1", ambiguo con "piso 1"). Texto del hint "Clic central: encender (N Polvo)" se actualiza por `research_changed` (`EnergyButton.gd:17,21-22`; la escena trae "10 Polvo" fijo, `EnergyButton.tscn:22`, solo hasta `_ready`). El contorno dorado "alcanzable" usa `get_power_cost()` y se refresca (`RoomLight.gd:54,90,97`). Cobra el costo vigente y lo guarda (`:247,253`); apagar devuelve `_power_paid`, es decir lo realmente pagado, no el costo actual (`:263-264`): sin exploit de comprar la mejora para ganar polvo. Test: `test_hud_ui.gd:296-303`. El tooltip del chip de Polvo (`HUDController.gd:7`) no menciona el costo (no estaba afectado).
- **DISCOVERY_DUST (OK).** `config.discovery_dust(piso) + roundi(bonus)` (`FloorManager.gd:64`); no corre para corredores de bucle (`:62-63`). Test `test_hud_ui.gd:333-340`.
- **Prerrequisitos:** `generator_overclock` -> `generator_tuning` (10 < 30) y `turret_rifling` -> `turret_plans` (8 < 25), ambos existen; el test exige prerrequisito existente y más barato (`test_hud_ui.gd:203-206`). Bloqueo mostrado como "Requiere: <nombre>" (`ResourceManager.gd:112-114`). Sin ids duplicados ni entradas sin consumidor (los 5 efectos tienen uno). Campo `module` sin uso en entradas no-UNLOCK (inocuo).
- **Ciclo de vida:** `reset_research()` en `Main._begin_new_run` junto a `reset_resources` (`Main.gd:137-138`); no se llama al avanzar de piso, así que la investigación sobrevive (`test_hud_ui.gd:173-195`). **No se guarda** (`SaveManager` no menciona research/science), igual que el resto de los recursos; coherente con "sin persistencia". Multijugador: el autoload es local, no hay sincronización **[NV]**.

## 4. Experiencia del jugador

Qué hay:
- Botón "Investigar" (`HUD.tscn:222-225`, tooltip "Investigaciones pagadas con Ciencia") que abre `ResearchPanel` acoplado sobre la barra inferior (`HUDController.gd:144-156`), cierra el menú de construcción y viceversa (`:106,109,155`).
- Cada tarjeta: "T1/T2 · nombre", efecto (`describe_effect`), costo con icono de Ciencia, estado (Disponible / Falta Ciencia / Requiere: X / Investigada) y botón; descripción narrativa solo en tooltip (`ResearchPanel.gd:84-132`). Tarjetas no disponibles en 60 % de opacidad. El panel se refresca solo al cambiar Ciencia o investigación.
- Cierra con Esc y clic derecho, consumidos (`ResearchPanel.gd:160-167`); funciona con `Engine.time_scale` 0 (Controls).
- Tooltip del chip de Ciencia explica el uso (`HUDController.gd:6`); el candado + "Requiere: <investigación>" aparece en tarjetas, tooltip y texto flotante del ghost (`BuildingMenu.gd:107-111,151-155,167`).

Qué falta o confunde:
- **Sin feedback al investigar** (corregido, ver I-01): `research()` / `_on_research_pressed` no emiten texto flotante, toast, sonido ni VFX; lo único que cambia es la tarjeta y el número de Ciencia (`ResearchPanel.gd:144-147`, `ResourceManager.gd:125-131`). Un sonido genérico de clic de botón podría existir en el tema **[NV]**.
- **Sin atajo de teclado** para abrir el panel (no hay acción en `project.godot`; solo existen `hero_cycle`, `tactical_pause`...). Sin insignia/aviso cuando hay algo comprable.
- **No dice qué investigar primero**. El orden del `.tres` pone los dos desbloqueos primero, pero en la grilla de 2 columnas los T2 no quedan junto a su prerrequisito (`COLUMNS=2`, `ResearchPanel.gd:13`: fila 3 = cartography + overclock, fila 4 = rifling). "Falta Ciencia" no indica cuánta falta. Nada avisa que `generator_tuning` no sirve sin generadores.
- **Descubribilidad de la fuente de Ciencia**: Gen. Ciencia bloqueado dice "Requiere: Instrumental arcano" pero no su costo ni que se compra en "Investigar"; el tooltip del chip no dice cómo ganar más Ciencia (generador, Mago, salas Elite).
- **Números desactualizados en construcción**: tarjetas y tooltips usan `Module.describe_effect` base ("+3 Ciencia por turno", "15 de daño cada 1.0 s", `Module.gd:55-65`, `BuildingMenu.gd:136,167`); no reflejan +25 %/+50 % ni +10 de daño.
- **El "+N" verde del HUD** es `get_turn_yield` (base + generadores, `HUDController.gd:370-375`); no incluye la pasiva del Mago ni la recompensa Elite, y la Ciencia del Mago no tiene texto flotante propio (la de Elite sí, `FloorManager.gd:119`).
- **Reconstrucción del panel en cada cambio de Ciencia** (`ResearchPanel.gd:155-157`): si llega un tick (puerta, Mago) mientras el mouse está sobre "Investigar" o con el botón presionado, la tarjeta se recrea (parpadeo de tooltip, clic perdido) **[NV]**. En pausa táctica no hay ticks.
- **Tamaño del panel**: 7 tarjetas en 4 filas sobre la barra inferior; puede tapar parte del mapa/minimapa **[NV]**.
- El Mago promete "Acelera la investigación" (`mage.tres:20,27`): coherente (+2/descubrimiento), pero sin indicación en partida.

## 5. Hallazgos

Severidades: ROTO = bug claro con fix pequeño; CONFUSO = UX; BALANCE = números; DUDA = requiere ejecutar. **ROTO: ninguno.** Aplicados: I-01, I-07. Abiertos (sin rediseñar): I-02..I-06, I-08..I-13.

| id | Sev. | Evidencia | Fix mínimo (no aplicado) |
|---|---|---|---|
| I-01 | CONFUSO · **corregido** | `ResourceManager.gd:125-131`, `ResearchPanel.gd:144-147`: investigar no da feedback | Aplicado: `ResearchPanel._on_research_pressed` muestra `HUDController.show_hint("Investigado: X", efecto)` (cubierto en `test_hud_ui.gd`). Falta sonido/VFX |
| I-02 | CONFUSO | `ResearchPanel.gd:84-132`, `HUDController.gd:6`: nada orienta el primer gasto ni explica dónde ganar Ciencia | Resaltar/ordenar `science_generator` primero con texto "Recomendado" y ampliar tooltip de Ciencia con las fuentes |
| I-03 | CONFUSO | `BuildingMenu.gd:136,167`, `Module.gd:55-65`: tarjetas sin bonus de investigación | `describe_effect` opcional con bonus (usar `get_bonus` para generadores y turret) |
| I-04 | CONFUSO | `HUDController.gd:370-375`: "+N" no incluye Mago/Elite | Documentarlo en el tooltip del chip o sumar `passive_discovery_bonus` esperado |
| I-05 | CONFUSO | `ResearchPanel.gd:13,73-81`: T2 lejos de su prerrequisito; sin atajo ni aviso de "comprable" | Acción de input (p. ej. R) + punto en el botón cuando `can_research` de alguna entrada |
| I-06 | CONFUSO | `ResearchPanel.gd:154-157`: rebuild total por cada cambio de Ciencia | Actualizar tarjetas en lugar de recrearlas, o ignorar si el mouse está sobre una tarjeta |
| I-07 | CONFUSO · **corregido** | `ResearchEntry.gd:12`: comentario "(floor 1)" ambiguo | Aplicado: "(never below 1)" en `ResearchEntry.gd` |
| I-08 | BALANCE | `ResourceManager.gd:18`, sección 1: sin Mago ni Gen. Ciencia la run da ~90 Ciencia (< 97) y T2 llegan al piso 4-5 | Subir base a 2, o abaratar T2 (30/25), o inicial 15 |
| I-09 | BALANCE | Costo total 97 vs. A/B/C/D: Gen. Ciencia (6+6) o Mago vuelven el árbol trivial hacia el piso 2-3; la Ciencia sobrante no tiene otro uso | Segundo sumidero (p. ej. más nodos T3) o reducir el rendimiento del generador |
| I-10 | BALANCE | `default_floor_config.tres:35`, `RoomTypeRule.gd`: el piso 5 tiene 2 cupos Elite al 70 % = 12-24 Ciencia (casi la mitad del ingreso de la run) | Revisar `max_count_per_floor` o `reward_per_floor` de Elite |
| I-11 | BALANCE | Con 1-2 generadores, `generator_overclock` (30) da +1 Ciencia/Industria/Comida por turno (`roundi`, `ResourceManager.gd:66`) | Bajar costo o subir `value` |
| I-12 | BALANCE | `HeroAbilities.gd:217`: el extra de Sobrecarga de Módulo ignora el bonus de investigación | Multiplicar por `1+get_bonus(GENERATOR_YIELD_PCT)` si se quiere coherencia |
| I-13 | DUDA | Multijugador Steam: el estado de investigación vive en el autoload local, sin sincronización | Decidir si es por jugador o compartido |

## 6. No verificado sin ejecutar

- (Verificado) Los tests de `tests/test_hud_ui.gd` (`_check_research`, `_check_research_lifetime`), `test_abilities.gd`, `test_perks.gd` y `test_party.gd` pasan hoy (runner completo, 0 fallos). Cubren: bloqueos, prerrequisitos, panel a `time_scale` 0, Esc/clic derecho, costo 7 de encendido y su devolución, bonus de generadores (4 y 5), turret 15 -> 25, cartografía, vida entre pisos y reset en Retry, Mente Analítica +2 y +3 con perk. **No cubren**: sonido al investigar, reflejo del bonus en las tarjetas de construcción, la recompensa Elite en Ciencia, ni que el panel quepa en pantalla.
- (Verificado: `roundi(4.5) == 5`, `roundi(3.75) == 4`, costo total 97.) Comportamiento exacto del panel (rebuild con mouse encima, tamaño/solapamiento a distintas resoluciones, tooltips).
- Las cifras esperadas por piso (Elite, bucles, sala GENERATOR) dependen de la generación aleatoria; son estimaciones, no medidas. Las tablas B-D suponen 1 Gen. Ciencia siempre vivo desde el turno 0 en la sala de inicio y que el Mago esté en el equipo.
- Sonido genérico de botones/UI, VFX o toasts globales que pudieran dispararse al pulsar "Investigar" sin código propio.
- Sincronización en red de la investigación.

## Actualización session economia-8
- `science_generator` y `turret_plans` pasan a `ModuleResearch` (`ballesta`; nuevos `brasero`, `catapulta`, con `tier`). Investigar exige un Scriptorium construido y activo (cierra parte de I-02: ahora la Ciencia tiene un primer paso claro, "Construí un Scriptorium").
- I-08 / I-09: sin `science_generator` (6 de Ciencia) y con 3 módulos en lugar de 2 el total sube a 115; la Ciencia sigue sobrando al final (ver `docs/BALANCE.md` "Economía"). Sin cambios en I-03..I-07 y I-10..I-13.

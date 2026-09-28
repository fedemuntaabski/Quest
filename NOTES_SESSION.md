# Session notes — 2026-09-27 (branch `session/opus-2026-09-27`, from `feature/td-module-effects`)

No Godot binary in environment → nothing executed in-engine. Everything below verified by reading code only.

## Fase 1 — Diagnóstico

**Funciona (según código, sin verificar en editor):**
- Shell: menú, slots de guardado, selección de personaje, Steam host/join, orquestador `Main.tscn`.
- Mapa: grafo fijo de 9 zonas (`Main2d.LAYOUT`), fog-of-war por grupo, puertas que avanzan turno.
- Economía: 4 recursos, tick por puerta + bonus de Generators.
- Energizar sala (Dust) → 3 slots → módulos (Generator/Turret/Trap) vía `BuildingMenu`.
- Nexo → fase de extracción (puertas bloqueadas, oleadas cada 5s) → victoria en `vault_room`.
- Enemigos (Swarm/Sapper/Hunter) spawnean por riesgo en salas oscuras, navegan el grafo, Sappers rompen módulos, Turrets les disparan.
- Muerte: `CharacterStats.died` → `PlayerStats.player_died` → `Main2d._on_player_died` → overlay. HUD HP ligado a `hp_changed`.

**Roto / falta para el core loop (explorar → combate → progresión):**
1. **No hay combate héroe↔enemigo.** Swarm/Hunter persiguen al héroe pero al llegar no hacen nada; el héroe no ataca. Nada llama nunca `CharacterStats.take_damage` → la derrota es inalcanzable y los enemigos no son amenaza. Es el hueco más grande del loop.
2. No hay progresión de piso: la victoria termina la run; no hay "siguiente piso" ni generación de mazmorra (layout hardcodeado).
3. Stats de enemigos hardcodeados en `Enemy.VARIANT_CONFIG` (dict), no en Resource `.tres`.
4. Turret daña vía chequeo ad-hoc (`body.has_method("take_damage")`), no vía componente reutilizable.
5. Comida/Ciencia no tienen sumidero (sin uso en gameplay).
6. Orden de eventos en `DoorTurnSystem.open_room`: `turn_advanced` antes de `room_revealed` (ya anotado en `HANDOFF_ROOM_CORE_M2.md`).

**Convenciones del proyecto (respetadas):** `class_name` por script, lookups vía `ManagerLocator`, `QuestLogger` en vez de `print`, HP block propio por entidad (no base class compartida), managers escena-instanciados (no autoloads) para estado de run, input 100% `Area2D.input_event`, comentarios `##` de cabecera, texto de UI en español.

## Fase 2 — Priorización

| # | Tarea | Impacto | Costo | Decisión |
|---|-------|---------|-------|----------|
| 1 | Combate héroe↔enemigo con `HitboxComponent`/`HurtboxComponent` reutilizables; stats de combate del héroe en `CharacterData` (.tres) | Alto: habilita amenaza + derrota | Bajo-medio | **Hecha** |
| 2 | Migrar Turret a `HitboxComponent` (borra chequeo ad-hoc) | Medio: unifica daño | Bajo | Descartada esta sesión: Turret ya funciona y dispara a *un* objetivo (semántica distinta de área continua); cambiarla ahora arriesga regresión sin editor para probar |
| 3 | `EnemyStats` Resource + 3 `.tres` reemplazando `VARIANT_CONFIG` | Medio: data-driven | Medio | Descartada: refactor sin cambio de gameplay; mejor después de balancear combate |
| 4 | Progresión de piso (tras victoria → siguiente piso con dificultad escalada) | Alto | Alto (necesita generador o varios layouts) | Descartada: no cierra en 25 min sin generador |
| 5 | Sumidero para Comida (curar héroe) | Bajo-medio | Bajo | Descartada: depende de que exista daño (tarea 1) → siguiente sesión |

**Por qué la 1 primero:** es el único hueco que deja el loop sin tensión (no se puede perder, enemigos inofensivos para el héroe). Además crea el sistema base reutilizable (Hitbox/Hurtbox) que las tareas 2 y futuras (habilidades, trampas de daño) usan.

## Fase 3 — Implementado

| Sistema | Archivo | Cambio |
|---|---|---|
| Combate (nuevo) | `scripts/core/combat/HurtboxComponent.gd` | `Area2D` pasiva, emite `hurt(amount)`; sin HP propio |
| Combate (nuevo) | `scripts/core/combat/HitboxComponent.gd` | `Area2D` que daña a todos los Hurtbox solapados cada `hit_interval` (Timer interno); `configure()`; señal `hit_landed` |
| Física | `project.godot` | `[layer_names]`: 2 `enemy_body`, 3 `player_hurtbox`, 4 `enemy_hurtbox` |
| Héroe | `scripts/core/stats/CharacterData.gd` | `@export_group("Combat")`: `attack_damage=3`, `attack_interval=1.0` (los 4 `.tres` usan defaults) |
| Héroe | `scripts/core/player/Player.gd`, `scenes/Player.tscn` | Nodos `Hurtbox` (r20, layer 4) y `Hitbox` (r160, mask 8); `_on_hurt` → `CharacterStats.take_damage` + log COMBAT |
| Enemigo | `scripts/entities/Enemy.gd`, `scenes/entities/Enemy.tscn` | Nodos `Hurtbox` (r14, layer 8) → `take_damage`; `Hitbox` (r24, mask 4) con `contact_damage` por variante (Swarm 2 / Sapper 1 / Hunter 3), 1 tick/s |
| Docs | `CLAUDE.md` | Sección "Hero↔enemy combat" |

Commits: `d21a540` notes → `feat(combat)` componentes → héroe → enemigo → docs.

## Checklist manual (editor, F5 desde `Main.tscn`)

1. Abrir proyecto: sin errores de parseo en Output (en particular `Player.gd`, `Enemy.gd`, los 2 componentes nuevos).
2. Project Settings → Layer Names → 2D Physics: ver `enemy_body` / `player_hurtbox` / `enemy_hurtbox`.
3. Debug → Visible Collision Shapes ON. Jugar offline: héroe muestra círculo chico (hurtbox) + grande ~1 sala (hitbox).
4. Abrir puertas hasta que haya invasión (flash rojo). Un Swarm llega a la sala del héroe:
   - HUD HP baja ~2/s por Swarm; log `Hero took 2 damage (...)`.
   - El Swarm muere en ~2 s (6 HP / 3 dmg/s); log `Enemy 'SWARM' died...`.
5. Dejar que varios enemigos lleguen sin moverse → HP a 0 → overlay de muerte (Retry/Exit funcionan).
6. Enemigo en el pasillo contiguo (~256 px) NO debe recibir daño del héroe ni dañarlo.
7. Regresión: Turret sigue disparando a enemigos; Sapper sigue rompiendo módulos; Nexo/extracción/victoria sin cambios.
8. Inspeccionar `resources/characters/warrior.tres`: grupo "Combat" editable en el Inspector.

## Riesgos / decisiones a revisar antes de mergear

- **Daño AoE del héroe (radio 160):** golpea a *todos* los enemigos de la sala a la vez. Coherente con DotE (héroe defiende su sala) pero fuerte contra swarms. Alternativa: pegar solo al primero (`break` tras el primer hit) → un parámetro más.
- **Balance a ojo:** 3 dmg/s héroe, 1-3 dmg/s por enemigo, héroe 20-22 HP. Sin playtest.
- **Contact damage en `VARIANT_CONFIG` (dict), no `.tres`:** seguí la convención existente del archivo; la migración a Resource es la tarea 3.
- **Hero root sigue siendo `Node2D`** (no `CharacterBody2D`): no hace falta física de cuerpo (se mueve por tween); cambiarlo tocaba muchas cosas sin beneficio ahora.
- **Sin feedback visual de golpe** (solo log + barra HP). `FloatingTextManager` existe y podría colgarse de `hit_landed`.
- `CharacterStats.take_damage` emite `died` en cada golpe con HP ya en 0 → lo filtra `Player._on_hurt` (`is_alive()`), y `Main2d` ya tenía guard `_is_dead`.
- Nada fue ejecutado: sin binario de Godot en el entorno.

## Pendiente / próximos pasos

1. Playtest con el checklist; ajustar radios/daño. Agregar floating damage text vía `hit_landed` + `FloatingTextManager`.
2. Tarea 3: `EnemyStats` Resource (`hp`, `speed`, `contact_damage`, ...) + 3 `.tres`, reemplazando `VARIANT_CONFIG`; luego tarea 2 (Turret sobre `HitboxComponent` con modo "single target").
3. Sumidero de Comida (curar héroe en sala energizada) y después progresión de piso (tarea 4), que necesita generador de layout o varios `LAYOUT` rotativos.

---

# Sesión 2 — 2026-09-27 (branch `session/opus-2026-09-27-2`, from `session/opus-2026-09-27`)

Verificación: `gdtoolkit` instalado en venv temporal (el pip global falló por lock de `gd2py.exe`); `gdparse` corre sobre cada `.gd` tocado. Sigue sin binario de Godot.

## Fase 1 — Diagnóstico

**Auditoría combate sesión 1:** `gdparse` OK en los 5 scripts. Layers/masks coherentes (hero hurtbox L3=4 ↔ enemy hitbox mask 4; enemy hurtbox L4=8 ↔ hero hitbox mask 8; Turret `DetectionZone` mask 2 solo ve el cuerpo del enemigo). `hurt` conectado en `_ready()` en ambos. ext_resource/sub_resource ids únicos en `Player.tscn`/`Enemy.tscn`. Sin bugs encontrados.

**Bug bloqueante nuevo (preexistente, no de la sesión 1):** `ResourceManager.reset_resources()` no tiene ningún caller → la run arranca con los 4 recursos en 0. Dust no se genera nunca (`BASE_YIELD_DUST = 0`, ningún generator de dust) y energizar cuesta 10 → **es imposible energizar salas, y por ende construir Turrets/Generators**. Además, al ser autoload, Retry arrastra los recursos de la run anterior. → Se arregla dentro de la tarea D: el orquestador resetea recursos al empezar run nueva.

## Fase 2 — Priorización (sesión 2)

| Tarea | Decisión | Motivo |
|---|---|---|
| Fix 0-dust (bloqueante) | **Hecha** | Sin ella nada de energizar/construir funciona; cae naturalmente en el límite de run que D necesita |
| D. Progresión de piso | **Hecha (completa)** | Cierra el loop entre pisos |
| A. Floating damage text | **Hecha** | Barata; único feedback de combate que faltaba |
| B. `EnemyStats` .tres | Descartada | Refactor sin cambio de gameplay; el escalado por piso ya multiplica sobre `VARIANT_CONFIG`, migrar después no rompe nada |
| C. Comida cura | Descartada (tiempo) | Necesita decidir disparador/UI (auto por puerta vs botón); mejor con playtest del combate |
| E. XP héroe | Descartada | Se superpone con el HP-upgrade store existente; diseño abierto |

## Fase 3 — Implementado (sesión 2)

| Sistema | Archivo | Cambio |
|---|---|---|
| Pisos (nuevo) | `scripts/core/floors/FloorConfig.gd`, `resources/floors/default_floor_config.tres` | Resource con escalado lineal por piso (HP/daño enemigo, chance/cantidad de invasión, intervalo de oleadas de extracción, `max_floors=5`, `dust_bonus_on_descend=10`) |
| Pisos (nuevo) | `scripts/managers/FloorManager.gd` | Fachada por-`Main2d` (grupo `floor_manager`), `floor_index`, `floor_completed`, `is_final_floor()`, bonus de dust al descender |
| Orquestador | `scripts/managers/Main.gd` | `current_floor`, `advance_floor()`, `_begin_new_run()` (reset recursos + piso 1) en `start_gameplay`/`reload_gameplay` |
| Locator | `scripts/managers/ManagerLocator.gd` | `get_floor_manager()` |
| Gameplay | `scripts/managers/Main2d.gd`, `scenes/Main2d.tscn` | Crea `FloorManager`; lo pasa a Enemy/Extraction; `victory_declared → complete_floor`; `NextFloorButton` en `VictoryOverlay` |
| Enemigos | `scripts/managers/EnemyManager.gd`, `scripts/entities/Enemy.gd` | `setup(..., floor_manager)`; chance/cantidad escaladas; `configure(..., hp_mult, dmg_mult)` escala HP, contact damage y daño a módulos |
| Extracción | `scripts/managers/ExtractionManager.gd` | `setup(..., spawn_interval)` |
| HUD | `scenes/HUD.tscn`, `scripts/ui/hud/HUDController.gd` | `Control/FloorLabel` "Piso N/M" |
| Combate | `scripts/core/combat/HitboxComponent.gd`, `scenes/entities/Enemy.tscn` | Números flotantes en `hit_landed` (amarillo héroe→enemigo, rojo enemigo→héroe) |
| Docs | `CLAUDE.md`, `NOTES_SESSION.md` | Secciones Floor progression / API del orquestador |

`gdparse` OK en todos los `.gd` tocados. `.tscn` releídos: ids únicos, nodos nuevos con parent correcto.

## Checklist manual (sesión 2)

1. F5 desde `Main.tscn`, run offline. HUD arriba-izq: **"Piso 1/5"**; recursos **15/15/10/20** (antes 0/0/0/0).
2. Energizar una sala (10 dust) ahora funciona → construir Turret/Generator.
3. Combate: números amarillos sobre enemigos, rojos sobre el héroe.
4. Nexo → extracción → `vault_room`: overlay "¡Piso 1 superado!" con **"Descender al piso 2"** + "Volver al menú".
5. Descender: fade, mapa nuevo, HUD "Piso 2/5", recursos conservados + 10 dust, héroe con HP lleno. Log `Floor 2/5 started (enemy HP x1.25, dmg x1.20)`.
6. En piso 2: extracción spawnea cada 4.5 s (log/observación); enemigos aguantan un golpe más.
7. Morir en piso 2+ → Retry → vuelve a **Piso 1/5** con recursos reseteados.
8. Piso 5 superado: overlay sin botón de descender (texto original "¡Reliquia extraída con éxito!").
9. Regresión: Turrets disparan, Sappers rompen módulos, puertas bloqueadas en extracción, pausa (Esc) funciona.
10. Inspector: `default_floor_config.tres` editable con grupos Progression / Enemy scaling / Wave scaling.

## Riesgos / decisiones a revisar (sesión 2)

- **Reset de recursos al iniciar run:** cambia el comienzo de la run de 0/0/0/0 a los defaults de `reset_resources()` (15/15/10/20). Era claramente la intención (valores ya escritos, doc dice "resets per run"), pero es cambio de balance visible.
- **HP del héroe se resetea en cada piso** (Player nuevo → `refresh_stats`). Simple y generoso; si se quiere desgaste entre pisos, guardar `current_hp` en `Main` como `current_floor`.
- **Mismo `LAYOUT` en todos los pisos**; solo cambia la dificultad. Variar layout requiere generador o pool de layouts.
- **Estado de run en `Main` (orquestador)**, no en un autoload nuevo: evita autoload con estado de gameplay; si crece (HP, oro de run, reliquias), extraer a un `RunState` Resource que `Main` guarde.
- Oro de run (`_run_gold_start`) se recalcula por piso: el overlay muestra oro del piso, no de toda la run.
- Números flotantes: `FloatingTextManager` cae en root si no existe `map_manager` (comportamiento previo, igual que `BuildingMenu`).

## Pendiente / próximos pasos

1. Playtest del checklist (sesión 1 + 2) en editor; ajustar `default_floor_config.tres` y daños.
2. C: Comida → curar héroe (p.ej. botón en sala energizada, costo/curación en un Resource).
3. B: `EnemyStats` .tres por variante, y variación de `LAYOUT` por piso (pool de 2-3 layouts elegidos por `floor_index`).

---

# Sesión 3 — 2026-09-27 (branch `session/opus-2026-09-27-3`, from `session/opus-2026-09-27-2`)

Verificación: **Godot 4.6.2 disponible** (`E:\Descargas\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`), `--headless` carga `Main.tscn`/`Main2d.tscn`/`HUD.tscn`. `gdparse` (gdtoolkit 4.5, pip global) sobre cada `.gd` tocado.

Errores **preexistentes** en headless (no tocados): `project.godot` `mouse_cursor/custom_image="uid://cbtsbpk8s6y35"` UID inexistente; `OptionsMenu.tscn` UID inválido (cae a path); GodotSteam DLL bloqueada/Steam no corriendo.

**Bug preexistente arreglado:** `Player.tscn` nodo `Stats` tenía `type="CharacterStats"` (class_name de script) → Godot creaba un *placeholder* y el héroe no tenía `CharacterStats` funcional. Ahora `type="Node"` + script.

## Fase 1 — Reconocimiento del mapa

- **Layout:** `Main2d.LAYOUT` (const dict): 9 zonas (5 salas + 4 pasillos), `connections` zona↔zona, 5 grupos de revelado (`start/hub/north/east/vault`), cada grupo = pasillo de entrada + sala.
- **Puertas:** 4 nodos `Door` a mano en `Main2d.tscn/Doors` (`target_room_id`=grupo, `from_zone_id`=sala padre, `cell`=celda entre sala padre y pasillo). `RoomManager.register_door` las posiciona y deriva `room_a_id/room_b_id`.
- **Fog-of-war:** `DoorTurnSystem.rooms[group].visited` es la verdad; `RoomManager.refresh_visibility/on_group_revealed` pinta tiles (`FloorGenerator.fill_cells`) y muestra `RoomZone`.
- **Energizar:** `RoomZone.try_power_up` (10 dust, `POWER_COST`) → `RoomManager.room_powered` → `RoomPowerSystem`.
- **"Cristal" = `El Nexo`** (`Nexo`/`NexoController`, hardcodeado a `"start_room"`). **Salida = `vault_room`** (`is_exit_room`).

**Contratos a preservar:**
- `ManagerLocator.get_room_manager()` / `get_floor_manager()` / etc. (grupos).
- `RoomManager` señales `zone_clicked/zone_hovered/zone_unhovered/room_powered/slot_clicked`; queries `get_center, get_group_id, find_zone_path, is_zone_revealed, is_group_revealed, get_zone_kind, get_zone_node, get_zone_ids, get_modules_in_group, get_all_modules, get_unpowered_revealed_room_group_ids, get_room_zone_id_in_group, get_group_zone_ids, get_group_centers, get_group_cells, get_dark_rooms, get_all_doors, is_exit_room, set_current_zone, set_zone_highlight, clear_highlights, refresh_door_visibility, on_group_revealed, refresh_visibility, validate_graph`.
- `DoorTurnSystem` señales `turn_advanced/door_opened/room_revealed/enemy_wave_requested`; `register_room/open_room/is_room_visited/get_room_cells`.
- `Door`: `door_clicked`, `target_room_id` (= grupo), `from_zone_id`, `cell`, `get_target_room_for()`.
- Consumidores: `EnemyManager` (`turn_advanced`, `get_dark_rooms`, `find_zone_path`), `ExtractionManager` (`get_unpowered_revealed_room_group_ids`), `PlayerActionController`, `Enemy`, `NexoController`, `RoomPowerSystem`, `ModuleBuildSystem`/`BuildingMenu` (`slot_clicked`), HUD (solo `ResourceManager`/`FloorManager`).

## Fase 2/3 — Diseño e implementación (sesión 3)

Prioridades cumplidas: (1) modelo de datos + fallback, (2) generador, (3) polvo por descubrimiento. Todo verificado en Godot headless.

**Decisión de alcance:** "reescribir el interior del mapa" = se reescribió todo lo que *construye* el mapa (datos, generación, grupos de revelado, puertas). La API de consulta/presentación de `RoomManager` (fog, highlights, BFS, dark rooms) se mantuvo intacta porque *es* el contrato que consumen Enemy/Extraction/PlayerActionController; reescribirla sin cambio de comportamiento era riesgo puro.

| Sistema | Archivo | Qué |
|---|---|---|
| Datos (nuevo) | `scripts/world/map/RoomData.gd` | Resource: `id`, `kind`, `pos`, `size`, `neighbors`, `is_start/is_exit/is_vault` |
| Datos (nuevo) | `scripts/world/map/CorridorData.gd` | Pasillo como entidad: `id`, `room_a` (lado puerta), `room_b`, rect, `door_cell` |
| Datos (nuevo) | `scripts/world/map/MapLayout.gd` | Resource: `rooms`, `corridors`, `map_seed`; `validate()` (1 start, ≥1 exit, 1 pasillo de entrada por sala, sin solapes, todo alcanzable) |
| Fallback (nuevo) | `resources/maps/fallback_layout.tres` | El viejo `Main2d.LAYOUT` (mismas celdas/ids, `vault_room` = exit + vault) |
| Generador (nuevo) | `scripts/world/map/MapGenerator.gd` | `generate(seed, room_count, branch_chance)`: árbol sobre grilla de slots (pitch 9, sala ≤5×5 → sin solapes), tamaños 5×5/5×3/3×5/3×3, exit = sala más lejana del start, vault = hoja más profunda restante. Determinista (`RandomNumberGenerator` con seed, nunca `shuffle()` global) |
| Pisos | `FloorConfig.gd` | Grupos "Map" (`base_room_count=6`, `+1`/piso, máx 12; `branch_chance` 0.25 `+0.1`/piso) y "Discovery" (`dust_per_discovery=2`, `+0.5`/piso) |
| Pisos | `FloorManager.gd` | `map_seed = hash([run_seed, floor])`, `room_count()`, `branch_chance()`, `on_room_discovered()` (+dust) |
| Orquestador | `Main.gd` | `run_seed = randi()` en `_begin_new_run()` |
| Mapa | `RoomManager.gd` | `build_from_map(MapLayout)` reemplaza `build_from_layout(dict)`; grupo = id de sala (+ su pasillo de entrada); nuevos `get_start_zone_id()`, `get_group_ids()`, `is_vault_room()` |
| Gameplay | `Main2d.gd`, `Main2d.tscn` | Sin `LAYOUT`/`SPAWN_ZONE_ID`; genera layout (fallback si `force_fallback_layout` o `validate()` falla); instancia 1 `Door` por pasillo (los 4 nodos a mano se quitaron del `.tscn`); conecta `room_revealed → floor_manager.on_room_discovered` |
| Nexo | `NexoController.gd` | Usa `room_manager.get_start_zone_id()` en vez de `"start_room"` |
| Fix | `Player.tscn` | `Stats` `type="Node"` (antes placeholder) |
| Tests (nuevos) | `tests/test_map_generator.gd`, `tests/test_map_flow.gd` | Ver abajo |
| Legacy | `_deprecated/map_v1/` (+ `.gdignore`) | Copia de `Main2d.gd/.tscn`, `RoomManager.gd`, `NexoController.gd` previos |

**Balance de polvo:** arranque 20, energizar 10. Piso 1 = 6 salas → 5 descubrimientos × 2 = +10 → 30 dust ≈ 3 de 6 salas. Piso 5 = 10 salas × 4 dust + bonus de descenso 10 + sobrante → ~5-6 de 10. Nunca todas si no se ahorra entre pisos.

**Contratos preservados:** todas las señales/queries listadas en Fase 1 siguen con la misma firma. Cambios de *valores*: los group ids ahora son ids de sala (`"hub_room"` en vez de `"hub"`; nadie los hardcodeaba) y los ids generados son `room_N`/`corr_room_N`. `build_from_layout` desapareció (único caller era `Main2d`).

## Verificación (sesión 3)

- `godot --headless --path . res://scenes/{Main,Main2d,HUD}.tscn --quit-after 90`: sin errores nuevos (solo los 3 preexistentes: cursor UID, OptionsMenu UID, Steam).
- `godot --headless --path . --script res://tests/test_map_generator.gd` → `OK`: 1000 layouts (5 pisos × 200 seeds) válidos, cantidad de salas correcta, determinismo por seed.
- `godot --headless --path . --script res://tests/test_map_flow.gd` → `OK`: instancia `Main2d` (generado y fallback), abre todas las puertas en orden, cada descubrimiento da exactamente `discovery_dust`, `validate_visibility` OK, camino start→exit revelado. (El ruido `Identifier not found: ThemeManager` en ese modo es de `--script`, que no registra autoloads como identificadores; no pasa en F5.)
- `python -m gdtoolkit.parser` sobre cada `.gd` tocado: OK.
- Si Godot deja de ver una clase nueva (`Could not find type "RoomData"`): cache de clases viejo → `godot --headless --path . --editor --quit` para reescanear.

## Checklist manual (sesión 3, F5 desde `Main.tscn`)

1. Run offline: mapa distinto a los 5 cuartos de siempre; log `RoomManager: built N zones, M groups (seed X)` y `validate_graph: OK`.
2. Solo la sala inicial visible con el Nexo en el centro; puertas marrones en sus paredes hacia cada vecino.
3. Abrir puerta: se revela pasillo + sala; HUD Polvo +2; log `Discovered 'room_N': +2 dust.` (también cuando no hay invasión).
4. Energizar con el polvo acumulado alcanza para ~3 salas del piso 1, no todas.
5. Retry → otro mapa (seed nuevo). Descender → otro mapa, más salas (piso 2 = 7), polvo por sala 2 (piso 3+: 3).
6. Nexo solo se agarra en la sala inicial; llevarlo a la sala más lejana (exit, sin indicador aún — ver log/`is_exit_room`) da victoria.
7. Inspector de `Main2d.tscn` → `force_fallback_layout` ON → vuelve el mapa viejo (`start_room` … `vault_room`) y todo funciona igual.
8. Regresión: enemigos caminan por pasillos generados, Turrets/Sappers/extracción igual que antes.

## Riesgos a revisar antes de mergear (sesión 3)

- **Salida invisible:** nada indica qué sala es la exit hasta sesión 4; el jugador tiene que explorar a ciegas (es la más lejana del start).
- **Sin loops:** el generador produce árboles (cada sala 1 pasillo de entrada = 1 grupo de revelado). DotE tiene ciclos; agregarlos requiere grupos de solo-pasillo en `DoorTurnSystem`. Marcado `ponytail:` en `MapGenerator`.
- **Mapa puede ir a coordenadas negativas** (slots arriba/izquierda del start): la cámara sigue al héroe, pero cualquier código futuro que asuma celdas ≥0 se rompe.
- **Sin cota de tamaño en pantalla**: con 12 salas en línea el mapa mide ~100 celdas; no hay zoom/minimapa.
- Group ids cambiaron de `"hub"` → `"hub_room"`: si algo externo (saves, logs parseados) guardaba ids de grupo, ya no coinciden. Hoy nadie lo hace.
- Balance de polvo a ojo; sin playtest. Knobs en `default_floor_config.tres` grupo Discovery.
- `Main2d.tscn` perdió los nodos `Doors/Door*`: cualquier edición manual del `.tscn` en el editor que los esperara ya no los ve (copia en `_deprecated/map_v1/Main2d.tscn`).

## Pendiente — sesión 4

1. **Luces por sala:** placeholder visual de sala oscura vs energizada (p.ej. `Polygon2D`/`PointLight2D` o `CanvasModulate` + overlay por `RoomZone`), manejado desde `RoomZone.set_powered`.
2. **Indicador de salida:** `RoomManager.is_exit_room()` ya existe — dibujar marcador (`Label`/`Polygon2D`) en la sala exit al revelarla, y opcional flecha/hint durante la extracción.
3. Loops en el generador (ver riesgos) y tipos de sala (`RoomData.kind`) con efectos.
4. Playtest de balance de polvo por piso.

---

# Sesión 4 — 2026-09-27 (branch `session/opus-2026-09-27-4`, from `session/opus-2026-09-27-3`)

Godot 4.6.2 headless + `python -m gdtoolkit.parser`, igual que sesión 3.

## Fase 1 — Diagnóstico

- **`RoomZone.set_powered(v)`**: cambia `is_powered`, recolorea `Fill`/`Outline` a dorado (`POWERED_*_COLOR`), oculta `EnergyButton`, crea `BuildingSlot`s. No emite señal propia (solo `powered_up` desde `try_power_up`, es decir, solo cuando lo paga el jugador). Sala oscura revelada = relleno transparente + contorno blanco 25%: **no comunica peligro**, y no hay diferencia visual entre "oscura pero pagable" y "oscura sin polvo".
- **`RoomManager`**: `is_exit_room(zone_id)` existe (dato desde `RoomData.is_exit`); fog = `apply_zone_visibility` → `RoomZone.set_shown` + tiles; `is_room_dark`/`get_dark_rooms` = revelada y no energizada (pool de spawn de enemigos).
- **Estado del cristal (Nexo):** `Player.is_carrying_nexo` (bool, sin señal). La señal equivalente ya existe: `ExtractionManager.phase_changed` pasa a `EXTRACTION` exactamente al agarrarlo (`NexoController` → `start_extraction()`).
- **HUD:** `HUD.tscn` vive en `Main.HUDContainer` (hermano de `WorldContainer`), autocableado vía autoloads/grupos. No hay nada de mapa/salida.
- **Cámara:** `Camera2D` hija de `Player` (smoothing 10), sin límites ni zoom. Una salida lejana queda fuera de pantalla casi siempre → hace falta flecha de borde.
- **Salida:** sin ningún indicador (riesgo #1 de sesión 3).

**Errores viejos arreglados (extra 4, seguro):** `project.godot` apuntaba el cursor custom al UID de `assets/ui/gauntlet.png`, borrado en `40b6f37` → se quitó la línea (mismo comportamiento real: cursor por defecto). `OptionsMenu.tscn` usaba un UID viejo del script → UID actual (`uid://b6rlxicpb1un2`). Queda preexistente: `ObjectDB instances leaked / 1 resources still in use at exit` al salir con `--quit-after` (también en la rama anterior).

## Fase 2/3 — Implementado (sesión 4)

Prioridades: (1) luces ✅, (2) indicador de salida + flecha ✅, (3) extras: UIDs viejos ✅, **minimapa no** (tiempo; ver pendientes).

| Sistema | Archivo | Qué |
|---|---|---|
| Config (nuevo) | `scripts/world/map/MapVisualConfig.gd`, `resources/maps/map_visual_config.tres` | Resource: grupo "Exit hint" (`exit_hint_mode` enum `ALWAYS`/`ON_DISCOVERY`/`ON_CRYSTAL`, default `ALWAYS`; colores; margen de flecha) y "Lighting" (overlay oscuro/peligro, pulso, contorno pagable, luz cálida, tiempo de transición). El setter de `exit_hint_mode` emite `changed` |
| Luces (nuevo) | `scripts/world/RoomLight.gd` | Hijo de cada `RoomZone` sala (debajo de Fill/botón/slots). Oscura: overlay que pulsa oscuro↔rojo sangre (peligro, ahí spawnean enemigos). Energizada: tween → overlay a 0 + `PointLight2D` cálido (textura `GradientTexture2D` radial generada en código, sin assets). Contorno dorado si `dust >= POWER_COST` (vía `ResourceManager.resource_changed`) |
| Salas | `RoomZone.gd` | Nueva señal `power_changed(zone_id, powered)` emitida en `set_powered` (cualquier cambio, no solo pagado); `attach_light()`, `get_light()`; fog oculta también la luz |
| Mapa | `RoomManager.gd` | `@export visual_config` (default el `.tres`); adjunta `RoomLight` a cada sala; nuevo `get_exit_zone_id()` |
| Salida (nuevo) | `scripts/world/ExitIndicator.gd` | Nodo por-`Main2d` (grupo `exit_indicator`, `ManagerLocator.get_exit_indicator()`). Marcador (rombo `Polygon2D` + `Label` "SALIDA", z 50, **por encima de la niebla**) + flecha en `CanvasLayer` (layer 5) que se clava al borde de pantalla cuando la salida está fuera de cámara. Llevando el Nexo: color dorado, texto "¡SALIDA! Traé el Nexo", pulso más grande/rápido — y se muestra en **cualquier** modo |
| Gameplay | `Main2d.gd` | `_setup_exit_indicator()` tras registrar grupos/puertas |
| Tests | `tests/test_map_flow.gd` | + luces (oscura, pagable, energizada, re-oscurecida), los 3 modos antes/después de explorar y con el cristal (cambio solo vía señal `changed`), `ExitIndicator.edge_point` |
| Fix | `project.godot`, `OptionsMenu.tscn` | UIDs muertos (ver Fase 1) |

**Señales, sin polling de estado:** estado del hint = `config.changed` + `DoorTurnSystem.room_revealed` + `ExtractionManager.phase_changed` (EXTRACTION = lleva el cristal; señal ya existente, no hizo falta agregar una a `Player`). Luces = `RoomZone.power_changed` + `ResourceManager.resource_changed`. Único `_process`: posicionar la flecha (la cámara se mueve cada frame), y solo corre mientras el hint es visible.

**Decisión: la flecha vive en un `CanvasLayer` propio del `ExitIndicator`**, no dentro de `HUD.tscn`: el HUD está en `Main.HUDContainer` (otro subárbol) y tendría que buscar la salida del mapa cada piso; así el indicador y su flecha nacen y mueren con el piso, sin cableado cruzado. Visualmente es igual una capa de HUD.

### Cómo cambiar el modo de salida

- **Permanente:** abrir `resources/maps/map_visual_config.tres` en el Inspector → grupo *Exit hint* → `Exit Hint Mode`.
- **Solo en un `Main2d`:** seleccionar el nodo `RoomManager` de `Main2d.tscn` → `Visual Config` → asignar otro `.tres` (o "Make Unique").
- **En runtime:** `room_manager.visual_config.exit_hint_mode = MapVisualConfig.ExitHintMode.ON_CRYSTAL` (o desde el Remote inspector) → se actualiza al instante por `changed`.

## Verificación (sesión 4)

- `test_map_generator` OK, `test_map_flow` OK (x2 corridas, estables).
- Carga headless de `Main`/`Main2d`/`HUD`: **0 errores** (se fueron los de UID). Solo quedan: warnings de Steam (no corre Steam) y `ObjectDB leaked / 1 resources still in use at exit` al cortar con `--quit-after` (preexistente, rama anterior igual).
- `gdparse` OK en todos los `.gd` tocados.
- Tras agregar clases, la **primera** corrida `--script` puede dar `Could not resolve external class member` → `--editor --quit` para reindexar y listo (pasó una vez esta sesión).

## Checklist manual F5 (sesión 4)

1. Arranque: sala inicial con overlay oscuro que late en rojo, contorno dorado (tenés 20 dust ≥ 10). Rombo verde "SALIDA" visible en su posición aunque esa zona siga en niebla; flecha verde en el borde de pantalla apuntando hacia él.
2. Caminar hacia la salida: cuando entra en cámara la flecha desaparece; al salir de cámara vuelve.
3. Energizar una sala: el rojo se desvanece (~0.6 s) y aparece un halo cálido; desaparece el contorno dorado. Con < 10 dust, las demás salas oscuras pierden el contorno dorado.
4. Agarrar el Nexo: marcador y flecha pasan a dorado, texto "¡SALIDA! Traé el Nexo", pulso más fuerte.
5. Cambiar `Exit Hint Mode` a `ON_DISCOVERY` en el `.tres` → F5: no hay marcador/flecha hasta descubrir la sala de salida (o agarrar el Nexo).
6. `ON_CRYSTAL` → nada hasta agarrar el Nexo; después, marcador + flecha dorados.
7. Regresión: salas en niebla no muestran overlay/luz; hover/click de salas, EnergyButton, BuildingSlots y módulos siguen clickeables encima del overlay; enemigos/héroe se dibujan por encima.
8. Opciones del menú principal abren normal (UID corregido); cursor = cursor del sistema (igual que antes, el custom estaba roto).

## Riesgos a revisar antes de mergear (sesión 4)

- **`PointLight2D` sin `CanvasModulate`:** la luz solo suma brillo (blend ADD) sobre el tile; el contraste real viene del overlay oscuro. Si se agrega `CanvasModulate` global más adelante, revisar `warm_light_energy`. En GL Compatibility las luces 2D funcionan, pero no se vio en pantalla (headless).
- **Overlay tapa el piso de salas oscuras al 60% + pulso:** puede ser demasiado oscuro/ruidoso con varias salas; knobs en el `.tres`.
- **Contorno "pagable" en todas las salas oscuras a la vez** (misma condición global de dust). Con muchas salas reveladas puede ser mucho ruido visual; alternativa: solo salas adyacentes al héroe.
- **ALWAYS revela la posición de la salida bajo niebla** (pedido explícito), lo que baja la tensión de exploración; `ON_DISCOVERY` es la alternativa "más DotE".
- `ExitIndicator` asume una sola salida (`get_exit_zone_id()` = primera). El generador marca una sola; un `.tres` a mano con varias mostraría solo una.
- El `.tres` de config es un recurso compartido: cambiarlo en runtime afecta a todos los pisos siguientes de la sesión (intencional para debug).
- Nada de esto se vio renderizado (solo headless): colores/tamaños a ojo.

## Pendiente / próximos pasos (sesión 5+)

1. **Minimapa** (extra no hecho): `Control` en `HUD.tscn` que dibuje rects de `RoomManager` (salas reveladas, héroe, salida si el hint es visible) con `_draw()`, refrescado por `room_revealed`/`power_changed`/movimiento del héroe.
2. **Loops en el generador:** grupos de solo-pasillo en `DoorTurnSystem` para permitir ciclos (DotE real).
3. **Tipos de sala con efectos** (`RoomData.kind`: tienda, tesoro/vault con recompensa, sala de generador doble, etc.).
4. **Playtest de balance:** polvo por descubrimiento vs costo de energizar, intensidad del overlay/pulso, tamaño de la flecha.

---

# Sesión 5 — 2026-09-28 (branch `session/opus-2026-09-28-5`, from `session/opus-2026-09-27-4`)

Bugs del playtest de la sesión 4 + minimapa. Loops y tipos de sala: **solo diseño** (se acabó el tiempo; ver abajo).

## Bug 1 — la salida se veía desde el arranque

- **Causa raíz:** no era un bug de lógica; `MapVisualConfig.exit_hint_mode` tenía default `ALWAYS` (decisión de la sesión 4), que muestra marcador + flecha bajo niebla desde el turno 0.
- **Fix:** default → `ON_DISCOVERY` en `MapVisualConfig.gd`. En `map_visual_config.tres` el valor queda implícito: el editor (abierto durante la sesión) re-guardó el `.tres` y **omitió la línea `exit_hint_mode`** porque ahora es igual al default del script — se lee como `ON_DISCOVERY`. `ALWAYS`/`ON_CRYSTAL` siguen como opciones. Con el Nexo en mano se muestra en cualquier modo (dorado), sin cambios.
- **Test:** `test_map_flow` verifica que el default sea `ON_DISCOVERY`, que al iniciar no haya marcador (`ExitMarker.visible`) ni flecha (`ExitIndicator` sin `_process` = la flecha nunca se posiciona), y que después de **cada** puerta abierta el hint aparezca exactamente cuando la sala de salida está revelada. Al final restaura `ON_DISCOVERY` (el `.tres` está cacheado y se comparte entre corridas; antes restauraba `ALWAYS`).

## Bug 2 — pasillo de 4 celdas, solo 3 clickeables

- **Qué hace hoy el clic en un pasillo:** `RoomZone` (Area2D, `input_event`) → `RoomManager.zone_clicked` → `PlayerActionController` → glide si está revelado y conectado. Una puerta cerrada la recibe `Door` (Area2D 48×48 sobre `door_cell`) → `open_room`.
- **Causa raíz:** `MapGenerator._make_corridor` pone `door_cell` **fuera** del rect del pasillo (pegada a la pared de `room_a`; el `CorridorData.get_rect()` son las celdas siguientes). En pantalla el pasillo son 4 tiles (puerta + 3), pero el `RoomZone` del pasillo se construía solo con `get_rect()` = 3. La 4ª celda la cubría únicamente el `Door`, y `disable_door()` desactiva su colisión al abrirse → esa celda quedaba sin ningún Area2D. Pasa igual en el fallback (`door_cell` fuera de `pos/size` en los 4 pasillos). No era inset, ni z-order, ni `input_pickable`, ni solape con la sala.
- **Repro:** `tests/test_corridor_picking.gd` — `intersect_point` (`collide_with_areas`) en el centro de cada celda. Con el código viejo: `FAIL: seed 1 floor 1 corridor 'corr_room_1' door cell (2, -1): not covered by 'corr_room_1'; covered by []` (una por pasillo). Con el fix: OK.
- **Fix (1 lugar, todos los callers):** `CorridorData.get_zone_rect()` = `get_rect()` ∪ `door_cell`; `RoomManager.build_from_map()` arma la zona del pasillo con eso. `get_rect()` no cambió (lo sigue usando `MapLayout.validate()` para solapes con la celda de puerta separada). Efectos: las `cells` del pasillo/grupo incluyen la celda de puerta (ya se pintaba aparte con `_apply_group_door_cell`, así que el render no cambia) y el `center_position` del pasillo se corre media celda hacia la puerta (waypoint del glide, visualmente mejor centrado).
- **Sin ambigüedad de clic:** antes de abrir, el `RoomZone` del pasillo está oculto (colisión deshabilitada) → el clic en la celda es del `Door`; después, el `Door` está deshabilitado → es del pasillo. El test lo comprueba (celda de puerta cerrada = solo `Door`; celdas de pasillo abiertas = solo su `RoomZone`; celdas de borde de cada sala = solo esa sala).
- **Cobertura:** seeds {1, 7, 42, 1234, 99991} × pisos 1–5 (25 mapas generados) + fallback. Para elegir piso sin el orquestador: nuevo export `Main2d.standalone_floor` (default 1, solo se usa sin `Main`; sirve también para F6 de debug). El seed se controla con `seed(n)` global antes de instanciar (`Main2d` sin `Main` usa `randi()`).

## Fase 3.1 — Minimapa ✅

| Sistema | Archivo | Qué |
|---|---|---|
| HUD (nuevo) | `scripts/ui/hud/Minimap.gd` | `Control` 200×150 con `_draw()`: zonas reveladas (salas gris, energizadas doradas, pasillos gris oscuro), punto del héroe, contorno de la salida **solo si** `ExitIndicator.is_hint_visible()` (dorado si lleva el Nexo). Escala fija con el bounding box de **todas** las zonas (no se reescala al revelar). `mouse_filter = IGNORE` |
| HUD | `HUDController.gd` | `_add_minimap()`: lo crea en código dentro de `$Control`, esquina inferior derecha (no se tocó `HUD.tscn`: el editor estaba abierto) |
| Héroe | `Player.gd` | Nueva señal `zone_changed(zone_id)` emitida en `set_zone()` |
| Salida | `ExitIndicator.gd` | Nueva señal `hint_changed(hint_visible)` emitida al final de `_refresh()` |

Refresco solo por señales: `DoorTurnSystem.room_revealed`, `RoomManager.room_powered`, `Player.zone_changed`, `ExitIndicator.hint_changed`. Funciona porque `Main.gd` agrega el mundo **antes** que el HUD (el minimapa resuelve `RoomManager`/`Player`/`ExitIndicator` en su `_ready`). Test: `test_map_flow` instancia un `Minimap` sobre cada `Main2d` y verifica que no se desactive.

## Fase 3.2 — Loops en el generador (solo diseño, no implementado)

- `FloorConfig` grupo "Map": `loop_chance: float = 0.0` (apagado hasta playtest).
- `MapGenerator`, después del árbol: para cada par de salas en slots adyacentes **sin** pasillo entre sí, con `rng.randf() < loop_chance` agregar un `CorridorData` extra con un flag nuevo `is_loop = true` (mismo `_make_corridor`, así el carril/puerta son deterministas). El rng se consume en orden fijo de pares → determinismo por seed intacto.
- `DoorTurnSystem`: cada pasillo de loop es **su propio grupo solo-pasillo** (group id = corridor id, `cells` = sus celdas), revelado al abrir su puerta; no revela sala. Así se mantiene "un grupo = lo que abre una puerta".
- `MapLayout.validate()`: relajar "exactamente un pasillo de entrada por sala no-start" a "exactamente uno **no-loop**"; los loops no pueden solapar (mismo chequeo de celdas) y el árbol no-loop sigue garantizando alcanzabilidad.
- `RoomManager.build_from_map()`: grupos de loop = `[corridor.id]`; `_link_zones(room_a, corr)` y `(corr, room_b)` igual que ahora → `find_zone_path` los usa solos. `Main2d` crea un `Door` más por loop (`target_room_id` = corridor id).
- Riesgo: `EnemyManager`/`get_dark_rooms` asumen grupo = sala; filtrar grupos solo-pasillo. Descubrir un loop no debe dar dust (o sí: decidir en playtest).
- Test: `test_map_generator` con `loop_chance = 0.5` → 1000 layouts válidos, deterministas, y al menos uno con loop.

## Fase 3.3 — Tipos de sala (solo diseño)

`RoomData.kind` (hoy siempre "room") → valores y efecto, aplicado en un solo lugar (`RoomManager.build_from_map` pasa `kind` al `RoomZone`; efectos leídos por los sistemas existentes):
- `treasure`: al descubrir, +X dust/industria una vez (`FloorManager.on_room_discovered` ya tiene el hook de discovery).
- `double_generator`: el slot MAJOR produce ×2 (`GeneratorModule.yield_amount` × multiplicador de la sala, leído en `ResourceManager._calculate_module_bonus`).
- `shrine`/`medbay`: energizada cura al héroe por turno (`DoorTurnSystem.turn_advanced`).
- `vault` ya existe como flag (`is_vault`): candidato natural para `treasure`.
- Generador: asignar kinds con el rng del layout (pesos en `FloorConfig`), nunca start/exit. Color distinto en `RoomLight`/minimapa.

## Verificación (sesión 5)

- Al empezar: `test_map_generator` OK, `test_map_flow` OK.
- Al terminar: `test_map_generator` OK, `test_map_flow` OK, `test_corridor_picking` OK (26 mapas); con el fix revertido `test_corridor_picking` falla (exit 1) en todas las celdas de puerta.
- `gdparse` (vía `python -m gdtoolkit.parser`, `gdparse` no está en PATH) OK en todos los `.gd` tocados.
- `HUD.tscn` headless (con autoloads): 0 errores; solo el warning esperado "Minimap: RoomManager not found" (HUD sin mundo).
- Ruido preexistente en `--script`: `Identifier not found: ThemeManager` → "Failed to load script Main2d.gd" (cadena PauseMenu→ThemeManager); aparece igual en la rama base y los tests pasan.
- **Nada visto en pantalla** (headless).
- `_deprecated/`: sin cambios — no se reemplazó ni borró ningún archivo (todo fueron ediciones puntuales/adiciones).

## Checklist manual F5 (sesión 5)

1. Arranque: **sin** rombo "SALIDA" ni flecha en el borde. Minimapa abajo a la derecha: sala inicial + punto celeste del héroe.
2. Abrir puertas: cada pasillo aparece en el minimapa con su sala; el punto del héroe salta al llegar.
3. **Pasillos:** en un pasillo abierto, clickear **las 4 celdas**, incluida la pegada a la sala de origen (donde estaba la puerta) → el héroe va al pasillo. Hover resalta el pasillo en las 4.
4. Puerta cerrada: clic en ella la abre (igual que antes). Celdas de borde de salas (pegadas al pasillo) siguen seleccionando la sala.
5. Al descubrir la sala de salida: aparecen rombo verde + flecha (si está fuera de cámara) + contorno verde en el minimapa.
6. Agarrar el Nexo: rombo/flecha/contorno del minimapa pasan a dorado. Con `ON_CRYSTAL` en el `.tres`: nada hasta agarrarlo. Con `ALWAYS`: visible desde el arranque (comportamiento de sesión 4).
7. Energizar una sala → en el minimapa se pone dorada.
8. Piso 2+: el minimapa se reconstruye con el nuevo mapa (HUD nuevo por piso).

## Riesgos a revisar antes de mergear (sesión 5)

- `center_position` de los pasillos se corrió media celda hacia la puerta (la zona ahora incluye la celda de puerta). Solo afecta waypoints del glide del héroe/enemigos; revisar que no se vea raro.
- `DoorTurnSystem` registra la celda de puerta dentro de las `cells` del grupo (antes se pintaba aparte). Render idéntico; `validate_visibility()` OK.
- El `.tres` de config ya no escribe `exit_hint_mode` (igual al default). Si alguien cambia el default del script, el `.tres` lo sigue sin aviso.
- Minimapa: tamaño/colores a ojo; tapa la esquina inferior derecha (¿choca con `BuildingMenu`/tooltips?). No se escala con la resolución.
- El bounding box del minimapa usa **todas** las zonas → la forma del recuadro insinúa el tamaño del mapa sin explorar.
- El héroe en el minimapa salta al final del glide (señal en `set_zone`), no se mueve durante el tránsito.

## Pendiente / próximos pasos (sesión 6+)

1. Loops en el generador (diseño arriba).
2. Tipos de sala (diseño arriba).
3. Playtest visual del minimapa y de la posición del waypoint del pasillo.
4. Balance (igual que sesión 4).

---

# Sesión 6 — 2026-09-28 (branch `session/opus-2026-09-28-6`, from `session/opus-2026-09-28-5`)

Interfaz estilo Dungeon of the Endless: retratos, popup de personaje, mejoras en Ciencia, menú de construcción por pestañas, barra de recursos con ganancia por turno.

## Fase 1 — Reconocimiento

| Pieza | Estado al empezar |
|---|---|
| `HUD.tscn` / `HUDController` | `CanvasLayer` (layer 2) → `Control` full-rect. Barra inferior centrada (`StatBarAnchor/.../StatPanelUI`) con 5 chips: HP como texto `"32/32"` + 4 recursos. `FloorLabel` arriba a la izquierda (offset fijo). `StatTooltip` (load-bearing para `StorePanel`), `InvasionFlash`, `BuildingMenu` (instancia). Minimapa agregado en código (abajo a la derecha). |
| `StatPanelUI` | `update_stats/update_hp/update_resource` formatean labels. |
| `BuildingMenu` | `PanelContainer` con `VBox` de `Button`s de `Module.CATALOG` filtrados por `slot_type`; gasta Industria (`spend_resource`), `slot.build()`, sacudida + texto flotante si falta. Sin señales propias. API pública: `open_menu(slot)`, `close_menu()`. Cierra con clic derecho / clic afuera vía `_input` sin marcar handled. |
| `PlayerStats` (autoload) | `stats_changed`, `upgrades_changed`, `player_died`; `base_hp`, `active_upgrades` (meta, **persisten en el save**), `upgrade_levels{"hp"}`, `apply_upgrade(dict)`, `refresh_stats()`. |
| `CharacterStats` | Solo HP (`hp_changed(current, max)`, `died`, `stats_changed`), `apply_modifier("hp", n)` con clamp `StatBalance.PLAYER_MAX_HP` = 40. |
| `CharacterData` | `display_name`, `portrait` (hay PNGs), `base_hp`, `attack_damage`/`attack_interval` (grupo Combat), habilidades, `sprite_frames`. El `HitboxComponent` del héroe se configuraba una vez en `Player._ready` desde `CharacterData`. |
| Store existente | `StorePanel` (menú de pausa): +2 vida máx por nivel, paga **Oro** (moneda meta, persistente), vía `PlayerStats.apply_upgrade()`. |
| Minimapa | `Minimap.gd` 200×150, abajo a la derecha, `mouse_filter = IGNORE`, solo señales. |
| Esc | `Main2d._input` (`ui_cancel`) abre/cierra la pausa y marca handled. `HUDContainer` va después de `WorldContainer` en `Main.tscn` → los `_input` del HUD corren **antes** que los de `Main2d`. |

## Plano del HUD (sin solapes, todo con anclas/contenedores)

```
┌──────────────────────────────────────────────────────────────┐
│ [TopLeft VBox]                              [TopRight VBox]  │
│  ResourceBar: ⚙ 15 +2 · 🍖 15 +2 ·          HeroPortrait ▣▬▬ │
│               ⚗ 10 +1 · ✦ 20                 (uno por héroe,  │
│  Piso 1/5                                    apilados)        │
│                                                              │
│            BuildingMenu: flota sobre el slot clickeado       │
│            (clamp a pantalla, fuera de las 3 esquinas usadas)│
│                                                              │
│            CharacterPopup: modal centrado + velo oscuro      │
│                                                   [Minimap]  │
└──────────────────────────────────────────────────────────────┘
```

- **Arriba-izquierda** `TopLeft` (`VBoxContainer`, preset top-left, margen 16): `ResourceBar` (panel con 4 chips: ícono, valor, `+N`/turno) y debajo `FloorLabel`.
- **Arriba-derecha** `Portraits` (`VBoxContainer`, preset top-right, `grow_horizontal = BEGIN`, margen 16): un `HeroPortrait` por héroe.
- **Abajo-derecha** `Minimap` (sin cambios, preset bottom-right, margen 16).
- **Abajo-centro** libre (la barra vieja desaparece).
- `BuildingMenu`: contextual, posicionado sobre el slot en pantalla, clamped al viewport.
- `CharacterPopup`: `Control` full-rect (velo que captura clics = cerrar), panel centrado (`CenterContainer`).
- Tooltips de chips: ahora crecen hacia **abajo** (barra arriba).

## Fase 2 — Implementado (sesión 6)

| Sistema | Archivos | Qué |
|---|---|---|
| Retratos | `scripts/ui/hud/HeroPortrait.gd` (nuevo), `scripts/ui/hud/HealthBarStyle.gd` + `resources/ui/health_bar_style.tres` (nuevos) | `PanelContainer` armado en código: `CharacterData.portrait` (o círculo con la inicial si no hay), nombre y `ProgressBar` 0..1 sin números. `hp_changed` → tween de valor + color (verde > 60 %, amarillo 30–60 % inclusive, rojo < 30 %) y destello rojo (`modulate`) solo si bajó la vida. Umbrales/colores/tiempos en el Resource. Clic → `portrait_clicked`. |
| HUD | `scenes/HUD.tscn`, `HUDController.gd`, `StatPanelUI.gd` | Nuevo plano (Fase 1): `TopLeft` (barra de recursos + piso), `Portraits` (arriba-derecha, `grow_horizontal = BEGIN`), minimapa igual. `add_hero_portrait(stats, data)` apila uno por héroe (`_portraits` = `CharacterStats → HeroPortrait`); si `PlayerStats` cambia de `CharacterStats` se re-bindea el mismo retrato. Tooltips de chips crecen hacia abajo. |
| Popup | `scripts/ui/hud/CharacterPopup.gd` (nuevo) | Modal armado en código (hijo de `HUD/Control`, encima de todo menos `StatTooltip`). Velo que cierra al clic, botón X, Esc. Preview = primer frame `idle` de `sprite_frames` → `portrait` → marco vacío. Nombre, Nivel, Vida a/b, Ataque, Intervalo (y golpes/s), pasiva/activa. Botón "Mejoras" despliega la tabla. Refresca por `stats_changed`/`hp_changed`/`run_upgrades_changed`/`resource_changed` (solo si está visible). |
| Mejoras | `scripts/core/stats/UpgradeConfig.gd` + `resources/upgrades/run_upgrade_config.tres` (nuevos), `PlayerStats.gd`, `CharacterStats.gd`, `Player.gd`, `Main.gd`, `StatBalance.gd` | Fila por stat (vida máx, daño, vel. de ataque): nivel, actual → siguiente, costo (rojo si falta), "+" deshabilitado si falta o MAX. `PlayerStats.buy_run_upgrade(key)` = único camino: gasta con `ResourceManager.spend_resource`, sube nivel, aplica, emite `run_upgrades_changed` + `stats_changed`. `get_run_upgrade_preview(key)` arma la fila (la UI no calcula nada). |
| Construcción | `scripts/ui/BuildingMenu.gd`, `scenes/ui/BuildingMenu.tscn` (reescritos), `Module.gd`, `BuildingSlot.gd` | `TabBar` Producción/Defensa (índice = `Module.SlotType`), tarjeta por módulo: ícono de color, nombre, efecto, costo con ícono de Industria (rojo si falta), "Construir" deshabilitado si falta o el slot es de otro tamaño, tooltip nativo con descripción + efecto + vida + motivo. Slot elegido con contorno dorado (`BuildingSlot.set_highlighted`). Se re-arma con `resource_changed` mientras está abierto. API y flujo intactos (`open_menu`, `close_menu`, `_on_module_selected` → `spend_resource` → `slot.build`, sacudida si falla). Textos: `Module.DESCRIPTIONS` + `Module.describe_effect(type)` (derivado de los números del `CATALOG`). |
| Recursos | `ResourceManager.gd`, `GeneratorModule.gd`, `StatPanelUI.gd` | Chip = ícono + valor + `+N` verde (oculto si 0). `ResourceManager.get_turn_yield(key)` (base + generadores; `process_turn_production` ahora lo usa, mismo orden y montos) y señal nueva `production_changed`, emitida por `GeneratorModule` al configurarse y al destruirse (`notify_production_changed`). |
| Test | `tests/test_hud_ui.gd` (nuevo) | Umbrales, curva de costo, bonos, textos de efecto; en vivo (Main2d fallback + HUD): retrato (1, ratio tras daño/cura, clic abre popup), compras (gasta Ciencia, sube stats, llega al `HitboxComponent`, falla sin Ciencia, tope), re-aplicación al registrar otro `CharacterStats` (= piso nuevo), `BuildingMenu` (pestaña por slot, deshabilitadas sin Industria, se habilitan, defensa deshabilitada en slot mayor, highlight, construir Gen. Ciencia → `+4` en la barra). |

### Decisiones

- **Mejoras en Ciencia, por partida.** Ciencia no tenía sumidero; la tienda de Oro (pausa) es meta-progresión persistente y queda como está. No se duplicó lógica: las dos aplican vía `PlayerStats` → `CharacterStats` (`apply_modifier("hp")` para vida; ataque vía `set_attack`). Las mejoras de partida viven en el autoload (`run_upgrade_levels`), sobreviven a los pisos porque `refresh_stats()` las re-aplica al registrar el `Player` nuevo, y `Main._begin_new_run()` las resetea (Retry/nueva partida). No se guardan en el save (igual que los recursos).
- **Curva:** `round(5 · 1.5^nivel)` → 5, 8, 11, 17, 25 Ciencia; tope 5 niveles; +4 vida, +1 daño, −10 % del intervalo base por nivel (piso 0.2 s). Todo en el `.tres`.
- **Nivel del héroe** = 1 + mejoras de partida compradas (no hay XP).
- **`StatBalance.PLAYER_MAX_HP` 40 → 60**: con el tope viejo, héroe base 22 + tienda de Oro (+20) ya llegaba al clamp y las mejoras de vida no hacían nada. Si igual se llega al tope, la fila muestra MAX (`maxed` cuando actual == siguiente).
- **Ataque en `CharacterStats`** (`base_attack_*` desde `CharacterData`, `attack_*` actual, señal `attack_changed`); `Player` conecta `attack_changed → hitbox.configure` antes de `register()`. Antes el hitbox se configuraba una sola vez desde `CharacterData`.
- **Esc del popup:** el `_input` del popup lo consume con `set_input_as_handled()`. `HUDContainer` va después de `WorldContainer` en `Main.tscn`, así que el `_input` del HUD corre antes que el de `Main2d` → Esc cierra el popup y no abre la pausa. Con el popup cerrado, Esc = pausa como siempre.
- **El popup no pausa el juego**; el velo bloquea clics al mundo mientras está abierto.
- **Tooltips del menú de construcción = `tooltip_text` nativo** (no el `StatTooltip` del HUD).
- **`ThemeStyles` por `preload`** en los 3 scripts nuevos/reescritos: `ThemeManager.gd` es autoload sin `class_name`, su identificador no existe en `--script` y rompía compilar el HUD en el test. Mismo patrón que `StatBalanceScript` en `StorePanel`.
- HUD mitad en `.tscn` (layout estático: anclas/contenedores) y mitad en código (retratos, popup, tarjetas: dependen de datos), igual que el minimapa de la sesión 5.
- Reemplazados → `_deprecated/hud_v1/` (`HUD.tscn`, `BuildingMenu.gd`/`.tscn` viejos).

## Fase 3 — no hecha

Loops en el generador y tipos de sala siguen como diseño (sesión 5). Se priorizó cerrar y testear la UI.

## Verificación (sesión 6)

- Al empezar: `test_map_generator`, `test_map_flow`, `test_corridor_picking` OK.
- Al terminar: los 3 OK + `test_hud_ui` OK.
- Carga normal (con autoloads) de `Main.tscn`, `Main2d.tscn`, `HUD.tscn` con `--quit-after 90`: 0 `SCRIPT ERROR`/`ERROR` (fuera de Steam y leaks preexistentes). `HUD.tscn` solo: warnings esperados de "sin mundo".
- `gdparse` OK en todos los `.gd` tocados y el test.
- `.tscn`/`.tres` nuevos o reescritos revisados con script: sin ids de `ext_resource`/`sub_resource` duplicados, sin `ExtResource`/`SubResource` colgados, todos los `path=` existen, sin rutas de nodo duplicadas.
- `--editor --quit` para registrar las clases nuevas (su ruido de "external text editor" es de la config local del editor).
- **Nada visto en pantalla** (headless).

## Checklist manual F5 (sesión 6)

1. HUD: arriba-izquierda barra de recursos (ícono, valor, `+2`/`+2`/`+1` en verde, Polvo sin ganancia) y "Piso 1/5" debajo; arriba-derecha retrato del héroe (imagen del personaje) con barra verde sin números; abajo-derecha minimapa. Nada abajo al centro. Nada se pisa a 1280×720 ni a la resolución máxima.
2. Hover en los chips: tooltip debajo del chip, dentro de pantalla.
3. Recibir daño: la barra baja con animación y destello rojo del retrato; < 60 % amarilla, < 30 % roja.
4. Clic en el retrato: popup centrado con velo; Vida exacta a/b, Ataque, Intervalo, Nivel 1. Cerrar con X, clic afuera y Esc (Esc **no** abre la pausa). Con el popup cerrado, Esc abre la pausa.
5. "Mejoras": 3 filas. Con 10 de Ciencia: comprar Vida (−5, vida máx +4, Nivel 2), Daño (−5, los números de daño a enemigos suben 1); Vel. de ataque queda con costo rojo y "+" deshabilitado. Al juntar Ciencia el costo vuelve a color.
6. Bajar al piso 2: las mejoras siguen. Retry o nueva partida: se pierden.
7. Energizar una sala y clic en el slot mayor: contorno dorado en el slot, menú arriba del slot en la pestaña Producción, 3 tarjetas; pestaña Defensa con tarjetas grises (tooltip "Requiere un slot menor"). Slot menor: al revés.
8. Sin Industria: costos en rojo, botones grises. Construir Gen. Ciencia: el menú se cierra, el contorno vuelve a normal, la barra muestra `+4` en Ciencia. Si un Sapper lo destruye, vuelve a `+1`.
9. Clic derecho / clic afuera cierra el menú; clic en otro slot vacío lo reabre ahí.
10. Tienda de Oro (pausa) sigue funcionando (+2 vida máx).

## Riesgos a revisar antes de mergear (sesión 6)

- **Nada renderizado:** tamaños, colores, fuentes y el recorte del retrato (`KEEP_ASPECT_COVERED` sobre los PNG de retrato) a ojo.
- **`PLAYER_MAX_HP` 60:** cambia el clamp de la vida base del save y lo que muestra el selector de slots ("Vida base x/60").
- **Orden de `_input` para Esc:** depende de que `HUDContainer` siga después de `WorldContainer` en `Main.tscn`. En F6 de `Main2d` no hay HUD, sin conflicto.
- **Popup y muerte/victoria:** si el héroe muere con el popup abierto, queda abierto debajo del overlay (capa del HUD = 2). No se cierra solo.
- **`BuildingMenu` se reconstruye en cada cambio de Industria** mientras está abierto (3 tarjetas, barato; si el hover parpadea al entrar recursos, actualizar en sitio).
- **Tooltips nativos** del menú de construcción usan el tema por defecto de Godot.
- El `+N` por turno no incluye el polvo de descubrimiento (`FloorConfig.discovery_dust`): no es producción por turno.
- `run_upgrade_levels` no se guarda: salir al menú y continuar el slot = partida nueva (igual que los recursos).

## Pendiente / próximos pasos (sesión 7+)

1. Playtest visual del HUD nuevo (checklist arriba) y ajuste de tamaños.
2. Cerrar el popup en `player_died`/`victory_entered`.
3. Loops en el generador y tipos de sala (diseños de la sesión 5).
4. Sumidero para Comida (curar / subir de nivel, como dice su tooltip).
5. Más héroes: `HUDController.add_hero_portrait()` ya apila; falta que `PlayerStats` maneje varios `CharacterStats`.

---

# Sesión 7 — 2026-09-28 (sobre `session/opus-2026-09-28-6`, sin commit)

Reorientación DotE: recursos + construcción abajo, luz con clic central + oscuridad real, más Polvo y mapas más grandes, Nexo solo con la salida descubierta, progresión por niveles pagada en Comida.

## Fase 1 — Reconocimiento (qué había)

| Pieza | Estado al empezar |
|---|---|
| HUD | Recursos arriba-izquierda (`TopLeft/ResourcePanel`), retratos arriba-derecha, minimapa abajo-derecha. **Bug:** `HUDController.floor_label` apuntaba a `Control/FloorLabel` pero el nodo estaba en `Control/TopLeft/FloorLabel` → "Piso N/M" nunca se actualizaba (siempre "Piso 1"). |
| `BuildingMenu` | Flotante sobre el slot clickeado (`_reposition`); única entrada = clic en slot vacío. |
| Iluminación | `EnergyButton` (clic izquierdo) → `RoomZone.try_power_up()` (10 Polvo, permanente, sin apagar). `RoomLight` = overlay oscuro/rojo + `PointLight2D` cálido, pero **sin `CanvasModulate`**: la luz solo sumaba brillo, no había oscuridad real. La sala inicial empezaba apagada. |
| Módulos | `Module.is_active` solo significaba "no destruido"; generadores/torretas/trampas no dependían de la luz. |
| Descubrimiento | `FloorConfig.discovery_dust` 2 (+0.5/piso); mapas de 6 salas (+1/piso, máx 12). |
| Nexo | Clic con el héroe en la sala inicial → se recogía al instante; no dependía de la salida. |
| Mejoras | 3 filas independientes (vida/daño/vel.) pagadas en Ciencia; nivel = 1 + compras. |

## Fase 2 — Implementado

| Sistema | Archivos | Qué |
|---|---|---|
| HUD abajo | `scenes/HUD.tscn`, `HUDController.gd` | Nuevo `Control/BottomBar` (VBox anclado abajo-centro, crece hacia arriba): `BuildingMenu` acoplado arriba + `BottomRow` = `ResourcePanel` (mismos chips/ganancia) + `BuildPanel` ("Construir": **Producción** / **Defensa**). `TopLeft` queda solo con `FloorLabel` (ruta corregida). Tooltips de chips crecen hacia arriba. Retratos/popup/minimapa sin cambios de lugar. |
| Construcción | `scripts/ui/BuildingMenu.gd` | Dos entradas, una sola compra (`_on_module_selected`): (a) **abajo**: `open_category(tab)` → tarjetas "Elegir" → módulo *armado*, contorno dorado en todos los slots libres del tamaño correcto en salas encendidas → clic en uno = construye (`ModuleBuildSystem` → `open_menu(slot)` detecta el armado); (b) clic en slot vacío = flujo de sesión 6 (tarjetas "Construir", slot resaltado). Clic derecho cancela; clic izquierdo afuera cierra solo si no está armado (ese clic es la elección del slot). Si no hay slots libres lo dice el título. `_reposition` eliminado (el menú vive en el contenedor). API intacta + `open_category()`/`is_armed()`. |
| Luz con clic central | `RoomZone.gd`, `EnergyButton.gd/.tscn`, `RoomManager.gd`, `Minimap.gd` | MMB sobre una sala descubierta → `RoomZone.toggle_power()`: apagada → `try_power_up()` (10 Polvo, igual que antes); encendida → `power_down()` devuelve **lo pagado** (`_power_paid`; la inicial es gratis → no devuelve nada, no se fabrica Polvo). `EnergyButton` queda como cartel pasivo ("Clic central: encender (10 Polvo)", no pickable). Señal nueva `RoomManager.room_power_changed(zone_id, powered)` (burbujea `RoomZone.power_changed`); el minimapa la usa para redibujar también al apagar. |
| Módulos y luz | `Module.gd`, `ResourceManager.gd`, `TurretModule.gd`, `Enemy.gd` | `Module.powered` + `is_working()` (= `is_active and powered`). `RoomZone.set_powered` lo propaga a sus módulos y emite `production_changed` si hay generadores. En salas apagadas: generadores no suman, torretas no disparan, trampas no ralentizan. Siguen siendo objetivos de los enemigos (`is_active` sin tocar). |
| Oscuridad real | `MapVisualConfig.gd` (grupo "Dark canvas"), `RoomManager._ensure_dark_canvas()`, `resources/maps/unshaded_material.tres`, `ExitIndicator.gd`, `FloatingText.gd` | Un `CanvasModulate` (`RoomManager/DarkCanvas`, `dark_canvas_color` = 0.5/0.5/0.6) oscurece el canvas del mundo; las salas encendidas destacan por el `PointLight2D` que `RoomLight` ya tenía. No es negro: lo descubierto se sigue leyendo. El HUD (CanvasLayers) no se afecta. Marcador de salida y números flotantes usan material *unshaded*. Se desactiva con `dark_canvas_enabled = false`. |
| Sala inicial encendida | `Main2d.gd` | `set_zone_powered(start, true)` al armar el mapa (gratis). Como sus 3 slots aparecen en el centro, el Nexo subió 56 px (`Main2d.NEXO_OFFSET`). |
| Polvo / mapa | `FloorConfig.gd` | `dust_per_discovery` 2 → **4** (+0.5/piso igual). `base_room_count` 6 → **8**, `max_room_count` 12 → **14** (+1/piso igual). Sigue siendo árbol: sin loops ni tipos de sala. La salida sigue apareciendo solo al descubrir su sala (`ON_DISCOVERY`) y visible al llevar el Nexo. |
| Nexo | `NexoController.gd`, `Nexo.gd` | `get_block_reason()`: "Descubrí la salida antes de llevarte el Nexo" / "Acercate al Nexo para recogerlo" (texto flotante). Si es válido abre un `ConfirmationDialog` nativo ("El Nexo", explica bloqueo de puertas/oleadas/lentitud; **Recoger** / **Cancelar**); `confirm_pickup()` revalida y sigue el flujo de siempre (`pick_up_nexo` → `pick_up` → `start_extraction`). |
| Niveles del héroe | `PlayerStats.gd`, `UpgradeConfig.gd`, `run_upgrade_config.tres`, `CharacterPopup.gd`, `HUDController.gd` (tooltips) | `run_level` único: `level_up_hero()` gasta Comida y sube **las tres** stats juntas (+4 vida máx, +1 daño, −10 % intervalo). `get_level_up_preview()` arma todo lo que muestra el popup. Costo `round(8·1.4^n)` → 8, 11, 16, 22, 31 Comida, 5 subidas (nivel 1 → 6). Popup: sección fija "Subir de nivel: N → N+1", fila por stat actual → siguiente, botón "Subir de nivel (X Comida)" (gris/rojo si falta, "Nivel máximo" al tope). Tooltips: Comida = subir de nivel; Ciencia = sin uso por ahora. |
| Tests | `tests/test_hud_ui.gd`, `tests/test_map_flow.gd` | HUD: barra inferior (padres, botones, piso, sin solape con minimapa), botón de nivel del popup, subida de nivel (Comida y no Ciencia, las tres stats, hitbox, tope, compat `buy_run_upgrade`), flujo armado desde Defensa (contornos, construye, gasta, limpia). Mapa: `DarkCanvas`, sala inicial encendida, apagarla no reembolsa, encender con MMB cuesta 10, apagar una pagada reembolsa 10, contorno "alcanza" al apagar; Nexo bloqueado antes de la salida (y `confirm_pickup` no lo saltea), luego sí inicia la extracción. |

### Decisiones

- **Construcción "armada" en vez de otro menú**: el `BuildingMenu` existente se acopló a la barra y ganó un modo sin slot; la compra sigue en un único lugar. Sin estructuras nuevas.
- **Reembolso al apagar** (como DotE): sin eso el toggle no tiene sentido. Solo se devuelve lo pagado (la inicial no).
- **Módulos en sala apagada = inertes** (`powered`), no invulnerables: sin esto, encender → construir → apagar (reembolso) dejaba generadores gratis.
- **Dark canvas = `CanvasModulate` + las luces existentes**: ningún sistema paralelo; el overlay rojo de peligro sigue igual.
- **Nivel en vez de stats**: se mantienen `buy_run_upgrade(key)` (ahora sube de nivel), `get_run_upgrade_level(key)`, `get_run_upgrade_preview(key)`, `run_upgrade_levels` (vista de solo lectura), `get_hero_level()`, `reset_run_upgrades()` y `run_upgrades_changed` (ahora `("level", n)`).
- **Multi-héroe (solo preparado)**: el nivel vive en `PlayerStats.run_level` para el único héroe; un comentario `ponytail:` marca que pasa a un dict por héroe con la API recibiendo el `CharacterStats` (el popup ya abre con `stats` + `data` propios y `add_hero_portrait` ya apila).
- Snapshots de lo reemplazado en `_deprecated/session6/` (README actualizado).

## Verificación (sesión 7)

- Al empezar: los 4 tests OK.
- Al terminar: `test_map_generator` (1000 mapas con los tamaños nuevos), `test_map_flow`, `test_corridor_picking`, `test_hud_ui` → OK.
- Carga normal de `Main.tscn`, `Main2d.tscn`, `HUD.tscn` (`--quit-after 90`): solo ruido de Steam; `HUD.tscn` solo, los warnings esperados de "sin mundo".
- Ruido de `--script` (`Compilation failed` en menús por `ThemeManager`/`PauseMenu`): idéntico antes y después (17 líneas en `test_hud_ui` también con el árbol original).
- `gdparse` OK en todos los `.gd` tocados; `--editor --quit` para reindexar.
- Bug encontrado por el test nuevo y corregido: `RoomLight` no reevaluaba el contorno "alcanza el Polvo" al apagarse una sala.
- **Nada visto en pantalla** (headless).

## Checklist manual F5 (sesión 7)

1. Abajo al centro: recursos (ícono, valor, `+N`) y a la derecha "Construir: Producción | Defensa". Arriba-izquierda "Piso 1/5". Minimapa abajo-derecha sin pisarse con la barra a 1280×720 y a la máxima.
2. Hover en los chips: tooltip **arriba** del chip.
3. La sala inicial arranca iluminada; el resto y las salas descubiertas apagadas se ven más oscuras pero legibles; el HUD no se oscurece. Si el centro de la luz queda quemado, bajar `warm_light_energy` o subir `dark_canvas_color` en `map_visual_config.tres`.
4. Clic central en sala oscura: −10 Polvo, se enciende, aparecen slots. Otra vez: se apaga y vuelve el Polvo. En la inicial: se apaga sin devolver nada. Sin Polvo: "Polvo insuficiente". Clic izquierdo sobre el cartel mueve al héroe (ya no enciende).
5. Construir un Gen. Ciencia y apagar su sala: la ganancia `+N` de Ciencia baja; al encender vuelve. Torreta en sala apagada no dispara.
6. "Producción" → tarjetas "Elegir" sobre la barra → elegir una: slots mayores libres de salas encendidas en dorado + título explicativo → clic en uno: se construye y se gasta Industria. Clic derecho cancela. Sin slots libres el título lo avisa. Clic en un slot vacío sigue abriendo el menú con "Construir".
7. Descubrir una sala da +4 Polvo (piso 1). Mapas de 8 salas en el piso 1.
8. Nexo antes de ver la salida: "Descubrí la salida…". Con la salida descubierta y el héroe en la sala inicial: diálogo "El Nexo" → Cancelar no hace nada; Recoger inicia la extracción como antes. Fuera de la sala: "Acercate al Nexo…".
9. Retrato → popup: "Subir de nivel: 1 → 2", tres filas actual → siguiente, botón "Subir de nivel (8 Comida)". Subir: −8 Comida, Ciencia intacta, vida/daño/velocidad suben juntos, Nivel 2. Sin Comida: botón gris/rojo. En nivel 6: "Nivel máximo".
10. Bajar de piso: el nivel se mantiene; Retry/nueva partida: vuelve a 1.

## Riesgos a revisar antes de mergear (sesión 7)

- **Nada renderizado**: intensidad del `CanvasModulate` vs `PointLight2D` en GL Compatibility, legibilidad de enemigos/héroe en salas oscuras, tamaño de la barra inferior.
- **Diálogo del Nexo**: `ConfirmationDialog` nativo (tema por defecto, ventana embebida); no pausa el juego.
- **Esc con un módulo armado**: abre la pausa; al volver sigue armado (clic derecho lo cancela).
- **Balance**: 4 Polvo por sala + inicial gratis + reembolso → sobra más Polvo; la Ciencia vuelve a no tener sumidero.
- **Enemigos**: la sala inicial encendida ya no es "oscura" (menos invasiones al principio; no spawnean ahí salvo que el jugador la apague).
- `run_upgrade_levels` ya no es asignable (nadie lo asignaba fuera de `PlayerStats`).
- Módulos de salas apagadas siguen siendo atacables por Sappers aunque no funcionen (decisión).

## Pendiente / próximos pasos (sesión 8+)

1. Playtest visual (checklist arriba) y ajuste de `dark_canvas_color`/`warm_light_energy`.
2. Sumidero para Ciencia (investigación).
3. Cerrar popup/menú de construcción en `player_died`/`victory_entered` (pendiente de la sesión 6).
4. Loops en el generador y tipos de sala (diseños de la sesión 5).
5. Multi-héroe: `run_level` por héroe + `PlayerStats` con varios `CharacterStats`.

# Sesión 8 — 2026-09-28 (rama `session/opus-2026-09-28-8`, sobre la sesión 7, sin commit)

Cámara libre estilo DotE y construcción solo desde la barra inferior (modo armado con fantasma).

## Fase 1 — Reconocimiento (qué había)

| Pieza | Estado al empezar |
|---|---|
| Cámara | Un `Camera2D` hijo de `Player.tscn`, sin script: solo `position_smoothing` (10). Seguía al héroe por ser hijo. Sin zoom, sin límites, sin paneo. Las acciones `move_up/down/left/right` (WASD) existían en `project.godot` sin uso. |
| Construcción (a) | Clic en slot vacío → `BuildingSlot.slot_clicked` → `ModuleBuildSystem` → `HUDController.open_building_menu` → `BuildingMenu.open_menu(slot)` → tarjetas "Construir" para ese slot. El slot marcaba el clic como manejado → tapaba el clic de mover al héroe. |
| Construcción (b) | `open_category(tab)` → "Elegir" → módulo armado, slots libres resaltados → clic en slot (mismo camino `open_menu`) construye. Clic derecho cancelaba. |
| Esc | Con un módulo armado, Esc llegaba a `Main2d._input` y abría la pausa (riesgo anotado en la sesión 7). |
| Fantasma / atajos | No existían. |

## Fase 2 — Implementado

| Sistema | Archivos | Qué |
|---|---|---|
| Cámara | `scripts/core/camera/GameCamera.gd` (nuevo), `scenes/Player.tscn` | El mismo nodo `Player/Camera2D` con script y `top_level = true` (no hereda la posición del héroe). Sigue al héroe hasta que el jugador panea; primer frame `reset_smoothing()` (sin barrido desde 0,0). Paneo con `move_*` (WASD + flechas) y bordes de pantalla (no si `gui_get_hovered_control()` ≠ null: BottomBar, popup, minimapa, retratos). Velocidad ÷ zoom. Rueda → `set_target_zoom()` con clamp e interpolación exponencial. Posición clampeada a las zonas descubiertas + margen (`refresh_bounds()` en `room_revealed`). Tecla **C** (`camera_recenter`) vuelve a seguir. `PROCESS_MODE_PAUSABLE`: se congela en pausa/muerte/victoria. Piso nuevo = Player nuevo → vuelve a seguir. |
| Config | `scripts/core/camera/CameraConfig.gd`, `resources/camera/camera_config.tres` (nuevos) | `pan_speed` 700, `edge_scroll_enabled`, `edge_scroll_margin` 16, `zoom_min` 0.5, `zoom_max` 2, `zoom_step` 1.15, `zoom_smoothing` 10, `bounds_margin` 160. Exportado en `GameCamera.config`. |
| Input | `project.godot` | Flechas agregadas a `move_*`; acción nueva `camera_recenter` (C). |
| Minimapa | `scripts/ui/hud/Minimap.gd` | `MOUSE_FILTER_STOP` + clic izquierdo → celda → mundo → `GameCamera.focus_on()` (deja de seguir). Al ser STOP también bloquea el scroll por borde encima. |
| Slots | `scripts/world/BuildingSlot.gd` | `input_pickable = false` por defecto: sin armar, el clic cae en la `RoomZone` (mueve al héroe). `set_ghost(type, ok)`/`clear_ghost()`: el `Icon` de la propia escena del módulo, separado antes de entrar al árbol (no corre `_ready`, no entra a `"generators"`), color del tipo + tinte verde/rojo al 60 %. `room_can_build()`. `build()` limpia el fantasma. |
| Menú | `scripts/ui/BuildingMenu.gd` | Quitado el flujo por slot (`_slot`, tarjetas "Construir", título por slot, resaltado del slot elegido). `open_menu(slot)` solo construye si hay módulo armado (sin armar no hace nada). Armado: resalta los libres que encajan en salas encendidas y vuelve pickables **todos** los slots vacíos con fantasma al pasar el cursor; rojo → texto flotante con `get_block_reason()`: "Tamaño incorrecto: requiere un slot …", "Sala apagada", "Falta Industria". Clic en slot inválido: texto + sacudida, sigue armado. Se re-arma en `room_power_changed`. Esc (`ui_cancel`) con el menú visible → cierra y consume el evento (no llega a la pausa). Clic derecho cancela. Teclas **1-9** eligen la tarjeta N (el nombre muestra "1. …"). API: `open_category`, `is_armed`, `open_menu`, `close_menu` + `get_block_reason`. |
| Ruta | `ModuleBuildSystem.gd`, `HUDController.gd` | Solo comentarios: la ruta slot → HUD → `open_menu` sigue, pero solo se usa armado. |
| Tests | `tests/test_hud_ui.gd`, `tests/test_map_flow.gd` | HUD: slot sin armar no pickable y su clic no abre/construye/gasta; tecla 3 no arma sin Industria y sí con; fantasma verde/rojo y los tres motivos; clic armado sin Industria no construye ni desarma; construye, gasta, sube el yield, limpia; Esc cancela y **no** pasa a la pausa (sonda de input entre Main2d y HUD), Esc con el menú cerrado sí pasa; Defensa → Torreta construye. Mapa (generado y fallback): `GameCamera` `top_level` siguiendo al héroe, zoom clampeado a min/max, los límites contienen al héroe con margen, `clamp_to_bounds` de un punto lejano cae adentro, `focus_on` deja de seguir y queda clampeado, `recenter` vuelve, los límites crecen al explorar. |

### Decisiones

- **"Modelo actual" de cámara** = el `Camera2D` existente en `Player.tscn`; se le puso script + `top_level` en vez de moverlo a `Main2d` (piso nuevo = Player nuevo = cámara nueva siguiendo, gratis).
- **Seguimiento**: sigue al héroe hasta el primer paneo; después queda libre hasta apretar C (no se re-engancha sola cuando el héroe se mueve). Lo más simple y parecido a DotE.
- **Sin arrastre con el mouse** (derecho = cancelar, central = luz): paneo solo con teclado + bordes.
- **Zoom al centro** de la pantalla, no al cursor.
- **Clamp del centro** de la cámara (no los `limit_*` nativos, que clampean los bordes de la vista): funciona igual con mapas más chicos que la pantalla.
- **Recentrar = C**: Espacio queda libre para la pausa táctica propuesta.
- **Causa raíz del clic en slot**: slots no pickables salvo armados (en vez de un guard en `open_menu`), así el clic sin armar mueve al héroe como en el resto de la sala.
- **Fantasma = el `Icon` real del módulo**: si mañana el módulo tiene sprite, el fantasma lo sigue sin tocar código.
- Colores del fantasma como `const` en `BuildingSlot` (como el resto de colores del slot); lo tunable de cámara, en recurso.
- Snapshots en `_deprecated/session7/` (README actualizado).

## Verificación (sesión 8)

- Al empezar: los 4 tests OK.
- Al terminar: `test_map_generator`, `test_map_flow`, `test_corridor_picking`, `test_hud_ui` → OK (exit 0).
- Ruido `SCRIPT ERROR` de `--script` (ThemeManager/PauseMenu): idéntico al árbol original (11 / 35 / 10 líneas, mismos tipos), medido con `git stash`.
- `Main.tscn --quit-after 90`: solo ruido de Steam.
- `gdparse` OK en todos los `.gd` tocados/nuevos; `--editor --quit` para reindexar `GameCamera`/`CameraConfig`.
- Trampa del test encontrada y corregida: con `PauseMenu` nulo bajo `--script`, el primer chequeo de Esc abortaba la función en silencio (y el test igual decía OK) → reemplazado por una sonda de input.
- **Nada visto en pantalla** (todo headless): scroll por borde, rueda, suavizado y fantasma no se probaron con mouse real.

## Checklist manual F5 (sesión 8)

1. Al entrar al piso la cámara está sobre el héroe, sin barrido desde la esquina.
2. WASD y flechas panean; el mouse contra cada borde panea; sobre la barra inferior, retratos, popup o minimapa **no** panea. La velocidad se siente igual con zoom in/out.
3. Rueda: zoom suave, se detiene en 0.5× y 2×. La rueda sobre el HUD no hace zoom.
4. Panear lejos: la cámara se frena a ~160 px de las salas descubiertas; al abrir puertas el límite crece.
5. C: vuelve al héroe y lo sigue mientras camina.
6. Clic en el minimapa: la cámara va a ese punto (clampeada).
7. Clic izquierdo en un slot vacío sin nada armado: el héroe se mueve; no se abre nada.
8. "Producción" → 1/2/3 o "Elegir": slots mayores libres en dorado; cursor encima: fantasma verde sobre el mayor, rojo + "Tamaño incorrecto…" sobre un menor; sala encendida y luego apagada: "Sala apagada"; sin Industria: "Falta Industria". Clic en uno verde: se construye y se gasta Industria.
9. Armado + Esc: cancela, **no** abre la pausa. Esc otra vez: pausa. Armado + clic derecho: cancela.
10. En pausa (Esc), WASD no mueve la cámara.
11. Bajar de piso: la cámara arranca sobre el héroe del piso nuevo.

## Riesgos a revisar antes de mergear (sesión 8)

- **Nada renderizado**: `gui_get_hovered_control()` depende de que todo Control decorativo que cubra la pantalla sea `MOUSE_FILTER_IGNORE`; uno nuevo que no lo sea mata el scroll por borde.
- Si el cursor queda en un borde/esquina al entrar, la cámara panea sola → `edge_scroll_enabled = false` en el `.tres` si molesta.
- El fantasma se calcula al entrar el cursor; si cambia la Industria con el cursor quieto no se repinta hasta salir/entrar.
- Texto flotante del motivo en cada entrada del cursor: puede spamear al barrer slots.
- Las salas nunca encendidas no tienen slots, así que "Sala apagada" solo aparece en salas encendidas antes y apagadas después.
- `project.godot` editado a mano (flechas + `camera_recenter`): si el editor estaba abierto, recargar el proyecto.
- Sigue el pendiente de la sesión 6: popup/menú no se cierran solos en muerte/victoria.

## Opcionales propuestos (no implementados)

- **Pausa táctica con Espacio**: `get_tree().paused` congela también la construcción; lo simple es `Engine.time_scale = 0` (Tweens/Timers/movimiento lo respetan, el HUD sigue respondiendo) + etiqueta "PAUSA". ~15 líneas en `Main2d._input`. Ojo: la cámara usa `delta` → también se congelaría; habría que escalar su delta.
- **Mover al héroe con clic derecho** fuera del modo armado: aceptar el botón derecho en `RoomZone.input_event` cuando `not is_armed()`. Choca con "clic derecho cierra el menú no armado".
- **Cerrar popup/menú en `player_died`/`victory_entered`**: conectar en `HUDController._ready` → `character_popup.close()` + `building_menu.close_menu()`. ~4 líneas.

## Pendiente / próximos pasos (sesión 9+)

1. Playtest visual (checklist arriba) y ajuste de `camera_config.tres`.
2. Decidir los opcionales de arriba.
3. Pendientes de la sesión 7: sumidero de Ciencia, loops/tipos de sala, multi-héroe (la cámara sigue a `get_parent()`: con varios héroes, seguir al seleccionado).

---

# Sesión 9 — 2026-09-28 (rama `session/opus-2026-09-28-9`, sobre la sesión 8, sin commit)

Zoom más cercano, pausa táctica con Espacio, mover con clic derecho y cierre de popup/menú en muerte/victoria.

## Fase 1 — Reconocimiento (qué había)

| Pieza | Estado al empezar |
|---|---|
| `CameraConfig` | pan 700, borde 16 px, zoom 0.5–2 (paso 1.15, suavizado 10), `bounds_margin` 160. `.tres` vacío (todo default). Sin zoom inicial: arrancaba en 1×. |
| `GameCamera` | `_process` con `delta` escalado + suavizado nativo de `Camera2D` (también escalado) → con `time_scale = 0` se congelaba entera. |
| `Main2d._input` | Solo `ui_cancel` → `pause_menu.toggle()` (si activo o menú abierto), consumía el evento. Espacio sin uso (libre desde la sesión 8). |
| `RoomZone.input_event` | Izquierdo → `clicked` (mover), central → `toggle_power()`; derecho ignorado. Respeta `is_input_handled()`. |
| `BuildingMenu._input` | Clic derecho cerraba el menú armado o no, sin consumir. |
| Muerte/victoria | Popup del héroe y menú de construcción quedaban abiertos (pendiente desde la sesión 6). |

## Fase 2 — Implementado

| Sistema | Archivos | Qué |
|---|---|---|
| Zoom | `CameraConfig.gd`, `camera_config.tres`, `GameCamera.gd` | `default_zoom` (1.5) en el grupo Zoom, aplicado en `_ready` (antes del primer frame, clampeado). `.tres`: `zoom_min` 1.0, `zoom_max` 3.0. `bounds_margin` 160 y borde 16 px sin cambios (ver Decisiones). |
| Cámara en tiempo real | `GameCamera.gd` | `delta` propio con `Time.get_ticks_usec()` (tope 0.1 s) para paneo y zoom; suavizado nativo apagado mientras `time_scale == 0` (si no, la cámara no se mueve en pantalla). |
| Pausa táctica | `project.godot`, `Main2d.gd`, `Main.gd` | Acción `tactical_pause` (Espacio). `Main2d._input` alterna `_tactical_paused` solo si el juego está ACTIVE y vivo, y consume el evento (un botón con foco no se "aprieta" con Espacio). `_apply_time_scale()`: `time_scale = 0` solo si táctica + ACTIVE; se re-aplica en `GameStateManager.state_changed` → Esc/muerte/victoria corren a 1 (sus overlays animan) y al volver a ACTIVE se recupera la pausa táctica. `time_scale = 1` en `Main2d._exit_tree` y en `Main.gd` junto a cada `paused = false` (volver al menú, reintentar, bajar de piso), antes del fundido. |
| Etiqueta PAUSA | `HUDController.gd` | `PauseLabel` creada en código (arriba al centro, 32 px, `MOUSE_FILTER_IGNORE`); `Main2d` la prende/apaga con `call_group("hud", "set_pause_label", v)`. |
| Feedback en pausa | `RoomLight.gd`, `FloatingText.gd`, `BuildingMenu.gd` | `set_ignore_time_scale()` en el tween de encendido/apagado de sala, el texto flotante y la sacudida del menú: se ven durante la pausa. |
| Clic derecho | `RoomZone.gd`, `BuildingMenu.gd` | `RoomZone`: derecho = izquierdo (`clicked`). `BuildingMenu`: armado → derecho cancela **y consume** (así no llega al picking y no mueve); sin armar → no hace nada (el héroe se mueve, el menú sigue abierto; se cierra con Esc o clic izquierdo afuera). |
| Cierre fin de piso | `HUDController.gd` | `PlayerStats.player_died` y `GameStateManager.victory_entered` → `close_popups()` (`character_popup.close()` + `building_menu.close_menu()`). |
| Tests | `tests/test_map_flow.gd`, `tests/test_hud_ui.gd` | Mapa: zoom inicial == `default_zoom` clampeado y dentro de min/max. HUD: Espacio → `time_scale` 0 + etiqueta; la cámara panea (`move_right` real) y hace zoom a `time_scale` 0; armar (tecla 2) + construir Trampa en pausa; apagar/encender sala con clic central en pausa; el popup abre en pausa; Esc (`request_pause`) → 1 y etiqueta oculta, Espacio ahí no alterna, resume → vuelve a 0; Espacio otra vez → 1. Derecho sin armar: el menú sigue abierto, el evento pasa la sonda y la zona emite `zone_clicked`; derecho armado: cancela y la sonda no lo ve (consumido). Victoria y muerte cierran popup + menú; la muerte baja `time_scale` a 1. `time_scale` 1 tras sacar `Main2d` del árbol. `EscProbe` → `InputProbe` (también registra el derecho). |

### Decisiones

- **Valor al reanudar = 1.0**, no "el previo": hoy no existe otra velocidad de juego; si aparece un x2, guardar el valor en `_apply_time_scale`.
- **Esc pausa por completo a `time_scale` 1** (el árbol ya está pausado, y así los tweens del menú/overlays no se congelan); la pausa táctica vive en `_tactical_paused` y vuelve sola en `state_changed` → ACTIVE.
- **Espacio solo se consume si alterna**: con el menú de pausa u overlays arriba queda como `ui_accept` para sus botones. Los `ConfirmationDialog` (Nexo) son ventanas embebidas que reciben el teclado antes que `Main2d`.
- **En pausa táctica todo lo que es "orden" sigue permitido**, incluido abrir puertas (avanza el turno) y dar la orden de mover (el tween queda congelado hasta reanudar). Lo más simple; restringir puertas es una línea en `PlayerActionController._open_group` si molesta.
- **Etiqueta por `call_group("hud", …)`** desde `Main2d` en vez de polling: el HUD es pausable y con polling quedaba "PAUSA" pegado sobre el overlay de muerte.
- **Derecho sin armar no cierra el menú**, ni siquiera un clic derecho afuera: cerrar = Esc o clic izquierdo afuera (lo pedido).
- **`bounds_margin` 160 y borde 16 px sin tocar**: el margen es en mundo (a 1.5× = 240 px de pantalla), el borde es en píxeles de pantalla y la velocidad ya se divide por el zoom (700 px de pantalla/s a cualquier zoom). Tunables en el `.tres` si el playtest dice otra cosa.
- **Tweens de feedback en tiempo real** (luz, texto, sacudida): con `time_scale` 0 encender una sala o el texto "Falta Industria" no se verían hasta reanudar. El pulso rojo de peligro y la barra de HP siguen escalados (se congelan con el juego, a propósito).
- Snapshots en `_deprecated/session8/` (README propio + línea en `_deprecated/README.md`; `project.godot` guardado como `.txt`).

## Verificación (sesión 9)

- Al empezar: los 4 tests OK.
- Al terminar: `test_map_generator`, `test_map_flow`, `test_corridor_picking`, `test_hud_ui` → OK (exit 0). Ruido `SCRIPT ERROR` idéntico al baseline (0 / 11 / 35 / 10).
- Mutación: sin el `set_input_as_handled()` del derecho armado, `test_hud_ui` falla ("armed right click must be consumed…").
- Hallazgo: tras `root.push_input()` de un clic, `is_input_handled()` queda `true` (Godot lo encola para el picking) → los tests usan una sonda de input y una tecla dummy (`_clear_handled`) antes de llamar a `RoomZone._on_input_event` directo.
- `gdparse` OK en todos los `.gd` tocados.
- `Main.tscn --quit-after 90`: exit 0, solo ruido de Steam. `Main2d.tscn --quit-after 90`: 0 `SCRIPT ERROR` (igual que antes).
- **Nada visto en pantalla** (todo headless): zoom, etiqueta, pausa, clic derecho real y picking bajo `time_scale` 0 no se probaron con mouse/teclado reales.

## Checklist manual F5 (sesión 9)

1. Al entrar al piso la cámara arranca más cerca (1.5×) y sin barrido; la rueda va de 1× a 3×.
2. Espacio: aparece "PAUSA" arriba al centro; héroe, enemigos, torretas y timers se detienen.
3. En pausa: WASD/bordes panean y la rueda hace zoom sin tirones.
4. En pausa: Producción/Defensa, 1-9, fantasma verde/rojo, construir (gasta Industria), clic central enciende/apaga sala (la luz se ve cambiar), retrato → popup y subir de nivel.
5. En pausa, clic en otra sala: el héroe no se mueve hasta volver a apretar Espacio, y ahí camina.
6. Pausa táctica + Esc: el menú de pausa anima normal; Espacio dentro del menú no saca "PAUSA" ni rompe botones; al volver sigue la pausa táctica.
7. Clic derecho en una sala sin armar: el héroe va. Con el menú abierto sin armar: el héroe va y el menú sigue abierto; Esc o clic izquierdo afuera lo cierran.
8. Armado + clic derecho sobre una sala: cancela y el héroe **no** se mueve.
9. Con popup y menú abiertos, morir: se cierran; ganar el piso: se cierran.
10. Pausa táctica activa y morir / reintentar / bajar de piso / salir al menú: lo siguiente corre a velocidad normal y los fundidos animan.
11. La etiqueta "PAUSA" no atrapa clics (el clic llega al mundo y el scroll por borde funciona debajo).

## Riesgos a revisar antes de mergear (sesión 9)

- **Picking a `time_scale` 0**: el picking de `Area2D` corre en el paso físico; Godot sigue contando pasos físicos con delta 0, así que debería andar, pero **no se verificó con clics reales** (los tests llaman `_on_input_event` / señales). Es lo primero a probar en F5.
- Un segundo clic de mover durante la pausa se ignora (`_action_in_flight`: el primer tween está congelado).
- Abrir puertas en pausa táctica avanza el turno y puede disparar invasiones (congeladas hasta reanudar).
- Tweens que siguen escalados (HP del retrato, destello de invasión, flash de daño) quedan quietos en pausa; si alguno se nota raro, `set_ignore_time_scale()`.
- `project.godot` editado a mano (`tactical_pause`): recargar el proyecto si el editor estaba abierto.
- Si en el futuro se agrega otra velocidad de juego, `_apply_time_scale` la pisa con 1.0.

## Pendiente / próximos pasos (sesión 10+)

1. Playtest F5 con los checklists de las sesiones 8 y 9, y ajuste de `camera_config.tres`.
2. Decidir si las puertas se bloquean en pausa táctica.
3. Pendientes de la sesión 7: sumidero de Ciencia, loops/tipos de sala, multi-héroe.

---

# Sesión 10 — 2026-09-28 (rama `session/opus-2026-09-28-10`, sobre la sesión 9, sin commit)

Investigación simple como sumidero de Ciencia: 7 investigaciones en 2 tiers, 2 módulos bloqueados, 4 mejoras globales, panel "Investigar" en la barra inferior.

## Fase 1 — Reconocimiento (qué había)

| Pieza | Estado al empezar |
|---|---|
| Módulos | `Module.CATALOG` (dict const por `ModuleType`: hp, label, slot MAJOR/MINOR, `cost` en Industria, números de efecto, escena). Generadores 6 (+3 de su recurso), Ballesta 4 (15 de daño cada 1 s), Trampa 3. Todos libres desde el inicio. |
| Estado de la partida | Recursos en el autoload `ResourceManager` (`_resources`); niveles del héroe en el autoload `PlayerStats` (`run_level`). Los dos sobreviven al cambio de piso (Main2d/HUD se recrean) y se resetean en `Main._begin_new_run()` (`reset_resources()` + `reset_run_upgrades()`), que llaman `start_gameplay()` y `reload_gameplay()` (Retry); `advance_floor()` no. |
| `BuildingMenu` | `_populate()` recorre `Module.CATALOG`, filtra por pestaña (= `SlotType`) y arma una tarjeta por módulo en `_make_card` (ícono de color, nombre con atajo, efecto, costo en Industria, botón "Elegir" deshabilitado si no alcanza). 1-9 aprietan el botón si no está deshabilitado. `get_block_reason(slot)`: sin armar / tamaño / sala apagada / Industria. |
| Ciencia | +1 por turno de base, +3 por Gen. Ciencia, 10 al inicio. Sin ningún uso (tooltip "todavía sin uso"). |
| Bonos a tocar | Generadores: `ResourceManager._calculate_module_bonus()` suma `yield_amount`. Torreta: export `damage` fijo en 15. Luz: `RoomZone.POWER_COST` const 10 (también en `RoomLight`, `RoomPowerSystem` y el texto de `EnergyButton.tscn`). Descubrimiento: `FloorManager.on_room_discovered()` ← `FloorConfig.discovery_dust()`. |

## Fase 2 — Implementado

| Sistema | Archivos | Qué |
|---|---|---|
| Datos | `scripts/core/research/ResearchEntry.gd`, `ResearchConfig.gd`, `resources/research/research_config.tres` | `ResearchEntry` (Resource): `id`, `display_name`, `description`, `cost` (Ciencia), `prerequisite` (id o ""), `effect` (`UNLOCK_MODULE`, `GENERATOR_YIELD_PCT`, `TURRET_DAMAGE`, `POWER_COST`, `DISCOVERY_DUST`), `value`, `module` (solo para desbloqueo) y `describe_effect()`. `ResearchConfig`: `entries` + `get_entry(id)` / `get_unlock_entry(module)`. Mismo patrón que `MapLayout`/`RoomData`. |
| Árbol | `research_config.tres` | T1: Instrumental arcano (6, desbloquea Gen. Ciencia), Planos de ballesta (8, desbloquea Ballesta), Engranajes afinados (10, +25% generadores), Lentes de polvo (10, −3 Polvo por luz), Cartografía (8, +1 Polvo por descubrimiento). T2: Sobrecarga (30, otro +25%, requiere Engranajes), Virotes estriados (25, +10 de daño de torreta, requiere Planos). Total: 97 de Ciencia. |
| Estado | `ResourceManager.gd`, `Main.gd` | `research_config`, `is_researched`, `get_research_block_reason` ("Investigada" / "Requiere: X" / "Falta Ciencia"), `can_research`, `research` (gasta solo Ciencia vía `spend_resource`), `is_unlocked(module)`, `get_bonus(effect)` (suma de los `value` investigados), `reset_research()`, señal `research_changed` (+ `production_changed` para el "+N"). `Main._begin_new_run()` llama `reset_research()` junto a `reset_run_upgrades()`. |
| Bonos | `ResourceManager.gd`, `TurretModule.gd`, `RoomZone.gd`, `RoomLight.gd`, `EnergyButton.gd`, `RoomPowerSystem.gd`, `FloorManager.gd` | Generadores: `_calculate_module_bonus` = `roundi(suma × (1 + GENERATOR_YIELD_PCT))` → llega a `get_turn_yield` (HUD) y a `process_turn_production` (lo que se paga). Torreta: `get_damage()` = `damage` + bono, leído en cada disparo (vale también para torretas ya construidas). Luz: `RoomZone.get_power_cost()` estático = `max(1, POWER_COST − bono)`; `try_power_up` paga eso y `_power_paid` guarda lo pagado (reembolso exacto); el contorno "pagable" de `RoomLight` y el cartel de `EnergyButton` lo leen y se refrescan con `research_changed`. Descubrimiento: `FloorManager.on_room_discovered` suma el bono a `config.discovery_dust()`. |
| Bloqueo | `BuildingMenu.gd`, `StatIcon.gd` | `BuildingMenu.get_lock_reason(module)` (estático) → "Requiere: <investigación>". Tarjeta bloqueada: candado (`StatIcon`, tipo nuevo `"lock"`) sobre el ícono, el efecto se reemplaza por el motivo, tooltip con el motivo, botón deshabilitado (así 1-9 la saltean). `_arm` rechaza módulos bloqueados y `get_block_reason` informa el bloqueo antes que el resto → `_build_armed_into` no construye ni cobra. Se repuebla con `research_changed`. |
| UI | `HUD.tscn`, `HUDController.gd`, `scripts/ui/hud/ResearchPanel.gd` | Botón "Investigar" en `BuildButtons`, al lado de Producción/Defensa. `ResearchPanel` (armado en código, como `CharacterPopup`) se acopla en `BottomBar` entre `BuildingMenu` y `BottomRow`, con el mismo estilo de panel y tarjetas. Grilla de 2 columnas: "T1/T2 · nombre", efecto, estado (Disponible / Falta Ciencia / Requiere: X / Investigada), costo con ícono de Ciencia y botón "Investigar"/"Hecho". Se repuebla con `research_changed` y con cada cambio de Ciencia. Abrir uno cierra el otro (Investigar ↔ Producción/Defensa). Esc y clic derecho lo cierran y se consumen. `close_popups()` (muerte/victoria) también lo cierra. Tooltip de Ciencia actualizado. |
| Tests | `tests/test_hud_ui.gd` | `_check_research`: 6-8 entradas; cada T2 con un prerrequisito que existe y es más barato; ≥2 módulos bloqueados y Gen. Industria/Comida/Trampa libres; la tarjeta bloqueada tiene candado + "Requiere"; ni la tecla 3 ni `_arm` arman; forzando `_armed_type`, `get_block_reason` da el bloqueo y no se construye ni se cobra; sin Ciencia o sin prerrequisito falla sin gastar; con `time_scale` 0 el botón "Investigar" abre el panel acoplado y el botón de la tarjeta investiga gastando **solo** 6 de Ciencia (los otros 3 recursos no cambian); estado "Investigada", botón deshabilitado, el T2 muestra "Requiere"; Esc cierra y no pasa la sonda (no pausa); clic derecho cierra y se consume; luz 10 → 7 (cartel "(7 Polvo)", paga 7, reembolsa 7); generador de industria 3 → 4 → 5 y el turno paga eso; disparo real de torreta 15 → 25; descubrimiento +1. `_check_research_lifetime`: un Main2d + HUD nuevos (piso siguiente) conservan lo investigado y el panel muestra "Investigada"; `Main.new()._begin_new_run()` lo resetea y el panel abierto se refresca. |

### Decisiones

- **El estado vive dentro de `ResourceManager`, no en un `ResearchManager` aparte**: tiene exactamente el mismo ciclo de vida (autoload, sobrevive a los pisos, se resetea en `_begin_new_run`), la investigación solo existe para gastar un recurso que ya maneja, y así no hace falta un autoload nuevo (editar `project.godot` a mano) ni otro acceso en `ManagerLocator`. Son ~70 líneas en una sección propia; si crece (T3, repetibles, UI de árbol) se puede extraer.
- **Reset**: `reset_research()` va aparte, llamado en `_begin_new_run()` al lado de `reset_run_upgrades()` (el mismo punto que los niveles del héroe). No lo metí en `reset_resources()` para no cambiar lo que hace esa función pública (los tests la llaman sola).
- **Módulos bloqueados: Gen. Ciencia y Ballesta.** Los básicos quedan libres: Gen. Industria, Gen. Comida y Trampa. Bloquear el Gen. Ciencia hace que la primera investigación sea la que arranca la economía de Ciencia (6 de los 10 iniciales); la Ballesta es la única defensa que hace daño, así que desbloquearla compite de verdad con las mejoras.
- **"No se construye"** se garantiza en el camino del jugador (`BuildingMenu`: `_arm` + `get_block_reason`). `BuildingSlot.build()` sigue sin chequear: es API interna que usan los tests y el código, y dejarla así es lo más simple.
- **El % de generadores se aplica sobre la suma**, no por generador: `roundi(total × (1 + %))`. Con un solo generador de 3: +25% → 4, +50% → 5 (el .5 redondea para arriba). Con varios, el redondeo favorece un poco más. Aplica solo a los generadores, no a la producción base por puerta.
- **El costo de la luz tiene mínimo 1** y el reembolso devuelve lo que realmente se pagó (`_power_paid`), así que investigar con salas ya encendidas no crea ni quita Polvo.
- **Clic derecho con el panel abierto: cierra y se consume** (el héroe no se mueve). Es lo mismo que hace el clic derecho armado del `BuildingMenu`; cerrar y además mover sería sorpresivo. El clic izquierdo afuera no lo cierra (no lo pedía el objetivo, y el panel no bloquea nada del mundo).
- **Un panel a la vez**: "Investigar" cierra el `BuildingMenu` (y lo desarma), y Producción/Defensa cierran el panel. "Investigar" alterna abrir/cerrar.
- **El candado está dibujado** con `StatIcon` (tipo nuevo `"lock"`) en vez de un emoji: la fuente por defecto no garantiza el glifo.

#### Balance: Ciencia (cuentas)

Supuestos: el piso N tiene 8 + (N−1) salas → N+6 puertas = turnos (7, 8, 9, 10, 11 → **45 turnos** en 5 pisos). Base: 1 de Ciencia por turno; 10 al inicio; Gen. Ciencia = +3 por turno por 6 de Industria. Los módulos **no** pasan de piso (el mapa es nuevo), así que el generador se reconstruye en cada piso en la sala inicial (encendida gratis, 1 slot mayor).

- **Sin Gen. Ciencia**: 10 + 45 = **55** en toda la run → alcanza para los 5 T1 (42), pero no para ningún T2 (55 más). La Ciencia sigue siendo escasa si no se invierte.
- **Con un Gen. Ciencia desde el turno 0 de cada piso** (4 por turno): piso 1 = 10 − 6 + 7×4 = **32** → al terminar el piso 1 se compraron ~3 T1 (p. ej. Ballesta 8 + Engranajes 10 + Lentes 10 = 28). El piso 2 suma 32 → T1 completo y ahorrando para los T2. En el piso 3 (+36) caen los dos T2 (55), entre el piso 3 y el 4. Total de la run ≈ 10 + 45 + 45×3 − 6 ≈ **184** contra **97** del árbol → sobran ~85 desde el piso 4.
- Con Engranajes/Sobrecarga el generador pasa a 4 o 5 por turno → el árbol se completa medio piso antes.
- **Lectura**: el sumidero funciona los primeros 3 pisos; en los 2 últimos la Ciencia vuelve a sobrar. Siguiente paso barato: un T3 caro o una investigación repetible (p. ej. +HP de módulos), que es solo datos en el `.tres` si el efecto ya existe.

#### Balance: Polvo (riesgo de la sesión 7, NO corregido)

Supuestos: 20 al inicio; `discovery_dust` = 4 + ⌊0.5×(N−1)⌋ por sala descubierta (4, 4, 5, 5, 6); +10 al bajar (pisos 2+); luz 10; sala inicial gratis; N+6 salas para encender por piso.

| Piso | Ingreso de Polvo | Encender todo | Salas que se pueden encender |
|---|---|---|---|
| 1 | 20 + 7×4 = 48 | 7×10 = 70 | 4 de 7 |
| 2 | 10 + 8×4 = 42 | 80 | 4 de 8 (+ lo que sobró) |
| 3 | 10 + 9×5 = 55 | 90 | 5 de 9 |
| 4 | 10 + 10×5 = 60 | 100 | 6 de 10 |
| 5 | 10 + 11×6 = 76 | 110 | 7 de 11 |

- En bruto no "sobra" (≈ 281 de ingreso contra 450 para encender todo). **Pero** apagar reembolsa todo lo pagado: antes de salir del piso (en la extracción) se pueden apagar todas las salas y llevarse el Polvo. En la práctica el Polvo **nunca se consume** y se acumula: 48 → 90 → 145 → 205 → 281 disponibles al llegar a cada piso, suficiente para encender todo desde el piso 3 (90 ≥ 90).
- Con investigación: Lentes (−3) → piso 1 = 7×7 = 49 ≈ 48 de ingreso (casi todo encendido ya en el piso 1); Cartografía (+1) = +45 de Polvo en la run. Las dos T1 de Polvo agravan el excedente.
- Sugerencias (no implementadas): que el reembolso no aplique al cambiar de piso ni durante la extracción, o que sea parcial (50%).

#### Puertas en pausa táctica (pendiente de la s9) — NO implementado

Hoy (desde la s9) se puede abrir una puerta en pausa táctica: el turno avanza al instante (producción, descubrimiento, tirada de invasión con los enemigos congelados) y el héroe recién camina al reanudar.

- **A favor de permitir**: menos reglas; la pausa es "dar órdenes" y abrir es una orden; no rompe nada técnico (los tests de la s9 lo cubren); el turno es instantáneo de todos modos.
- **En contra (a favor de bloquear)**: estado incoherente (sala revelada y turno avanzado con el héroe todavía en la otra sala). Y es **explotable**: abrir en pausa, ver dónde cayó la invasión con los enemigos congelados, encender esa sala y construir defensas (todo permitido en pausa) antes de que actúen. En DotE la puerta se abre cuando el héroe llega, no al hacer clic.
- **Recomendación: bloquear** las puertas en pausa táctica con un texto flotante "En pausa": una guarda en `PlayerActionController._open_group()` que consulte `Main2d.is_tactically_paused()`, sin cola de órdenes. Encolar la apertura para cuando se reanude sería más fiel, pero agrega estado; se puede hacer después si el playtest lo pide.

## Verificación (sesión 10)

- Baseline (antes de tocar nada): `test_map_generator`, `test_map_flow`, `test_corridor_picking` y `test_hud_ui` OK; `SCRIPT ERROR` 0 / 11 / 35 / 10; `Main.tscn --quit-after 90` exit 0 con 0 `SCRIPT ERROR`.
- Final: los 4 tests OK (exit 0). `SCRIPT ERROR` 0 / 11 / 35 / **11**. El +1 de `test_hud_ui` es el ruido ya conocido `Trying to assign value of type 'CanvasLayer' to a variable of type 'PauseMenu.gd'` (Main2d.gd:33), que sale una vez por cada `Main2d` que se arranca en `--script`, y el test nuevo de persistencia arranca un segundo `Main2d`. No hay errores nuevos distintos.
- `Main.tscn --quit-after 90` y `Main2d.tscn --quit-after 90`: exit 0 y 0 `SCRIPT ERROR` (igual que el baseline).
- Mutaciones: sin `reset_research()` en `_begin_new_run`, `test_hud_ui` falla ("_begin_new_run (Retry) must reset research"); sin el chequeo de bloqueo en `get_block_reason`, falla ("locked reason", "a locked module must not be built nor paid", …).
- `gdparse` OK en todos los `.gd` tocados y nuevos. Corrí `--editor --quit` para indexar las clases nuevas (`ResearchEntry`, `ResearchConfig`, `ResearchPanel`).
- **No se vio nada en pantalla** (todo fue headless): el panel, el candado, el layout de la barra inferior y los clics reales no se probaron con mouse ni teclado.

## Checklist manual F5 (sesión 10)

1. Barra inferior: "Construir: Producción · Defensa · Investigar". El tooltip de Ciencia habla de investigaciones.
2. Producción: Gen. Ciencia con candado y "Requiere: Instrumental arcano"; no se puede elegir (ni con la tecla 3). Defensa: la Ballesta igual, con "Requiere: Planos de ballesta"; la Trampa está libre.
3. Investigar: panel acoplado sobre la barra, 7 tarjetas en 2 columnas, mismo estilo que el de construcción; se ve bien sin tapar el minimapa ni los retratos (probar también en 720p).
4. Investigar "Instrumental arcano" (Ciencia 10 → 4): la tarjeta pasa a "Investigada"/"Hecho", y en Producción el Gen. Ciencia ya se puede elegir.
5. "Sobrecarga" y "Virotes estriados" muestran "Requiere: …" hasta comprar su T1; sin Ciencia dicen "Falta Ciencia" y el botón queda apagado.
6. Engranajes con un generador construido: el "+N" del recurso sube (3 → 4). Lentes: el cartel de las salas oscuras dice "(7 Polvo)", encender cobra 7 y apagar devuelve 7. Cartografía: el contador de Polvo sube 1 más al descubrir una sala.
7. Virotes: los números de daño de la Ballesta pasan de 15 a 25.
8. Espacio (pausa táctica) → Investigar y comprar funciona; los tooltips se ven.
9. Con el panel abierto: Esc lo cierra y **no** abre el menú de pausa; un segundo Esc sí pausa. El clic derecho lo cierra y el héroe no se mueve.
10. Producción/Defensa cierran el panel; Investigar cierra el menú de construcción (y lo desarma).
11. Bajar de piso: lo investigado sigue (panel y candados). Morir → Reintentar, o salir y empezar partida nueva: todo vuelve a estar bloqueado.

## Riesgos a revisar antes de mergear (sesión 10)

- **Picking real con `time_scale` 0** (heredado de la s9, sigue sin probarse con clics reales): los tests llaman `_on_input_event` o emiten señales. Es lo primero en F5: con Espacio, clic en salas, en slots armados y clic central. El panel de investigación es `Control` puro (no depende del picking físico), pero conviene confirmarlo también.
- Layout: el panel de 2 columnas × 4 filas más la barra puede quedar alto en 720p; si tapa demasiado, `COLUMNS = 3` en `ResearchPanel.gd` o tarjetas más compactas.
- Balance: la Ciencia vuelve a sobrar desde el piso 4 y el Polvo nunca se consume por el reembolso (ver Decisiones, con números).
- Bloquear la Ballesta deja la Trampa como única defensa hasta gastar 8 de Ciencia: si el piso 1 se vuelve más duro, bajar Planos de ballesta a 4-6 en el `.tres`.
- `BuildingSlot.build()` no respeta el bloqueo (solo lo hace el camino del menú): cualquier código nuevo que construya tiene que consultar `is_unlocked`.
- El texto de `EnergyButton.tscn` ("10 Polvo") queda como valor del editor; en juego lo pisa `_refresh_label()`.

## Pendiente / próximos pasos (sesión 11+)

1. Playtest F5 con los checklists de las sesiones 8, 9 y 10 (sobre todo el picking con `time_scale` 0).
2. Decidir las puertas en pausa táctica (recomendación: bloquear, ver Decisiones).
3. Sumidero tardío de Ciencia (T3 o repetible) y reembolso de Polvo al cambiar de piso.
4. Pendientes de la sesión 7: loops/tipos de sala, multi-héroe.

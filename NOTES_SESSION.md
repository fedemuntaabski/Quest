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

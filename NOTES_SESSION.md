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

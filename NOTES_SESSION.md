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

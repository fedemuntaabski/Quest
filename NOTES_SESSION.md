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

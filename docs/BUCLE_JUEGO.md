# BUCLE_JUEGO.md — session/bucle-7

Auditoría del bucle (puertas, polvo, energía, spawns, extracción, pausa) y lo que cambió.
Rama `session/bucle-7`, sobre `session/impl-6`. Referencia de diseño: *Dungeon of the Endless*.

## 1. Qué hacía el bucle antes de esta sesión

### Apertura de puerta
`PlayerActionController._open_group` rechaza la apertura si hay extracción, si la puerta no es adyacente a un héroe seleccionado o si el grupo ya está revelado. Luego:

1. `DoorTurnSystem.open_room(group)` marca el grupo visitado y llama `advance_turn`.
2. `advance_turn` incrementa `current_turn`, emite `turn_advanced` y `ResourceManager.process_turn_production()`.
3. `EnemyManager._on_turn_advanced` (oyente síncrono) tira la invasión **antes** de revelar la sala.
4. `room_revealed` → `FloorManager.on_room_discovered` (polvo, pasivas, banner, recompensa del tipo de sala), `LootSpawner`, `Minimap`, `GameCamera`.
5. `enemy_wave_requested` se emite sin oyentes (resto histórico).

### Recompensa por puerta (valores fijos)
| Qué | Dónde | Valor |
|---|---|---|
| Base plana por puerta | `ResourceManager.process_turn_production` | industria 2, comida 2, ciencia 1, polvo 0 (global, igual en todos los pisos) |
| Polvo por descubrimiento | `FloorConfig.dust_per_discovery` | 4 + 0.5 por piso (los corredores-loop no pagan) |
| Generadores | `_calculate_module_bonus` | solo los que `is_working()` |
| Recompensa del tipo de sala | `RoomTypeRule.reward_*` | por tipo, no por piso |

No había recurso extra aleatorio por piso.

### Amenaza por puerta
`P = min(0.85, 0.05 + salas_oscuras*0.08 + turno*0.015 + bono_piso)`, cantidad `1 + turno/5 + extras_piso`. Constantes en `EnemyManager.gd` (`BASE_CHANCE`, `CHANCE_PER_DARK_ROOM`, `CHANCE_PER_TURN`, `MAX_CHANCE`, `TURNS_PER_WAVE_STEP`). Dependía del turno global y de cuántas salas oscuras hubiera, no de cuántas puertas se abrieron. Sin salas oscuras no hay tirada. `randf()` sin semilla.

### Energía
- `RoomZone.POWER_COST = 10` fijo (menos el bono de investigación). Clic central energiza/apaga; apagar reembolsa lo pagado. La sala inicial arranca encendida gratis.
- Los spawns ya eran solo en salas oscuras: `EnemyManager.get_spawn_rooms()` = `RoomManager.get_dark_rooms()` (reveladas y sin energía) menos las de `blocks_spawns` (Descanso).
- Módulos en salas apagadas: `Module.is_working()` = `is_active and powered`, así que generadores, torretas y trampas no funcionan; siguen siendo atacables (`is_targetable()` ignora la energía) y destruibles.
- Bug: `TurretModule._on_fire_timer_timeout` detenía su `Timer` si no estaba energizada y nada lo reiniciaba, así que una torreta apagada una vez quedaba muerta al volver a encender.
- Estado visible: color/luz (`RoomLight`: pulso rojo apagada, `PointLight2D` encendida, contorno dorado si alcanza el polvo), texto del `EnergyButton`, minimapa dorado/gris. No había ícono de encendida/apagada.

### Enemigos: cantidad, composición, tope
- Tipo: `EnemyManager._roll_type` → `FloorManager.roll_role()` (cuota de raiders por piso) → `EnemyPool.roll(rng, role)`; un raider que llegaría al Nexo en menos de `raider_min_arrival_sec` pasa a hunter. El comportamiento lo decide `TargetSelector` según el `TargetProfile` del `EnemyType`.
- Cantidad: fórmula de arriba. **No había tope de enemigos vivos.**

### Nexo y extracción
- El Nexo se recoge en la sala inicial con la sala de salida descubierta; `ExtractionManager.start_extraction()` pasa a `EXTRACTION`.
- Oleadas: un `Timer` fijo (5 s, menos 0.5 por piso, mínimo 2 s) que genera 1 enemigo en **cada** sala oscura revelada. No crece dentro de la extracción y no pasa por `invasion_triggered`, así que no había alerta.
- Portador: 0.75 de velocidad, fijo en `PlayerActionController`.
- Si moría cualquier héroe terminaba la run (`Main2d._on_player_died`). El Nexo no se podía soltar ni recoger de nuevo (`_picked_up` nunca volvía a false).
- Asesinos: `assassin.tres` ya tenía `HERO_CARRIER` como primera regla.

### Telegrafía
Solo el destello rojo `InvasionFlash` al invadir por puerta (sin saber dónde) y el aro/borde rojo del Nexo atacado. Sin sonido de juego (solo `click`/`hover` de menús).

### Pausa táctica
Espacio fija `Engine.time_scale = 0`. Consumibles (`InventoryComponent.get_block_reason`) y habilidades (`HeroAbilities._input_allowed`) ya se bloqueaban en pausa. Las órdenes de movimiento se aceptaban pero el `Tween` quedaba congelado; no había 1x/2x.

## 2. Desvíos respecto del original (DotE) y del diseño buscado

| Tema | Original / objetivo | Antes |
|---|---|---|
| Amenaza por puerta | Probabilidad que crece con las puertas abiertas en el piso | Salas oscuras + turno global |
| Recompensa | Siempre algo al abrir | Base plana global sin variación por piso |
| Costo de energía | Sube con cada sala ya energizada | Fijo (10) |
| Estado de sala | Se lee de un vistazo (encendida/apagada) | Solo color y texto |
| Tope de enemigos | Las oleadas no se acumulan sin límite | Sin tope |
| Extracción | Oleadas por fases que crecen hasta la salida | Timer plano |
| Nexo | Se puede perder y recuperar | Una muerte terminaba la run |
| Pausa | Pausa + velocidad | Solo pausa |

## 3. Qué cambió en esta sesión
Se completa a medida que se implementa (ver commits de `session/bucle-7`).

## 4. No verificado sin ejecutar el juego
Se completa al final.

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

| # | Cambio | Dónde |
|---|---|---|
| 1 | `DoorRollConfig`: cada apertura (salas y corredores-loop) tira amenaza `0,10 + 0,06 × puertas + 0,05 × (piso − 1)` (tope 0,85) y **siempre** paga Polvo (salas) + 1 recurso al azar ponderado por piso. Reemplaza la base plana de `ResourceManager` (ahora 0) y las constantes de `EnemyManager`. El recurso extra es determinista por puerta (`FloorManager.door_bonus`). | `scripts/core/floors/DoorRollConfig.gd`, `resources/floors/door_roll_config.tres`, `EnemyManager`, `FloorManager` |
| 2 | Energía: el costo de encender crece `power_cost_step` (2) por cada sala ya energizada con Polvo (la inicial gratis no cuenta; el reembolso es lo pagado, sin ganancia por ciclos). `PowerIcon` por sala (rayo dorado "Encendida" / gris tachado "Apagada") además de la luz. Arreglo: una torreta apagada y vuelta a encender ya funciona. | `RoomZone`, `RoomManager`, `RoomLight`, `EnergyButton`, `TurretModule` |
| 3 | Tope de enemigos vivos por piso (6/8/10/12/14), un solo punto de control en `EnemyManager._spawn_enemy` (cubre invasiones por puerta, `spawn_enemies_in_room` y oleadas). Tipo y comportamiento siguen saliendo de `EnemyPool` → `EnemyType` → `TargetProfile` → `TargetSelector` (sin cambios). | `FloorConfig`, `EnemyManager` |
| 4 | Extracción: `phase_changed` arranca las oleadas; la etapa sube cada 20 s hasta la 3 (oleada 1 → 4 enemigos, pausa −0,5 s por etapa, mínimo 2 s). Portador a 0,85 (`carrier_speed_mult`). Si el portador cae, el Nexo queda en su sala y otro héroe vivo lo recoge (clic, sin diálogo ni reiniciar la extracción); la run solo se pierde si caen todos los héroes o se destruye el Nexo. Asesinos: `HERO_CARRIER` ya era su primera regla (se verifica en `test_target_selector` y `test_extraction_phases`). | `ExtractionManager`, `Nexo`, `NexoController`, `Main2d`, `PlayerActionController` |
| 5 | Telegrafía: señal `enemies_appeared(zonas, cantidad, origen)` → texto "Invasión/Oleada: N enemigos en: Sala 3, …", marca flotante "¡Enemigos!" en cada sala, destello rojo en oleadas, anillo naranja parpadeante en el minimapa (6 s) y beep placeholder generado en código (`assets/audio/alert.*` si existe). | `EnemyManager`, `HUDController`, `Minimap` |
| 6 | Pausa táctica: Espacio pausa, **X** alterna 1x/2x (banner "PAUSA" / "2x"). En pausa las órdenes de caminar se aceptan (corren al reanudar) pero no se abren puertas; consumibles y habilidades siguen rechazados. La trampa-lenta y la ventana de represalia pasan a reloj de juego (`Enemy.game_msec`) para no correr en pausa ni desfasarse a 2x. | `PauseController`, `Main2d`, `PlayerActionController`, `Enemy`, `TargetSelector`, `project.godot` |

Tests: `test_door_roll` (probabilidad creciente, spawns solo en salas oscuras, tope, recompensa, costo, torreta, telegrafía), `test_extraction_phases`, `test_tactical_pause`. `test_party`/`test_hud_ui` se ajustaron a la regla de derrota; `test_map_flow`/`test_abilities` a la recompensa por puerta. `BalanceSim.door_rows()/extraction_rows()` y la sección "Bucle" de `docs/BALANCE.md` (las 5 tablas de combate no cambian).

Límites conocidos:
- Una orden de caminar en curso no se puede reemplazar mientras dura (ya era así sin pausa): en pausa solo se aceptan órdenes cuando no hay un lote en marcha.
- Los raiders de los spawns por puerta siguen yendo al Nexo en su base: "seguro salvo los spawns por puertas" se cumple porque no hay oleadas con timer antes de recoger el Nexo.
- El Nexo caído no se mueve ni se defiende solo; los raiders lo atacan en la sala donde cayó.

## 4. No verificado sin ejecutar el juego
Todo lo siguiente está cubierto por tests headless pero **no se vio en una ventana** (Godot corrió solo en modo headless en esta sesión):

1. Aspecto y legibilidad del `PowerIcon` (posición arriba a la derecha, tamaño, texto "Encendida/Apagada" sobre la luz y la niebla), y que no se superponga con el `TypeBadge` de salas chicas.
2. El anillo naranja del minimapa y su convivencia con el anillo rojo del Nexo; el texto de `show_hint` con varias salas; las marcas flotantes "¡Enemigos!".
3. El beep placeholder (tono, volumen en el bus `SFX`, que no moleste con oleadas seguidas).
4. Sensación de la curva de amenaza por puerta (2,4 amenazas en el piso 1; chance 0,85 en las últimas puertas del piso 4-5) y de las etapas de extracción con el tope de enemigos.
5. Flujo completo en ventana: tomar el Nexo, caer el portador (muerte real en combate), el Nexo visible en el suelo, recogerlo con el otro héroe a mano, victoria en la salida.
6. Pausa/2x con el ratón: órdenes de caminar en pausa, el aviso "En pausa: no se abren puertas", el banner "2x" y la tecla X (el test usa los métodos de `PauseController`, no pulsa teclas); 2x con animaciones, cámara y tweens de feedback a tiempo real.
7. Un frame de retraso al pausar (el `time_scale` llega al motor un frame tarde: un paso mínimo del héroe puede verse al pulsar Espacio).
8. Que el `Main.tscn` por F5 siga arrancando con el HUD completo (solo se arrancó `Main2d.tscn` y los tests con HUD).
9. Re-guardado del editor: Godot reescribe `resources/floors/default_floor_config.tres` (añade `max_enemies_by_floor = null`, que ignora al cargar, igual que el existente `raider_ratio_by_floor = null`); conviene abrir el editor y confirmar que no aparecen advertencias nuevas.

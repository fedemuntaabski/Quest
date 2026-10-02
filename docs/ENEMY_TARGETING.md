# Enemigos: cómo se eligen los objetivos

Estado **antes** de `session/enemies-2` (referencia; los roles nuevos están al final).

## Datos
- `EnemyType` (`scripts/core/enemies/EnemyType.gd`, 20 `.tres` en `resources/enemies/`): arte + multiplicadores sobre un `behavior` (`Enemy.Variant` SWARM/SAPPER/HUNTER). No existe una clase `EnemyData`.
- `EnemyPool` (`resources/floors/enemy_pool_f1..f5.tres`): tipos + pesos por piso; `FloorConfig.enemy_pool(floor)` (clamp al último).
- `Enemy.VARIANT_CONFIG` (`Enemy.gd`): stats base por behavior (hp, speed, ai_interval, contact_damage, damage_per_tick).
- Multiplicadores: piso (`FloorConfig.enemy_hp/damage_multiplier`) × sala (`RoomTypeRule.enemy_*_mult`, Elite) × tipo (`hp_mult`/`damage_mult`).

## Spawn
- Invasión por puerta: `EnemyManager._on_turn_advanced` (P = min(0.85, 0.05 + salas_oscuras·0.08 + turno·0.015 + bonus de piso)) → `invasion_triggered` → `_spawn_enemy` en salas oscuras reveladas (`get_spawn_rooms()`, sin `blocks_spawns`).
- Oleadas de extracción: `ExtractionManager._on_spawn_timeout` → `spawn_enemies_in_room(grupo, 1)` por sala oscura revelada.
- Ambos pasan por `EnemyManager._spawn_enemy`, que tira `FloorManager.roll_enemy_type()`.

## Objetivo por behavior (`Enemy._on_ai_tick`, cada `ai_interval` s)
| Behavior | Destino |
|---|---|
| SWARM | zona del héroe más cercano (menos zonas en `find_zone_path`) |
| SAPPER | primera sala revelada con módulos; si no hay, como SWARM |
| HUNTER | solo si un héroe lleva el Nexo → su zona; si no, quieto |

- Todos atacan al primer `Module` activo de cualquier sala en la que entran (`on_zone_entered` → `AttackTimer` → `Module.take_damage`).
- Daño a héroes: `HitboxComponent` de contacto (capa 3 `player_hurtbox`), 1 tick/s mientras se solapan.
- Nadie apunta al Nexo (no tiene PV).

## Movimiento
- `RoomManager.find_zone_path` = BFS sobre zonas **reveladas**; `EnemyMoveAction` encadena tweens entre centros de zona (sin colisión: `collision_mask = 0`). Las puertas no bloquean; un enemigo no puede atascarse físicamente.
- Atascos lógicos: ruta vacía, objetivo en la misma zona, todos apilados en el mismo píxel (spawn y destino son el centro de la zona).
- No se re-planifica a mitad de ruta: el destino solo cambia en el siguiente tick tras terminar el trayecto.

## Compatibilidad
- Torres: `DetectionZone` (máscara 2 = `enemy_body`); los enemigos están en esa capa y en el grupo `enemies`.
- Trampas: `apply_slow` al llegar a una sala con trampa. Rest: `blocks_spawns`. Elite: multiplicadores.

## Roles (session enemies-2)
Ver `docs/archive/NOTES_SESSION.md` "Sesión enemies-2".

### Resumen
- `EnemyType.role` HUNTER/RAIDER, `aggro_range` 320 px, `attack_range` 40 (cazador) / 56 (saqueador), `damage_vs_heroes` (0 = daño de contacto del variant), `damage_vs_nexo`.
- Cazador: héroe vivo más cercano dentro de `aggro_range` (alcanzable por el grafo revelado) -> va a su posición; si no, a la zona del héroe más cercano por ruta. Ataca héroes por contacto y módulos como antes.
- Saqueador: ignora héroes y módulos; ruta más corta (`find_zone_path`) a `Nexo.get_target_zone()`; en `attack_range` golpea al Nexo cada `attack_speed` s. Si un héroe está a <= 48 px o lo golpeó hace < 3 s, actúa como cazador hasta que pase.
- Re-planifica tras cada tramo si el objetivo cambió de zona; se reparten en un anillo de 8 slots (sin física).
- Proporción por piso: `FloorConfig.raider_ratio_by_floor`; un saqueador no spawnea si llegaría al Nexo en menos de `raider_min_arrival_sec` (pasa a cazador).

## Perfiles de objetivo (session impl-6, fases 3A/3B)
El destino ya no está escrito dentro de `Enemy`: lo decide un **`TargetProfile`** (datos) que evalúa un **`TargetSelector`** (nodo hijo de `Enemy`). `Enemy` solo mueve y ataca.

### Datos
- `TargetRule` (`scripts/core/enemies/TargetRule.gd`): `type` (`HERO_NEAREST`, `HERO_WEAKEST`, `HERO_CARRIER`, `NEXO`, `MODULE_GENERATOR`, `MODULE_TURRET`, `MODULE_TRAP`, `MODULE_ANY`), `aggro_range` (px; `< 0` = el `aggro_range` del `EnemyType`; `0` = cualquier punto alcanzable por el grafo revelado), `condition` (`ALWAYS`, `NEXO_CARRIED`, `NEXO_IDLE`), `attack_range` (reservado, hoy el del `EnemyType`).
- `TargetProfile` (`resources/enemies/profiles/*.tres`): `rules` en **orden de prioridad**, `fallback` (`NEAREST_HERO_ZONE`, `NEXO`, `HOLD`), `retaliate`/`retaliate_sec`, `reeval_sec` (0 = el `ai_interval` del behavior en `VARIANT_CONFIG`), `drop_range_mult` (1.25), `hits_modules_en_route`, `display_name`/`description` (los usará el bestiario).
- `EnemyType.target_profile`; si es `null`, `EnemyType.get_target_profile()` lo **deriva** de `role`/`behavior` (`TargetProfile.derive`: RAIDER → asedio, Sapper → saboteador, resto → cazador). `EnemyType.role` sigue siendo el dato que leen `EnemyPool`, `FloorManager.roll_role`, `EnemyManager` y `BalanceSim`; `tests/test_target_selector.gd` comprueba `role == RAIDER ⇔ la primera regla es NEXO`.

### Perfiles y asignación
| Perfil | Reglas (prioridad) | Fallback | Enemigos |
|---|---|---|---|
| `siege` Asedio | `NEXO` (si lo golpean o un héroe está a ≤ 48 px: reglas de cazador durante `retaliate_sec`) | `NEXO` | goblin, masked_orc, orc_warrior |
| `hunter` Cazador | héroe más cercano en `aggro_range` → héroe más cercano por ruta | zona del héroe más cercano | skelet, orc_shaman, wogol, necromancer, tc_eyeball, tc_dragon |
| `saboteur` Saboteador | `MODULE_GENERATOR` → `MODULE_ANY` → reglas de cazador | `HOLD` | tiny_zombie, big_zombie, ogre, tc_ogre |
| `tower_breaker` Rompe-torres | `MODULE_TURRET` → `MODULE_TRAP` → reglas de cazador | zona del héroe más cercano | tc_fire_skull, big_demon |
| `assassin` Asesino | `HERO_CARRIER` (en todo el grafo) → `HERO_WEAKEST` (480 px) → reglas de cazador; **ignora módulos** | zona del héroe más cercano | imp, tc_red_imp, tc_wolf, chort, tc_demon |

Cambios de comportamiento respecto a antes de impl-6 (la fase 3A no cambió nada: `test_enemy_roles`/`test_raider_timing` sin editar y BalanceSim idéntico):
- Saboteador: prioriza **generadores** y elige el módulo **más cercano** (menos zonas, luego distancia) en una sala revelada alcanzable (antes: la primera sala en orden de `zone_ids`, sin comprobar alcance). Los módulos apagados siguen siendo objetivo.
- Rompe-torres y asesinos son nuevos. Los asesinos dejaron de atacar el módulo de cada sala por la que pasan (`hits_modules_en_route = false`); el resto de perfiles conserva ese hábito, pero ahora elige el módulo que su perfil prefiere (`TargetSelector.pick_module_in_room`).
- `HOLD` del saboteador solo se usa si **ningún** héroe es alcanzable (su última regla es la caza de héroes), para no cambiar la presión que ejercen los zombis en pisos sin módulos.

### Re-evaluación y estabilidad
- `TargetSelector.select()` es una consulta pura; `reevaluate()` guarda el resultado en `current` y emite `target_changed`.
- Disparadores: tick del `AiTimer`, `target_lost` (el módulo emite `module_destroyed`, el héroe `stats.died`, el Nexo `destroyed`: re-selecciona **en el mismo frame**; si el enemigo golpeaba ese módulo, `Enemy._on_target_lost` deja de golpear y re-planifica), `ExtractionManager.phase_changed` (aparece un portador) y `RoomManager.module_built` (nueva señal).
- Anti-parpadeo: dentro de la **misma regla**, un héroe ya perseguido se mantiene mientras sea válido y esté a ≤ `alcance × drop_range_mult`; una regla de mejor prioridad siempre gana.
- `Enemy._goal_zone/_goal_point/_aggro_hero/_player_zone/_is_raiding/_note_blocking_hero` siguen existiendo como wrappers (los usan los tests).

### Daño a módulos
`Module` emite `hp_changed(current, max)` y `damaged(amount)`, parpadea en blanco (tween del color del icono, no el shader del Nexo: un `Polygon2D` sin textura no se aclara con `white_flash`), muestra un número flotante y una mini-barra bajo el módulo (solo visible si está dañado). `is_targetable()` = construido y vivo, **aunque la sala esté apagada**; `get_target_position()`.

### Balance (rompe-torres y asesinos)
Ver `docs/BALANCE.md`, "Perfiles de objetivo". Los asesinos no cambian vida, daño ni velocidad: concentran la oleada en el héroe más débil, que el simulador ya modela (un héroe recibe toda la oleada). Los rompe-torres se ajustaron con `module_damage` (`tc_fire_skull` 5, `big_demon` 3).

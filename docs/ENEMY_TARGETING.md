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
- `EnemyType.role` HUNTER/RAIDER, `aggro_range` 320 px, `attack_range` 40 (cazador) / 56 (saqueador), `damage_vs_heroes` (0 = daño de contacto del variant), `damage_vs_nexus`.
- Cazador: héroe vivo más cercano dentro de `aggro_range` (alcanzable por el grafo revelado) -> va a su posición; si no, a la zona del héroe más cercano por ruta. Ataca héroes por contacto y módulos como antes.
- Saqueador: ignora héroes y módulos; ruta más corta (`find_zone_path`) a `Nexo.get_target_zone()`; en `attack_range` golpea al Nexo cada `attack_speed` s. Si un héroe está a <= 48 px o lo golpeó hace < 3 s, actúa como cazador hasta que pase.
- Re-planifica tras cada tramo si el objetivo cambió de zona; se reparten en un anillo de 8 slots (sin física).
- Proporción por piso: `FloorConfig.raider_ratio_by_floor`; un saqueador no spawnea si llegaría al Nexo en menos de `raider_min_arrival_sec` (pasa a cazador).

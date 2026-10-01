# Tipos de sala

`RoomData.RoomType` = `COMBAT, START, EXIT, REST, LOOT, ELITE, GENERATOR`. START/EXIT se derivan de `is_start`/`is_exit` (`RoomData.get_room_type()`); el resto lo asigna `MapGenerator.assign_room_types` según las `RoomTypeRule` de `FloorConfig.room_types`. Un tipo sin regla nunca se genera.

## Qué define cada cosa
| Qué | Dónde |
|---|---|
| Cuándo aparece y qué hace (recompensa/cura/spawns/enemigos) | `RoomTypeRule` en `resources/floors/default_floor_config.tres` |
| Cómo se ve (nombre, ícono, color, cartel, frase de efecto `description`, pista larga `hint`, props) | `RoomTypeVisual` en `resources/maps/room_type_visual_config.tres` (`RoomTypeVisualConfig`, colgado de `MapVisualConfig.room_type_visuals`) |
| Rombo/ícono + nombre en la sala | `RoomZone.set_room_type()` (aparece con la niebla, no depende de la luz) |
| Marcador en el minimapa (cuadrado de color + ícono) | `Minimap._draw()` |
| Cartel al descubrir la sala (nombre + frase, una vez) | `FloorManager._show_room_banner()` (`banner_text` + `description`) |
| Pista larga, la primera vez que aparece cada tipo en la run | `HUDController.show_hint()` (`hint`); `FloorManager._seen_types`, reset en `Main._begin_new_run` |
| Tooltip al pasar el mouse por la sala en el minimapa (solo reveladas) | `Minimap._get_tooltip()` (`display_name: description`) |
| Props propios en el anillo del suelo | `MapTileRenderer._plan_props()` (`decor_props`/`decor_count`, RNG propio `"type_decor"`) |

Reglas que **no** cambian: Polvo por sala descubierta (`FloorManager.on_room_discovered`), luz por sala (`RoomLight`), la salida solo se ve al descubrir su sala (`ExitIndicator`, `ON_DISCOVERY`); su cartel también sale solo al descubrirla. START/EXIT tienen `show_marker = false`: no llevan badge ni marcador de minimapa (conservan su propia pista).

## Auditoría (session/rooms-1)
Medido con `tests/test_rooms.gd` (30 seeds x pisos 1-5 = 150 layouts; todos válidos, todas las salas alcanzables desde el inicio, ningún loop toca la salida) + `tests/test_map_flow.gd` (recompensas, spawns, multiplicadores, cartel).

| Tipo | Se define | Cuándo se genera | Qué hace al descubrirla | Cómo se ve | Estado | Evidencia |
|---|---|---|---|---|---|---|
| COMBAT | `RoomData.room_type` default | resto de salas | nada | nada (a propósito) | funciona | `MapGenerator.assign_room_types` |
| START | `RoomData.is_start` | `room_0` | spawn de héroes + Nexo, luz gratis | sin marcador | funciona | `Main2d._register_groups_and_doors`, `_spawn_heroes` |
| EXIT | `RoomData.is_exit` | sala más lejana del inicio, nunca con loops | victoria si llevas el Nexo | cartel al descubrir; `ExitIndicator` | funciona | `MapGenerator._mark_exit_and_vault`, `ExtractionManager.declare_victory` |
| REST | `RoomTypeRule` (`default_floor_config.tres`) | chance 0.6, cupo 1 | cura a todo el grupo vivo + sin spawns | badge, minimapa, cartel, props | funciona (arreglado: curaba solo al primario) | `FloorManager._apply_room_type_discovery`, `EnemyManager.get_spawn_rooms/_spawns_blocked` |
| LOOT | idem | chance 0.8, cupo 1 (+0.5/piso) | +Industria, cofre `Pickup` decorativo | badge, minimapa, cartel, props | funciona | `FloorManager._apply_room_type_discovery`, `Main2d._on_room_revealed` |
| ELITE | idem | chance 0.3 (+0.1/piso), cupo 1 (+0.25/piso) | enemigos x1.5 HP / x1.25 daño + Ciencia | badge, minimapa, cartel, props | funciona | `EnemyManager._spawn_enemy` |
| GENERATOR | `RoomTypeRule.extra_major_slots` | chance 0.5, cupo 1 | encendida ofrece 2 slots MAJOR + 2 MINOR | badge azul, minimapa, cartel, props | funciona (era solo diseño) | `RoomZone._spawn_building_slots`, `Main2d._register_groups_and_doors` |

**Eliminado: SHOP (Tienda).** Era solo display y sin efecto. Desde fix-3 no hay moneda (Oro eliminado); venderla por Industria/Ciencia sería una mecánica nueva fuera del diseño. Quitada del enum, del visual config y del test. `RoomType` se renumeró (GENERATOR = 6): ningún `.tres` guardaba SHOP/GENERATOR salvo `room_type_visual_config.tres` y `default_floor_config.tres`, ya actualizados.

Reglas verificadas (`test_map_flow.gd`/`test_rooms.gd`): Polvo solo al descubrir (y 0 en loops), solo el inicio revelado al empezar, la salida solo se marca al descubrir su sala, el minimapa lee zonas/layout (no tiles), tooltip vacío en salas sin revelar, puertas centradas en el carril (`test_door_alignment.gd`), todas las salas alcanzables y ningún loop toca la salida (150 layouts).

`is_vault` sigue siendo un flag de datos sin tipo (candidato natural a Botín, ver `NOTES_SESSION.md` sesión 5/11). Un "santuario/enfermería" ya está cubierto por REST.

## Añadir un tipo nuevo
1. Agregar (o ya tener) su `RoomType` al final del enum (no reordenar: `.tres` guardan el entero).
2. Una entrada en `room_type_visual_config.tres` (nombre, color, ícono, cartel, `description`, `hint`, props Kenney).
3. Una `RoomTypeRule` en `default_floor_config.tres` (chance/cupo) → el generador ya lo asigna.
4. Si su efecto no cabe en los campos de `RoomTypeRule`, leerlo en el sistema dueño (`FloorManager`, `EnemyManager`, `ResourceManager`), nunca con un `match` sobre el tipo en el render.

Los props usan coordenadas de `assets/art/_source/kenney_tinyDungeon/Tilemap/tilemap_packed.png` (12×11, 16 px); `tools/build_tilesets.gd` hornea todos los tiles en `props_tileset.tres`. Test: `tests/test_room_type_visuals.gd`.

## VFX (balance-4)
Descubrir una sala Rest muestra `heal_glow` sobre cada héroe curado. No hay otros efectos por tipo de sala.

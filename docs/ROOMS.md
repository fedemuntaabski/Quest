# Tipos de sala

`RoomData.RoomType` = `COMBAT, START, EXIT, REST, LOOT, ELITE, SHOP, GENERATOR`. START/EXIT se derivan de `is_start`/`is_exit` (`RoomData.get_room_type()`); el resto lo asigna `MapGenerator.assign_room_types` según las `RoomTypeRule` de `FloorConfig.room_types`. Un tipo sin regla nunca se genera.

## Qué define cada cosa
| Qué | Dónde |
|---|---|
| Cuándo aparece y qué hace (recompensa/cura/spawns/enemigos) | `RoomTypeRule` en `resources/floors/default_floor_config.tres` |
| Cómo se ve (nombre, ícono, color, cartel, props) | `RoomTypeVisual` en `resources/maps/room_type_visual_config.tres` (`RoomTypeVisualConfig`, colgado de `MapVisualConfig.room_type_visuals`) |
| Rombo/ícono + nombre en la sala | `RoomZone.set_room_type()` (aparece con la niebla, no depende de la luz) |
| Marcador en el minimapa (cuadrado de color + ícono) | `Minimap._draw()` |
| Cartel al descubrir la sala (texto flotante, una vez) | `FloorManager._show_room_banner()` (`banner_text`) |
| Props propios en el anillo del suelo | `MapTileRenderer._plan_props()` (`decor_props`/`decor_count`, RNG propio `"type_decor"`) |

Reglas que **no** cambian: Polvo por sala descubierta (`FloorManager.on_room_discovered`), luz por sala (`RoomLight`), la salida solo se ve al descubrir su sala (`ExitIndicator`, `ON_DISCOVERY`); su cartel también sale solo al descubrirla. START/EXIT tienen `show_marker = false`: no llevan badge ni marcador de minimapa (conservan su propia pista).

## Estado por tipo
| Tipo | Estado | Efecto | Display |
|---|---|---|---|
| COMBAT | implementado (default) | ninguno | ninguno (a propósito) |
| START | implementado | spawn + Nexo, luz gratis | sin marcador ni cartel |
| EXIT | implementado | victoria | cartel "Salida encontrada" al descubrir; marcador = `ExitIndicator` |
| REST (Descanso) | implementado | cura al descubrir, sin invasiones | flasco rojo, verde agua, cartel, frascos |
| LOOT (Botín) | implementado | recompensa (Industria) + cofre `Pickup` | cofre, naranja, cartel, cofres |
| ELITE (Élite) | implementado | enemigos más fuertes + recompensa (Ciencia) | hacha doble, violeta, cartel, armas |
| SHOP (Tienda) | **solo display, sin efecto** | ninguno; sin `RoomTypeRule`, nunca se genera | frasco amarillo, dorado, cartel, mesa/frascos |
| GENERATOR (Generador doble) | **solo display, sin efecto** | ninguno; diseño de la sesión 5: slot MAJOR ×2 | botón azul, celeste, cartel, maquinaria |

`is_vault` sigue siendo un flag de datos sin tipo (candidato natural a Botín, ver `NOTES_SESSION.md` sesión 5/11). Un "santuario/enfermería" ya está cubierto por REST.

## Activar un tipo nuevo o de solo display
1. Agregar (o ya tener) su `RoomType` al final del enum (no reordenar: `.tres` guardan el entero).
2. Una entrada en `room_type_visual_config.tres` (nombre, color, ícono, cartel, props Kenney).
3. Una `RoomTypeRule` en `default_floor_config.tres` (chance/cupo) → el generador ya lo asigna.
4. Si su efecto no cabe en los campos de `RoomTypeRule`, leerlo en el sistema dueño (`FloorManager`, `EnemyManager`, `ResourceManager`), nunca con un `match` sobre el tipo en el render.

Los props usan coordenadas de `assets/art/_source/kenney_tinyDungeon/Tilemap/tilemap_packed.png` (12×11, 16 px); `tools/build_tilesets.gd` hornea todos los tiles en `props_tileset.tres`. Test: `tests/test_room_type_visuals.gd`.

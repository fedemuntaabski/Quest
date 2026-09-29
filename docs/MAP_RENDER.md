# Cómo se dibuja el mapa

Estado **antes** de `session/assets-2` (referencia; la sección final resume qué cambia).

## Datos
`MapGenerator.generate_floor()` → `MapLayout` (`RoomData` en celdas, `CorridorData` 1 celda de ancho, `door_cell` en el muro de `room_a`, fuera de `get_rect()`) → `Main2d._setup_room_manager()` → `RoomManager.build_from_map()` crea zonas (`zones`, `groups`) y un `RoomZone` (`Area2D`) por sala/pasillo. El pasillo usa `CorridorData.get_zone_rect()` (rect + door cell). Rejilla lógica: celda = 64 px (`Floor.tile_set.tile_size`, `RoomManager._tile_size()`).

## Capas visuales (de abajo a arriba)
| Capa | Nodo / script | Qué dibuja |
|---|---|---|
| Suelo | `Main2d/Floor` (`FloorGenerator`, `TileMapLayer`, z -10, `placeholder_tileset` 64 px) | Una celda de 64 px por celda lógica, pintada **al revelar** (`fill_cells`). No hay muros ni bordes. |
| Highlight | `RoomZone/Fill` (`Polygon2D`) + `Outline` (`Line2D`), z -5 | Color translúcido según `Highlight` (CURRENT/REACHABLE/OPENABLE/BLOCKED) + contorno; encendida = dorado. |
| Luz por sala | `RoomLight` (hijo de `RoomZone`) | Sala oscura: overlay que pulsa negro↔rojo; sala encendida: overlay se desvanece y `PointLight2D` cálido entra. Contorno dorado si alcanza el polvo. |
| Oscuridad global | `RoomManager/DarkCanvas` (`CanvasModulate`, `MapVisualConfig` "Dark canvas") | Atenúa todo el canvas del mundo; el HUD (CanvasLayer) no. |
| Puertas | `Door.tscn` (`Area2D`): `Polygon2D` marrón 48×48 + `CollisionShape2D` | Se oculta al abrirse (`refresh_door_visibility`). El `Area2D` es el clic. |
| Tipo de sala | `RoomZone.set_room_type` → `TypeBadge` (rombo + nombre, unshaded) | Solo Descanso/Botín/Élite. |
| Salida | `ExitIndicator` (marcador z 50 + flecha en CanvasLayer 5) | Marcador sobre la sala `is_exit`; visible según `MapVisualConfig.exit_hint_mode`. No es un tile. |
| Minimapa | `Minimap` (`Control._draw`) | Lee `RoomManager.zones`/reveal/power/`ExitIndicator`; **no** lee tiles. |

## Descubrimiento (ocultamiento)
`DoorTurnSystem.room_revealed` → `Main2d._on_room_revealed` → `RoomManager.on_group_revealed(group)`:
1. `_apply_group_door_cell` pinta el suelo de la celda de puerta.
2. `apply_zone_visibility(zone)` → `RoomZone.set_shown(true)` (activa Fill/Outline/colisión de clic) y `_paint_cells` en `Floor`.
3. `refresh_door_visibility()` muestra/oculta cada `Door` (visible si su zona origen es visible y no está abierta).

Las zonas sin descubrir no tienen tile, ni fill, ni luz visible: fondo = clear color. `validate_visibility()` (debug) comprueba que `RoomZone` y `Floor` coinciden con `is_zone_visible`.

## Colisiones
No hay colisiones de muro: el movimiento es tween por centros de zona (`MoveAction`), los héroes son `Node2D` y los enemigos `CharacterBody2D` con capas de colisión 0. Capas de física del proyecto: 2 `enemy_body`, 3 `player_hurtbox`, 4 `enemy_hurtbox`.

## Cambio en session/assets-2
`MapTileRenderer` (4 `TileMapLayer`: Floor/Walls/Decor/Doors, tiles 16 px ×2, celda = 2×2 tiles) dibuja el arte y se engancha en los puntos 1-3 de arriba. `Floor` sigue como rejilla lógica **oculta**. El resto (Fill, luces, canvas oscuro, indicador de salida, minimapa) no cambia. Ver `docs/ASSETS.md` para la escala.

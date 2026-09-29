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

## Después (session/assets-2)
`MapTileRenderer` (`scenes/world/MapTileRenderer.tscn`, `scripts/world/map/MapTileRenderer.gd`): 4 `TileMapLayer` (Floor z -9 / Walls -8 / Decor -7 / Doors -6, bajo el `Fill` de `RoomZone` z -5), tiles de 16 px con `scale = ArtConfig.ART_SCALE`; 1 celda lógica = 2×2 tiles. Instanciado por `Main2d._setup_room_manager()` y asignado a `RoomManager.tile_renderer`.
- **Plan puro** `MapTileRenderer.build_plan(layout, config)`: por zona `{floor, walls, decor}` (tile → `Vector4i(source, ax, ay, alt)`) + `doors`. Semillas `hash([map_seed, "floor"|"banners"|"decor"])`. Coordenadas de atlas en `DungeonTiles.gd`; los `.tres` (`assets/tilesets/`) se hornean con `tools/build_tilesets.gd`.
- **Muros**: anillo de 1 celda (8-vecinos) alrededor de todo el suelo, 2 tiles de grosor. Fila que toca suelo debajo = cara de ladrillo (`wall_left/mid/right`, algunas con banner 0x72), fila sobre ella = tapa (`wall_top_*`), fila que toca suelo arriba = tapa invertida (`ALT_FLIP_V`), resto = relleno sólido. Reglas de vecinos en GDScript en vez de Terrain: la plantilla 3×3 de `atlas_walls_low` no encaja con un muro de 2 tiles + cara. Cada celda de muro pertenece a la primera zona vecina → solo se pinta al revelarla.
- **Capa física**: los tiles de muro llevan polígono 16×16 en la capa 5 `wall` (máscara 0); nadie la enmascara aún, igual que hoy (sin colisiones de muro).
- **Ocultamiento**: `RoomManager.apply_zone_visibility` → `tile_renderer.show_zone()`; `refresh_door_visibility` → `show_door()`. Escalera (`floor_stairs` 2×2) va en el suelo de la sala de salida → aparece solo al descubrirla. `Floor` (64 px) queda oculto como rejilla lógica; `validate_visibility()` sigue válido.
- **Decor**: banners 0x72 en caras de muro (`wall_decor_density`), props Kenney (armarios, lápidas, yunque…) en el anillo exterior del suelo de las salas (`prop_density`), un cofre Kenney en salas LOOT. El pack no trae antorchas: sin antorchas por ahora.
- **Puertas**: `doors_leaf_closed/open` 32×32 (= 1 celda); `ALT_TRANSPOSE` en pasillos E-O. El `Polygon2D` marrón de `Door` se oculta; el `Area2D` de clic sigue igual.
- Sin cambios: descubrimiento, polvo, `RoomLight`, `DarkCanvas`, `ExitIndicator`, `Minimap` (lee `RoomManager.zones`), `fallback_layout.tres`.
- Revisión visual: `godot --path . --script res://tests/tools/shot_map.gd -- out.png [full|close]` (ventana real, no headless).

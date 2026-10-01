extends Resource
class_name RoomTypeVisual

## RoomTypeVisual: how one RoomData.RoomType looks (badge, minimap marker,
## discovery banner, tile props). Pure data, no gameplay: what a type *does* is
## its RoomTypeRule (FloorConfig.room_types). One per type in RoomTypeVisualConfig.

@export var type: RoomData.RoomType = RoomData.RoomType.COMBAT
## Short name on the room badge and the floating reward text.
@export var display_name: String = ""
## Floating text shown once when the room is discovered ("" = none).
@export var banner_text: String = ""
## One short sentence of what the room does: second line of the discovery
## banner and the minimap tooltip ("" = none).
@export var description: String = ""
## Longer tip shown once per run, the first time this type is discovered.
@export_multiline var hint: String = ""
@export var icon: Texture2D
@export var color: Color = Color.WHITE
## Badge in the room + marker on the minimap. Off for Start/Exit: they keep the
## exit hint / start light instead (the exit must only show once discovered).
@export var show_marker: bool = true

@export_group("Decor")
## Kenney tilemap_packed atlas coords (props_tileset.tres) for extra props on
## this room's outer floor ring, drawn only once the room is discovered.
@export var decor_props: Array[Vector2i] = []
@export var decor_count: int = 0

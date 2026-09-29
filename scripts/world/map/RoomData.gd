extends Resource
class_name RoomData

## RoomData: one room of a MapLayout (cell space, tile = 64px). Its id is also
## its DoorTurnSystem reveal group id. Corridors are separate CorridorData.

## START/EXIT are never stored: get_room_type() derives them from is_start/
## is_exit. The rest come from MapGenerator.assign_room_types (FloorConfig
## RoomTypeRules); COMBAT is the plain default. SHOP and GENERATOR are design-only
## (display ready in RoomTypeVisualConfig, no RoomTypeRule: never generated, no
## effect; see docs/ROOMS.md). Names, icons, colors and banners live in
## resources/maps/room_type_visual_config.tres, not here.
enum RoomType { COMBAT, START, EXIT, REST, LOOT, ELITE, SHOP, GENERATOR }

@export var id: String = ""
@export var room_type: RoomType = RoomType.COMBAT
@export var pos: Vector2i = Vector2i.ZERO
@export var size: Vector2i = Vector2i(5, 5)
## Room ids joined to this one by a corridor (both directions, loops included).
@export var neighbors: PackedStringArray = PackedStringArray()
@export var is_start: bool = false
@export var is_exit: bool = false
@export var is_vault: bool = false


func get_rect() -> Rect2i:
	return Rect2i(pos, size)


func get_room_type() -> RoomType:
	if is_start:
		return RoomType.START
	if is_exit:
		return RoomType.EXIT
	return room_type

extends Resource
class_name RoomData

## RoomData: one room of a MapLayout (cell space, tile = 64px). Its id is also
## its DoorTurnSystem reveal group id. Corridors are separate CorridorData.

@export var id: String = ""
## Room type tag ("room" today; future: "shop", "treasure"...).
@export var kind: String = "room"
@export var pos: Vector2i = Vector2i.ZERO
@export var size: Vector2i = Vector2i(5, 5)
## Room ids joined to this one by a corridor (both directions).
@export var neighbors: PackedStringArray = PackedStringArray()
@export var is_start: bool = false
@export var is_exit: bool = false
@export var is_vault: bool = false


func get_rect() -> Rect2i:
	return Rect2i(pos, size)

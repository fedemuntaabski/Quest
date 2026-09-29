extends Resource
class_name CorridorData

## CorridorData: a corridor entity — a straight 1-cell-wide segment joining
## `room_a` (the side you open it from) to `room_b`. `door_cell` is the Door
## at room_a's wall; the room_b end opens straight into room_b. Revealed
## together with room_b (same DoorTurnSystem group = room_b's id) — unless
## `is_loop`: then it is its own corridor-only group (group id = its id).

@export var id: String = ""
@export var room_a: String = ""
@export var room_b: String = ""
@export var pos: Vector2i = Vector2i.ZERO
@export var size: Vector2i = Vector2i(1, 1)
@export var door_cell: Vector2i = Vector2i.ZERO
## Extra corridor between two rooms already joined by the tree (a cycle).
## Never an entry corridor: opening it reveals only itself, no room.
@export var is_loop: bool = false


func get_rect() -> Rect2i:
	return Rect2i(pos, size)


## True when the corridor runs east-west (its door cell sits left/right of room_a).
func is_east_west(origin_room: RoomData) -> bool:
	var rect := origin_room.get_rect()
	return door_cell.x < rect.position.x or door_cell.x >= rect.end.x


## What the player sees and clicks as "the corridor": get_rect() plus the door
## cell (always adjacent, same lane). Once the door opens it is disabled and
## this zone must own the cell, or that tile of the corridor is dead to clicks.
func get_zone_rect() -> Rect2i:
	return get_rect().merge(Rect2i(door_cell, Vector2i.ONE))

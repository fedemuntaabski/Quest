extends Area2D
class_name Door

## Door: clickable gameplay node. Emits `door_clicked` on left-click; access
## validation (is the hero in the right room?) lives in
## PlayerActionController, not here — with room-granular movement the hero
## stands at a room *center*, so Door can no longer validate adjacency by
## comparing grid cells against itself.

signal door_clicked(door: Door)

@export var door_id: String = ""
@export var target_room_id: String = ""
@export var from_zone_id: String = ""
@export var cell: Vector2i = Vector2i.ZERO

## Graph edge: joins exactly two room nodes. Never authored — always derived
## by RoomManager.register_door() from from_zone_id / target_room_id.
var room_a_id: String = ""
var room_b_id: String = ""

var is_open: bool = false


func _ready() -> void:
	z_index = 1
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_open:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	door_clicked.emit(self)
	get_viewport().set_input_as_handled()


func is_opened() -> bool:
	return is_open


## Permanently disables the door: no more clicks, faded visual.
func disable_door() -> void:
	is_open = true
	modulate.a = 0.3
	input_pickable = false
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)


func mark_opened() -> void:
	disable_door()


## Returns the room on the other side of this door as seen from `zone_id`,
## or "" when `zone_id` is not one of the door's two rooms (not adjacent).
func get_target_room_for(zone_id: String) -> String:
	if zone_id == "":
		return ""
	if zone_id == room_a_id:
		return room_b_id
	if zone_id == room_b_id:
		return room_a_id
	return ""

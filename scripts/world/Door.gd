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

var _is_opened: bool = false


func _ready() -> void:
	z_index = 1
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_opened:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	door_clicked.emit(self)
	get_viewport().set_input_as_handled()


func is_opened() -> bool:
	return _is_opened


func mark_opened() -> void:
	_is_opened = true
	modulate = Color(0.5, 0.5, 0.5, 1.0)
	input_pickable = false

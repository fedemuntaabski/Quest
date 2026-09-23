extends Area2D
class_name Nexo

## Nexo: clickable pickup at the center of the start room. Click plumbing
## mirrors Door.gd. NexoController owns the pickup rule (must be in
## start_room) and kicks off the extraction phase.

signal nexo_clicked(nexo: Nexo)

var _picked_up: bool = false


func _ready() -> void:
	z_index = 2
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _picked_up:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	nexo_clicked.emit(self)
	get_viewport().set_input_as_handled()


func pick_up() -> void:
	_picked_up = true
	visible = false
	input_pickable = false

extends Node
class_name InputHandler

var player: PlayerMovement = null
var map_manager: MapManager = null

func setup(p_player: PlayerMovement, p_map: MapManager) -> void:
	player = p_player
	map_manager = p_map
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	# Delegate gating to parent controller if available
	var parent_ctrl := get_parent()
	if parent_ctrl and parent_ctrl.has_method("_can_process_input"):
		if not parent_ctrl._can_process_input():
			return

	# Mouse left click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if parent_ctrl and parent_ctrl.has_method("_handle_mouse_click"):
				var consumed : Variant = parent_ctrl._handle_mouse_click(event)
				if consumed:
					get_viewport().set_input_as_handled()
			return

	# Mouse hover
	if event is InputEventMouseMotion:
		if parent_ctrl and parent_ctrl.has_method("_handle_mouse_hover"):
			parent_ctrl._handle_mouse_hover(event)
		return

	# Keyboard
	if event is InputEventKey and event.pressed:
		if parent_ctrl and parent_ctrl.has_method("_handle_keyboard"):
			var consumed_key : Variant = parent_ctrl._handle_keyboard(event)
			if consumed_key:
				get_viewport().set_input_as_handled()
		return

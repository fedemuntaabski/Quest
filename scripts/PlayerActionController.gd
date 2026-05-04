extends Node
class_name PlayerActionController

var player: PlayerMovement
var map_manager: MapManager

func setup(p_player: PlayerMovement, p_map_manager: MapManager):
	player = p_player
	map_manager = p_map_manager


func process_input() -> void:
	print("PROCESS INPUT RUNNING")
	if player == null or map_manager == null:
		return

	_handle_keyboard()
	_handle_mouse()

func _handle_keyboard() -> void:
	var dir := Vector2i.ZERO

	if Input.is_action_just_pressed("ui_up"):
		dir = Vector2i.UP
	elif Input.is_action_just_pressed("ui_down"):
		dir = Vector2i.DOWN
	elif Input.is_action_just_pressed("ui_left"):
		dir = Vector2i.LEFT
	elif Input.is_action_just_pressed("ui_right"):
		dir = Vector2i.RIGHT

	if dir != Vector2i.ZERO:
		player.request_move(dir)


func _handle_mouse() -> void:
	print("CLICK DETECTED")

	var cam := player.get_node_or_null("Camera2D")
	if cam == null:
		print("NO CAMERA")
		return

	var world_pos: Vector2 = cam.get_global_mouse_position()
	var target_cell := map_manager.world_to_grid_coords(world_pos)

	print("PLAYER GRID:", player.grid_pos)
	print("TARGET CELL:", target_cell)

	var dir := target_cell - player.grid_pos
	print("RAW DIR:", dir)

	# convertir a cardinal
	if abs(dir.x) > abs(dir.y):
		dir = Vector2i(sign(dir.x), 0)
	else:
		dir = Vector2i(0, sign(dir.y))

	print("FINAL DIR:", dir)

	if dir != Vector2i.ZERO:
		print("TRY MOVE")
		player.request_move(dir)
	else:
		print("DIR ZERO - NO MOVE")

	
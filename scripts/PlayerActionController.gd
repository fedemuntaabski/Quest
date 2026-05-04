extends Node
class_name PlayerActionController

var player: PlayerMovement
var map_manager: MapManager

func setup(p_player: PlayerMovement, p_map_manager: MapManager):
	player = p_player
	map_manager = p_map_manager


# 🔥 INPUT REAL (event-driven)
func _input(event: InputEvent) -> void:
	if player == null or map_manager == null:
		return

	# 🖱️ CLICK IZQUIERDO
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_mouse_click()

	# ⌨️ TECLADO
	if event is InputEventKey and event.pressed:
		_handle_keyboard()


# ─────────────────────────────────────────────
# KEYBOARD (turn-based feel)
# ─────────────────────────────────────────────
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


# ─────────────────────────────────────────────
# MOUSE CLICK → 1 STEP (ToME style)
# ─────────────────────────────────────────────
func _handle_mouse_click() -> void:
	var cam := player.get_node_or_null("Camera2D")
	if cam == null:
		return

	var world_pos: Vector2 = cam.get_global_mouse_position()
	var target_cell := map_manager.world_to_grid_coords(world_pos)

	var dir := target_cell - player.grid_pos

	# 🔥 NORMALIZAR A 1 TILE (cardinal)
	if abs(dir.x) > abs(dir.y):
		dir = Vector2i(sign(dir.x), 0)
	else:
		dir = Vector2i(0, sign(dir.y))

	if dir != Vector2i.ZERO:
		player.request_move(dir)
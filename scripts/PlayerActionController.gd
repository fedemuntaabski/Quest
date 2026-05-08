extends Node
class_name PlayerActionController

var player: PlayerMovement
var map_manager: MapManager
const AttackAction = preload("res://scripts/AttackAction.gd")

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
	if player == null or not player.my_turn:
		return

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
	if player == null or not player.my_turn:
		return
	var cam := player.get_node_or_null("Camera2D")
	if cam == null:
		return

	var world_pos: Vector2 = cam.get_global_mouse_position()
	var target_cell := map_manager.world_to_grid_coords(world_pos)
	if target_cell == player.grid_pos:
		player.cancel_movement()
		return

	var enemy := map_manager.get_actor_at_cell(target_cell)
	if enemy and enemy != player:
		if player.combat_component == null:
			return

		if not player.combat_component.can_attack(enemy):
			return

		var action := AttackAction.new(player.combat_component, enemy)
		if player.turn_manager and player.turn_manager.action_queue:
			player.turn_manager.action_queue.queue_action(action)
			player.my_turn = false
		return


	var path: Array[Vector2i] = map_manager.find_path(player.grid_pos, target_cell)

	if path.is_empty():
		print("NO PATH")
		return

	player.set_path(path)



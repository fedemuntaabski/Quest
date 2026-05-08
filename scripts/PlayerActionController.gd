extends Node
class_name PlayerActionController

var player: PlayerMovement
var map_manager: MapManager
const AttackAction = preload("res://scripts/AttackAction.gd")

var hud: HUDController = null

var cards: Array[Dictionary] = []
var active_card_index: int = 0
var hovered_enemy: Node = null

func setup(p_player: PlayerMovement, p_map_manager: MapManager):
	player = p_player
	map_manager = p_map_manager
	_ensure_input_actions()
	_init_default_cards()
	_resolve_hud()


# 🔥 INPUT REAL (event-driven)
func _input(event: InputEvent) -> void:
	if player == null or map_manager == null:
		return

	# 🖱️ CLICK IZQUIERDO
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_mouse_click()

	# 🖱️ HOVER
	if event is InputEventMouseMotion:
		_handle_mouse_hover()

	# ⌨️ TECLADO
	if event is InputEventKey and event.pressed:
		_handle_keyboard()


# ─────────────────────────────────────────────
# KEYBOARD (turn-based feel)
# ─────────────────────────────────────────────
func _handle_keyboard() -> void:
	if player == null or not player.my_turn:
		return

	if Input.is_action_just_pressed("hotbar_1"):
		_select_card(0)
		return
	if Input.is_action_just_pressed("hotbar_2"):
		_select_card(1)
		return
	if Input.is_action_just_pressed("hotbar_3"):
		_select_card(2)
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

		if not _can_use_active_card():
			return

		_apply_active_card_to_combat()

		if not player.combat_component.can_attack(enemy):
			return

		var action := AttackAction.new(player.combat_component, enemy)
		if player.turn_manager and player.turn_manager.action_queue:
			player.turn_manager.action_queue.queue_action(action)
			player.my_turn = false
			_consume_active_card()
		return


	var path: Array[Vector2i] = map_manager.find_path(player.grid_pos, target_cell, player)

	if path.is_empty():
		print("NO PATH")
		return

	player.set_path(path)

func on_player_turn_started() -> void:
	_tick_cooldowns()
	_update_hotbar_ui()

func _ensure_input_actions() -> void:
	if not InputMap.has_action("hotbar_1"):
		InputMap.add_action("hotbar_1")
		var ev1 := InputEventKey.new()
		ev1.keycode = KEY_1
		InputMap.action_add_event("hotbar_1", ev1)

	if not InputMap.has_action("hotbar_2"):
		InputMap.add_action("hotbar_2")
		var ev2 := InputEventKey.new()
		ev2.keycode = KEY_2
		InputMap.action_add_event("hotbar_2", ev2)

	if not InputMap.has_action("hotbar_3"):
		InputMap.add_action("hotbar_3")
		var ev3 := InputEventKey.new()
		ev3.keycode = KEY_3
		InputMap.action_add_event("hotbar_3", ev3)

func _init_default_cards() -> void:
	cards = [
		{
			"name": "Espada",
			"description": "Golpe fisico cuerpo a cuerpo",
			"stat": "strength",
			"base_damage": 1,
			"range": 1,
			"cooldown": 0,
			"cooldown_remaining": 0
		},
		{
			"name": "Arco",
			"description": "Disparo preciso a distancia",
			"stat": "dexterity",
			"base_damage": 0,
			"range": 3,
			"cooldown": 1,
			"cooldown_remaining": 0
		},
		{
			"name": "Fuego",
			"description": "Hechizo de fuego a media distancia",
			"stat": "magic",
			"base_damage": 2,
			"range": 2,
			"cooldown": 2,
			"cooldown_remaining": 0
		}
	]

func _resolve_hud() -> void:
	hud = get_tree().get_first_node_in_group("hud") as HUDController
	if hud == null:
		call_deferred("_resolve_hud")
		return
	if hud and not hud.hotbar_slot_pressed.is_connected(_on_hotbar_slot_pressed):
		hud.hotbar_slot_pressed.connect(_on_hotbar_slot_pressed)
	_update_hotbar_ui()

func _update_hotbar_ui() -> void:
	if hud:
		hud.update_hotbar(cards, active_card_index)

func _select_card(index: int) -> void:
	if index < 0 or index >= cards.size():
		return
	active_card_index = index
	_update_hotbar_ui()

func _on_hotbar_slot_pressed(index: int) -> void:
	_select_card(index)

func _apply_active_card_to_combat() -> void:
	if player == null or player.combat_component == null:
		return

	var card := cards[active_card_index]
	player.combat_component.attack_stat = card.get("stat", "strength")
	player.combat_component.base_damage = int(card.get("base_damage", 0))
	player.combat_component.attack_range = int(card.get("range", 1))

func _can_use_active_card() -> bool:
	if cards.is_empty():
		return false

	var cd := int(cards[active_card_index].get("cooldown_remaining", 0))
	return cd <= 0

func _consume_active_card() -> void:
	var cd := int(cards[active_card_index].get("cooldown", 0))
	cards[active_card_index]["cooldown_remaining"] = cd
	_update_hotbar_ui()

func _tick_cooldowns() -> void:
	for i in range(cards.size()):
		var cd := int(cards[i].get("cooldown_remaining", 0))
		if cd > 0:
			cards[i]["cooldown_remaining"] = cd - 1

func _handle_mouse_hover() -> void:
	if player == null:
		return

	var cam := player.get_node_or_null("Camera2D")
	if cam == null:
		return

	var world_pos: Vector2 = cam.get_global_mouse_position()
	var target_cell := map_manager.world_to_grid_coords(world_pos)
	var actor := map_manager.get_actor_at_cell(target_cell)
	if actor == hovered_enemy:
		return

	if hovered_enemy and hovered_enemy.has_method("set_targeted"):
		hovered_enemy.set_targeted(false)

	hovered_enemy = actor if actor is Enemy else null
	if hovered_enemy and hovered_enemy.has_method("set_targeted"):
		hovered_enemy.set_targeted(true)



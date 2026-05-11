extends Node
class_name PlayerActionController

var player: PlayerMovement
var map_manager: MapManager

var hud: HUDController = null
var hovered_enemy: Node = null

var card_manager: CardManager = null
var combat_card_system: CombatCardSystem = null

var DEFAULT_DECK: Array[CardData] = [
	load("res://resources/cards/sword_card.tres"),
	load("res://resources/cards/bow_card.tres"),
	load("res://resources/cards/fire_card.tres"),
	load("res://resources/cards/focus_card.tres"),
	load("res://resources/cards/cripple_card.tres"),
]

func setup(p_player: PlayerMovement, p_map_manager: MapManager):
	player = p_player
	map_manager = p_map_manager
	_ensure_input_actions()
	_ensure_card_system()
	_resolve_hud()


# 🔥 INPUT REAL (event-driven)
func _input(event: InputEvent) -> void:
	if not _can_process_input():
		return
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
	if player == null or not player.can_accept_input():
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
	if player == null or not player.can_accept_input():
		return
	var cam := player.get_node_or_null("Camera2D")
	if cam == null:
		return

	var world_pos: Vector2 = cam.get_global_mouse_position()
	var target_cell := map_manager.world_to_grid_coords(world_pos)
	if target_cell == player.grid_pos:
		if combat_card_system and card_manager:
			var self_card := card_manager.get_active_card()
			if self_card and self_card.target_type == "self":
				if combat_card_system.can_play(self_card, player):
					combat_card_system.queue_card_action(self_card, player, player.turn_manager)
					_update_hotbar_ui()
					return
		player.cancel_movement()
		return
	print("CLICK WORLD: ", world_pos)
	print("TARGET CELL: ", target_cell)
	var enemy := map_manager.get_actor_at_cell(target_cell)
	print("ACTOR AT CELL: ", enemy)
	if enemy and enemy != player:
		print("ENEMY CLICKED")
		if combat_card_system and card_manager:
			var card := card_manager.get_active_card()
			if card and combat_card_system.can_play(card, enemy):
				if combat_card_system.queue_card_action(card, enemy, player.turn_manager):
					_update_hotbar_ui()
				return
		return


	var path: Array[Vector2i] = map_manager.find_path(player.grid_pos, target_cell, player)

	if path.is_empty():
		print("NO PATH")
		return

	player.set_path(path)

func on_player_turn_started() -> void:
	if card_manager:
		card_manager.tick_cooldowns()
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

func _ensure_card_system() -> void:
	if player == null:
		return

	card_manager = player.get_node_or_null("CardManager") as CardManager
	if card_manager == null:
		card_manager = CardManager.new()
		card_manager.name = "CardManager"
		player.add_child(card_manager)
	card_manager.max_equipped = 3
	card_manager.set_deck(DEFAULT_DECK)

	combat_card_system = player.get_node_or_null("CombatCardSystem") as CombatCardSystem
	if combat_card_system == null:
		combat_card_system = CombatCardSystem.new()
		combat_card_system.name = "CombatCardSystem"
		player.add_child(combat_card_system)

	combat_card_system.setup(player, map_manager, card_manager, player.get_combat_component())

func _resolve_hud() -> void:
	hud = get_tree().get_first_node_in_group("hud") as HUDController
	if hud == null:
		call_deferred("_resolve_hud")
		return
	if hud and not hud.hotbar_slot_pressed.is_connected(_on_hotbar_slot_pressed):
		hud.hotbar_slot_pressed.connect(_on_hotbar_slot_pressed)
	if card_manager:
		if not card_manager.cooldowns_changed.is_connected(_update_hotbar_ui):
			card_manager.cooldowns_changed.connect(_update_hotbar_ui)
		if not card_manager.active_index_changed.is_connected(_on_active_index_changed):
			card_manager.active_index_changed.connect(_on_active_index_changed)
		if not card_manager.equipped_changed.is_connected(_update_hotbar_ui):
			card_manager.equipped_changed.connect(_update_hotbar_ui)
	_update_hotbar_ui()

func _update_hotbar_ui() -> void:
	if hud and card_manager:
		hud.update_hotbar(card_manager.get_equipped_payload(), card_manager.active_index)

func _select_card(index: int) -> void:
	if card_manager == null:
		return
	card_manager.set_active_index(index)
	_update_hotbar_ui()

func _on_hotbar_slot_pressed(index: int) -> void:
	_select_card(index)

func _on_active_index_changed(_index: int) -> void:
	_update_hotbar_ui()

func _handle_mouse_hover() -> void:
	if not _can_process_input():
		return
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

func _can_process_input() -> bool:
	var game_state_manager := get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if game_state_manager:
		return game_state_manager.can_process_input()
	return true

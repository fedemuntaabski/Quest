extends Node
class_name PlayerActionController

const PRELOAD_ATTACK_ACTION = preload("res://scripts/core/combat/AttackAction.gd")

@export var card_library: CardLibrary

var player: PlayerMovement
var map_manager: MapManager

var hud: HUDController = null
var hovered_enemy: Node = null

var card_manager: CardManager = null
var combat_card_system: CombatCardSystem = null
var card_system_controller = null

var DEFAULT_DECK: Array[CardData] = [
	load("res://resources/cards/strength/sword_card.tres"),
	load("res://resources/cards/agility/bow_card.tres"),
	load("res://resources/cards/magic/fire_card.tres"),
	load("res://resources/cards/magic/focus_card.tres"),
	load("res://resources/cards/agility/cripple_card.tres"),
]

func setup(p_player: PlayerMovement, p_map_manager: MapManager):
	player = p_player
	map_manager = p_map_manager
	_ensure_input_actions()
	# Ensure an InputHandler child exists to capture input events
	var input_handler := get_node_or_null("InputHandler") as InputHandler
	if input_handler == null:
		input_handler = InputHandler.new()
		input_handler.name = "InputHandler"
		add_child(input_handler)
	input_handler.setup(player, map_manager)
	# Setup card system via CardSystemController
	card_system_controller = get_node_or_null("CardSystemController")
	if card_system_controller == null:
		var cls = load("res://scripts/core/cards/CardSystemController.gd")
		card_system_controller = cls.new()
		card_system_controller.name = "CardSystemController"
		add_child(card_system_controller)
	card_system_controller.setup(player, map_manager, card_library)
	# Expose convenience references
	card_manager = card_system_controller.card_manager
	combat_card_system = card_system_controller.combat_card_system
	# Bind HUD via CardSystemController
	card_system_controller.bind_hud()


# Input is now handled by InputHandler child; keep handlers here for delegation


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
	var world_pos: Vector2 = _get_mouse_world_pos()
	if map_manager:
		map_manager.update_hover(world_pos)
	var target_cell := map_manager.hovered_cell if map_manager else Vector2i.ZERO
	if target_cell == Vector2i(-999, -999) and map_manager:
		target_cell = map_manager.world_to_grid_coords(world_pos)
	if target_cell == player.grid_pos:
		if combat_card_system and card_manager:
			var self_card := card_manager.get_active_card()
			if self_card and self_card.target_type == "self":
				if combat_card_system.can_play(self_card, player):
					combat_card_system.queue_card_action(self_card, player, player.turn_manager)
					if card_system_controller:
						card_system_controller.update_hotbar_ui()
					return
		player.cancel_movement()
		return
	var enemy := map_manager.get_actor_at_cell(target_cell)
	if _is_enemy_combat_target(enemy):
		if combat_card_system and card_manager:
			var card := card_manager.get_active_card()
			if card and combat_card_system.can_play(card, enemy):
				if combat_card_system.queue_card_action(card, enemy, player.turn_manager):
					if card_system_controller:
						card_system_controller.update_hotbar_ui()
				return
		if _queue_basic_attack(enemy):
			return
		_move_towards_enemy(enemy)
		return


	var path: Array[Vector2i] = map_manager.find_path(player.grid_pos, target_cell, player)

	if path.is_empty():
		return

	player.set_path(path)
	
	# Clear path preview overlay once movement is confirmed/queued
	var highlighter := get_tree().get_first_node_in_group("tile_highlighter") as TileHighlighter
	if highlighter:
		highlighter.clear_path_preview()

func on_player_turn_started() -> void:
	if card_system_controller:
		card_system_controller.tick_cooldowns()
		card_system_controller.update_hotbar_ui()

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
	var starter_deck := _get_starter_deck()
	card_manager.set_deck(starter_deck)

	combat_card_system = player.get_node_or_null("CombatCardSystem") as CombatCardSystem
	if combat_card_system == null:
		combat_card_system = CombatCardSystem.new()
		combat_card_system.name = "CombatCardSystem"
		player.add_child(combat_card_system)

	combat_card_system.setup(player, map_manager, card_manager, player.get_combat_component())

func _get_starter_deck() -> Array[CardData]:
	if card_library == null:
		card_library = load("res://resources/cards/card_library.tres") as CardLibrary
	if card_library:
		var starter := card_library.get_starter_deck()
		if not starter.is_empty():
			return starter
	return DEFAULT_DECK

func _select_card(index: int) -> void:
	if card_manager == null:
		return
	
	# Toggle behavior: if already selected, deselect to neutral state
	if card_manager.active_index == index:
		card_manager.set_active_index(-1)
	else:
		card_manager.set_active_index(index)
	if card_system_controller:
		card_system_controller.update_hotbar_ui()

func _on_hotbar_slot_pressed(index: int) -> void:
	_select_card(index)

func _on_active_index_changed(_index: int) -> void:
	if card_system_controller:
		card_system_controller.update_hotbar_ui()

func _handle_mouse_hover() -> void:
	if not _can_process_input():
		return
	if player == null:
		return
	var world_pos: Vector2 = _get_mouse_world_pos()
	var target_cell := map_manager.world_to_grid_coords(world_pos)
	var actor := map_manager.get_actor_at_cell(target_cell)
	if actor == hovered_enemy:
		return

	if hovered_enemy and hovered_enemy.has_method("set_targeted"):
		hovered_enemy.set_targeted(false)

	hovered_enemy = actor if _is_enemy_combat_target(actor) else null
	if hovered_enemy and hovered_enemy.has_method("set_targeted"):
		hovered_enemy.set_targeted(true)

func _can_process_input() -> bool:
	var game_state_manager := get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if game_state_manager:
		return game_state_manager.can_process_input()
	return true

func _is_enemy_combat_target(actor: Node) -> bool:
	if actor == null or actor == player:
		return false
	if actor.has_method("get_combat_component"):
		return actor.get_combat_component() != null
	return actor.get_node_or_null("CombatComponent") != null

func _queue_basic_attack(target: Node) -> bool:
	if player == null or player.turn_manager == null or player.turn_manager.action_queue == null:
		return false

	var player_combat := player.get_combat_component()
	if player_combat == null:
		return false
	if not player_combat.can_attack(target):
		return false

	var action := PRELOAD_ATTACK_ACTION.new(player_combat, target)
	player.turn_manager.action_queue.queue_action(action)
	return true

func _move_towards_enemy(enemy: Node) -> void:
	if player == null or map_manager == null:
		return
	if enemy == null or enemy.get("grid_pos") == null:
		return

	var enemy_cell: Vector2i = enemy.get("grid_pos")
	var path := map_manager.find_path_to_adjacent(player.grid_pos, enemy_cell, player)
	if path.is_empty():
		return
	player.set_path(path)

func _get_mouse_world_pos() -> Vector2:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if map_manager:
		var canvas_to_world: Transform2D = map_manager.get_global_transform_with_canvas().affine_inverse()
		return canvas_to_world * mouse_pos
	if player:
		var player_to_world: Transform2D = player.get_global_transform_with_canvas().affine_inverse()
		return player_to_world * mouse_pos
	return Vector2.ZERO

extends Node
class_name PlayerActionController

# Routes player input into movement requests and combat targeting while keeping
# the actual movement state and turn handling inside PlayerMovement.

const PRELOAD_ATTACK_ACTION = preload("res://scripts/core/combat/AttackAction.gd")

@export var card_library: CardLibrary

var player: PlayerMovement
var map_manager: MapManager

var hud: HUDController = null
var hovered_enemy: Node = null

var card_manager: CardManager = null
var combat_card_system: CombatCardSystem = null
@onready var card_system_controller: CardSystemController = $CardSystemController

func setup(p_player: PlayerMovement, p_map_manager: MapManager):
	player = p_player
	map_manager = p_map_manager
	_ensure_input_actions()
	var game_state_manager := get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if game_state_manager and not game_state_manager.state_changed.is_connected(_on_game_state_changed):
		game_state_manager.state_changed.connect(_on_game_state_changed)
	# Ensure an InputHandler child exists to capture input events
	var input_handler := get_node_or_null("InputHandler") as InputHandler
	if input_handler == null:
		input_handler = InputHandler.new()
		input_handler.name = "InputHandler"
		add_child(input_handler)
	input_handler.setup(player, map_manager)
	# Setup card system via explicit CardSystemController child reference.
	assert(card_system_controller != null, "[PlayerActionController] CardSystemController child is required in PlayerActionController")
	if card_system_controller == null:
		push_error("[PlayerActionController] FATAL: CardSystemController child is missing; cannot initialize card combat pipeline")
		return
	card_system_controller.setup(player, map_manager, card_library)
	# Expose convenience references
	card_manager = card_system_controller.card_manager
	combat_card_system = card_system_controller.combat_card_system
	if card_manager == null:
		push_error("[PlayerActionController] FATAL: card_manager is NULL after setup; aborting controller initialization")
		return
	if combat_card_system == null:
		push_error("[PlayerActionController] FATAL: combat_card_system is NULL after setup; aborting controller initialization")
		return
	if combat_card_system and not combat_card_system.card_played.is_connected(_on_card_played):
		combat_card_system.card_played.connect(_on_card_played)


# Input is now handled by InputHandler child; keep handlers here for delegation


# ─────────────────────────────────────────────
# KEYBOARD (turn-based feel)
# ─────────────────────────────────────────────
func _handle_keyboard(_event: InputEvent = null) -> bool:
	if player == null or not player.can_accept_input():
		return false

	if Input.is_action_just_pressed("hotbar_1"):
		_select_card(0)
		return true
	if Input.is_action_just_pressed("hotbar_2"):
		_select_card(1)
		return true
	if Input.is_action_just_pressed("hotbar_3"):
		_select_card(2)
		return true

	var dir := Vector2i.ZERO

	if Input.is_action_just_pressed("move_up"):
		dir = Vector2i.UP
	elif Input.is_action_just_pressed("move_down"):
		dir = Vector2i.DOWN
	elif Input.is_action_just_pressed("move_left"):
		dir = Vector2i.LEFT
	elif Input.is_action_just_pressed("move_right"):
		dir = Vector2i.RIGHT

	if dir != Vector2i.ZERO:
		player.request_move(dir)
		return true

	return false


# ─────────────────────────────────────────────
# MOUSE CLICK → 1 STEP (ToME style)
# ─────────────────────────────────────────────
func _handle_mouse_click(_event: InputEventMouseButton = null) -> bool:
	if player == null:
		return false
	if not _has_card_dependencies():
		return true
	if not player.can_accept_input():
		return false
	var world_pos: Vector2 = _get_mouse_world_pos()
	if map_manager:
		map_manager.update_hover(world_pos)
	var target_cell := map_manager.hovered_cell if map_manager else Vector2i.ZERO
	if target_cell == Vector2i(-999, -999) and map_manager:
		target_cell = map_manager.world_to_grid_coords(world_pos)

	var active_card := card_manager.get_active_card() if card_manager else null
	if active_card:
		if active_card.target_type == "self":
			if target_cell != player.grid_pos:
				return true
			var ccs := _get_combat_card_system()
			if ccs:
				var self_validation := ccs.get_card_validation(active_card, player)
				if bool(self_validation.get("valid", false)):
					var queued_self := ccs.queue_card_action(active_card, player, player.turn_manager)
					if queued_self and card_system_controller:
						_clear_card_targeting_state()
			return true

		if active_card.target_type == "enemy":
			var enemy_card_target := map_manager.get_actor_at_cell(target_cell) if map_manager else null
			if not _is_enemy_combat_target(enemy_card_target):
				return true
			var ccs := _get_combat_card_system()
			if ccs:
				var enemy_validation := ccs.get_card_validation(active_card, enemy_card_target)
				if bool(enemy_validation.get("valid", false)):
					var queued_enemy := ccs.queue_card_action(active_card, enemy_card_target, player.turn_manager)
					if queued_enemy and card_system_controller:
						_clear_card_targeting_state()
			return true

	if target_cell == player.grid_pos:
		var ccs := _get_combat_card_system()
		if ccs and card_manager:
			var self_card := card_manager.get_active_card()
			if self_card and self_card.target_type == "self":
				var self_validation := ccs.get_card_validation(self_card, player)
				if bool(self_validation.get("valid", false)):
					var queued := ccs.queue_card_action(self_card, player, player.turn_manager)
					if queued and card_system_controller:
						_clear_card_targeting_state()
					return true
		player.cancel_movement()
		return true
	var enemy := map_manager.get_actor_at_cell(target_cell)
	if _is_enemy_combat_target(enemy):
		var ccs := _get_combat_card_system()
		if ccs and card_manager:
			var card := card_manager.get_active_card()
			if card and bool(ccs.get_card_validation(card, enemy).get("valid", false)):
				var queued := ccs.queue_card_action(card, enemy, player.turn_manager)
				if queued:
					_clear_card_targeting_state()
				return true
		if _queue_basic_attack(enemy):
			return true
		if player.request_path_to_adjacent(enemy.grid_pos):
			return true
		return true


	if not player.request_path_to_cell(target_cell):
		return true
	
	# Clear path preview overlay once movement is confirmed/queued
	var highlighter := get_tree().get_first_node_in_group("tile_highlighter") as TileHighlighter
	if highlighter:
		highlighter.clear_path_preview()
	return true

func on_player_turn_started() -> void:
	if card_system_controller:
		card_system_controller.tick_cooldowns()

func _on_card_played(_card: CardData, _target: Node, _result: Dictionary) -> void:
	_clear_card_targeting_state()

func _clear_card_targeting_state() -> void:
	if card_system_controller:
		card_system_controller.request_set_active_index(-1)
	else:
		if card_manager:
			card_manager.set_active_index(-1)
	_clear_hover_targeting_state()

func _clear_hover_targeting_state() -> void:
	if hovered_enemy and hovered_enemy.has_method("set_targeted"):
		hovered_enemy.set_targeted(false)
	hovered_enemy = null
	# Centralize hover clear in MapManager (MapManager is the source of truth for hovered_cell)
	if map_manager:
		map_manager.clear_hover()
	var highlighter := get_tree().get_first_node_in_group("tile_highlighter") as TileHighlighter
	if highlighter:
		highlighter.clear_path_preview()

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

func _select_card(index: int) -> void:
	if card_manager == null:
		return
	if not _can_process_input():
		return
	
	# Toggle behavior: if already selected, deselect to neutral state
	if card_manager.active_index == index:
		if card_system_controller:
			card_system_controller.request_set_active_index(-1)
		else:
			card_manager.set_active_index(-1)
	else:
		if card_system_controller:
			card_system_controller.request_set_active_index(index)
		else:
			card_manager.set_active_index(index)

func _on_hotbar_slot_pressed(index: int) -> void:
	_select_card(index)

func clear_card_targeting_state() -> void:
	_clear_card_targeting_state()

func clear_hover_targeting_state() -> void:
	_clear_hover_targeting_state()

func _on_game_state_changed(new_state: GameStateManager.State, _old_state: GameStateManager.State) -> void:
	if new_state != GameStateManager.State.ACTIVE:
		_clear_card_targeting_state()

func _handle_mouse_hover(_event: InputEvent = null) -> void:
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
		var comp = actor.get_combat_component()
		return comp != null
	return actor.get_node_or_null("CombatComponent") != null

func _queue_basic_attack(target: Node) -> bool:
	if player == null or player.turn_manager == null or player.turn_manager.action_queue == null:
		return false

	var player_combat := player.get_combat_component()
	if player_combat == null:
		return false
	if not bool(CombatValidation.validate_target(player_combat, target, player_combat.map_manager, player_combat.attack_range, true).get("valid", false)):
		return false

	var action := PRELOAD_ATTACK_ACTION.new(player_combat, target)
	player.turn_manager.action_queue.queue_action(action)
	return true

func _has_card_dependencies() -> bool:
	if card_system_controller == null:
		push_error("[PlayerActionController] dependency check failed: card_system_controller is NULL")
		return false
	if card_manager == null:
		push_error("[PlayerActionController] dependency check failed: card_manager is NULL")
		return false
	if combat_card_system == null:
		push_error("[PlayerActionController] dependency check failed: combat_card_system is NULL")
		return false
	return true

func _get_combat_card_system() -> CombatCardSystem:
	if combat_card_system == null:
		push_error("[PlayerActionController] _get_combat_card_system: combat_card_system is NULL (initialization failure)")
		return null
	return combat_card_system

func _get_mouse_world_pos() -> Vector2:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if map_manager:
		var canvas_to_world: Transform2D = map_manager.get_global_transform_with_canvas().affine_inverse()
		return canvas_to_world * mouse_pos
	if player:
		var player_to_world: Transform2D = player.get_global_transform_with_canvas().affine_inverse()
		return player_to_world * mouse_pos
	return Vector2.ZERO

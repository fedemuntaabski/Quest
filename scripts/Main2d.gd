extends Node2D

# ─────────────────────────────────────────────
# NODES
# ─────────────────────────────────────────────
@onready var map_manager: MapManager = $MapManager
@onready var hud: HUDController = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var death_overlay: CanvasLayer = $DeathOverlay
@onready var enemy_manager: EnemyManager = $MapManager/EnemyManager
@onready var card_reward_ui: CardRewardUI = $CardRewardUI

@onready var retry_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var exit_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/ExitButton
@onready var death_gold_label: Label = $DeathOverlay/CenterContainer/VBoxContainer/GoldLabel

@onready var upgrade_menu: CanvasLayer = $UpgradeMenu

var game_state_manager: GameStateManager
var card_reward_manager: CardRewardManager

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────
var room_timer: Main2dRoomTimer
var death_handler: Main2dDeathHandler

var visited_rooms: Array[int] = []
var enemies_killed: int = 0
var rooms_cleared: int = 0
var _is_dead: bool = false

var tutorial_layer: Node = null

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	room_timer = Main2dRoomTimer.new()
	death_handler = Main2dDeathHandler.new()
	death_handler.setup(self, death_overlay, death_gold_label)

	_setup_managers()
	_connect_signals()
	_load_tutorial_if_needed()

	_reset_room_timer()

func _setup_managers() -> void:
	# GameStateManager
	game_state_manager = get_node_or_null("GameStateManager") as GameStateManager
	if game_state_manager == null:
		game_state_manager = GameStateManager.new()
		game_state_manager.name = "GameStateManager"
		add_child(game_state_manager)

	# CardRewardManager
	card_reward_manager = get_node_or_null("CardRewardManager") as CardRewardManager
	if card_reward_manager == null:
		card_reward_manager = CardRewardManager.new()
		card_reward_manager.name = "CardRewardManager"
		add_child(card_reward_manager)

	card_reward_manager.reward_ui = card_reward_ui
	
	# Connect reward signals
	if card_reward_manager and not card_reward_manager.reward_completed.is_connected(_on_reward_completed):
		card_reward_manager.reward_completed.connect(_on_reward_completed)
	if card_reward_manager and not card_reward_manager.reward_declined.is_connected(_on_reward_declined):
		card_reward_manager.reward_declined.connect(_on_reward_declined)

# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────
func _dg() -> DungeonGenerator:
	return map_manager.dungeon_generator

# ─────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────
func _connect_signals() -> void:
	_connect_dungeon()
	_connect_player()
	_connect_ui()

func _connect_dungeon() -> void:
	var dg = _dg()
	if not dg:
		return

	if not dg.room_changed.is_connected(_on_room_changed):
		dg.room_changed.connect(_on_room_changed)

	if enemy_manager and not enemy_manager.room_cleared.is_connected(_on_room_cleared):
		enemy_manager.room_cleared.connect(_on_room_cleared)

	if enemy_manager and not enemy_manager.enemy_defeated_global.is_connected(_on_enemy_defeated):
		enemy_manager.enemy_defeated_global.connect(_on_enemy_defeated)

	if enemy_manager and not enemy_manager.enemy_defeated_with_reward.is_connected(_on_enemy_defeated_with_reward):
		enemy_manager.enemy_defeated_with_reward.connect(_on_enemy_defeated_with_reward)

func _connect_player() -> void:
	var player_stats = get_node_or_null("/root/PlayerStats")

	if player_stats and not player_stats.player_died.is_connected(_on_player_died):
		player_stats.player_died.connect(_on_player_died)

func _connect_ui() -> void:
	if retry_button and not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)

	if exit_button and not exit_button.pressed.is_connected(_on_return_pressed):
		exit_button.pressed.connect(_on_return_pressed)

	if pause_menu and pause_menu.has_method("close_menu"):
		pause_menu.close_menu()

	if pause_menu and not pause_menu.exit_requested.is_connected(_on_pause_exit_requested):
		pause_menu.exit_requested.connect(_on_pause_exit_requested)

# ─────────────────────────────────────────────
# TUTORIAL 
# ─────────────────────────────────────────────
func _load_tutorial_if_needed() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr or not save_mgr.first_time_player:
		return

	var scene := load("res://scenes/TutorialLayer.tscn")
	if not scene:
		return

	tutorial_layer = scene.instantiate()
	add_child(tutorial_layer)

	# 🔥 Delegamos toda la lógica al propio tutorial
	if tutorial_layer.has_method("setup"):
		tutorial_layer.setup(_dg())

# ─────────────────────────────────────────────
# LOOP
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	if get_tree().paused:
		return

	var tick_data := room_timer.tick(delta)

	if hud:
		hud.update_room_timer(
			tick_data["remaining"],
			Main2dRoomTimer.ROOM_TIMER_SECONDS,
			tick_data["color"]
		)

	if tick_data["expired"]:
		push_warning("Room timer reached zero")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _is_dead:
		_set_paused_state(not get_tree().paused)
		get_viewport().set_input_as_handled()

# ─────────────────────────────────────────────
# GAME EVENTS
# ─────────────────────────────────────────────
func _on_room_changed(room_id: int) -> void:
	if room_id not in visited_rooms:
		visited_rooms.append(room_id)
		_reset_room_timer()

	if hud:
		hud.update_current_room(room_id)

	if hud and enemy_manager:
		hud.update_enemies_remaining(enemy_manager.get_enemies_in_room(room_id))

func _on_room_cleared(room_id: int) -> void:
	rooms_cleared += 1

	if upgrade_menu and upgrade_menu.has_method("show_menu"):
		upgrade_menu.show_menu(room_id)

func _on_enemy_defeated() -> void:
	enemies_killed += 1

	var dg = _dg()
	if hud and dg and enemy_manager:
		hud.update_enemies_remaining(
			enemy_manager.get_enemies_in_room(dg.active_room_id)
		)

func _on_player_died() -> void:
	if _is_dead:
		return
	
	_is_dead = true
	
	# Use GameStateManager to handle death state
	var gsm := _get_game_state_manager()
	if gsm:
		gsm.request_death()
	else:
		# Fallback to old method
		if map_manager and map_manager.turn_manager:
			map_manager.turn_manager.stop()
		if pause_menu and pause_menu.has_method("close_menu"):
			pause_menu.close_menu()
		get_tree().paused = true
	
	# Show death overlay
	if death_handler:
		death_handler.handle_player_died(enemies_killed, rooms_cleared)

# ─────────────────────────────────────────────
# PAUSE
# ─────────────────────────────────────────────
func _set_paused_state(paused: bool) -> void:
	if pause_menu:
		if paused and pause_menu.has_method("open_menu"):
			pause_menu.open_menu()
		elif not paused and pause_menu.has_method("close_menu"):
			pause_menu.close_menu()

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_pause_exit_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# ─────────────────────────────────────────────
# TIMER
# ─────────────────────────────────────────────
func _reset_room_timer() -> void:
	if room_timer:
		room_timer.reset()

func _get_game_state_manager() -> GameStateManager:
	return get_tree().get_first_node_in_group("game_state_manager") as GameStateManager

# ─────────────────────────────────────────────
# REWARD HANDLERS
# ─────────────────────────────────────────────
func _on_enemy_defeated_with_reward(_enemy, _position: Vector2) -> void:
	if _is_dead:
		return
	
	# Queue a card reward (actual UI will be shown via GameStateManager)
	if card_reward_manager and game_state_manager:
		# Don't show immediately - queue for after combat resolves
		call_deferred("_process_next_reward")

func _process_next_reward() -> void:
	if card_reward_manager and game_state_manager and game_state_manager.is_active():
		card_reward_manager.offer_reward()

func _on_reward_completed(_selected_card: CardData) -> void:
	# Reward completed, return to active state via GameStateManager
	if game_state_manager:
		game_state_manager.close_reward(_selected_card)
	_update_hotbar_display()

func _on_reward_declined() -> void:
	# Reward declined, return to active state via GameStateManager
	if game_state_manager:
		game_state_manager.close_reward(null)

func _update_hotbar_display() -> void:
	if map_manager:
		var player := map_manager.get_node_or_null("Player") as PlayerMovement
		if player:
			var controller := player.get_node_or_null("PlayerActionController") as PlayerActionController
			if controller:
				controller._update_hotbar_ui()

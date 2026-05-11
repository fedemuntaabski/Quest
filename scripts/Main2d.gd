extends Node2D

# ─────────────────────────────────────────────
# NODES
# ─────────────────────────────────────────────
@onready var map_manager: MapManager = $MapManager
@onready var hud: HUDController = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var death_overlay: CanvasLayer = $DeathOverlay
@onready var enemy_manager: EnemyManager = $MapManager/EnemyManager

@onready var retry_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var exit_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/ExitButton
@onready var death_gold_label: Label = $DeathOverlay/CenterContainer/VBoxContainer/GoldLabel

@onready var upgrade_menu: CanvasLayer = $UpgradeMenu

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

	_connect_signals()
	_load_tutorial_if_needed()

	_reset_room_timer()

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
	if map_manager and map_manager.turn_manager:
		map_manager.turn_manager.stop()
	if pause_menu and pause_menu.has_method("close_menu"):
		pause_menu.close_menu()

	var player := map_manager.get_node_or_null("Player") as PlayerMovement
	if player:
		var controller := player.get_node_or_null("PlayerActionController")
		if controller:
			controller.set_process_input(false)
	get_tree().paused = true

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

	get_tree().paused = paused

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

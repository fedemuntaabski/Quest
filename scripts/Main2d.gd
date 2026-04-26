extends Node2D

const ROOM_TIMER_SECONDS: float = 120.0
const WARNING_SECONDS: float = 60.0
const CRITICAL_SECONDS: float = 15.0

@onready var dungeon_generator: DungeonGenerator = $MapManager/DungeonGenerator
@onready var hud: HUDController = $HUD
@onready var pause_menu: Node = $PauseMenu
@onready var death_overlay: CanvasLayer = $DeathOverlay
@onready var return_button: Button = $DeathOverlay/ReturnButton

var room_timer_remaining: float = ROOM_TIMER_SECONDS
var timer_expired_logged: bool = false
var visited_rooms: Array[int] = []

var tutorial_layer: Node = null

var enemies_killed: int = 0
var rooms_cleared: int = 0
var _is_dead: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if dungeon_generator:
		if not dungeon_generator.room_changed.is_connected(_on_room_changed):
			dungeon_generator.room_changed.connect(_on_room_changed)
		if not dungeon_generator.room_cleared.is_connected(_on_room_cleared):
			dungeon_generator.room_cleared.connect(_on_room_cleared)
		if not dungeon_generator.enemy_defeated_global.is_connected(_on_enemy_defeated):
			dungeon_generator.enemy_defeated_global.connect(_on_enemy_defeated)
			
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.first_time_player:
		var tut_scene = load("res://scenes/TutorialLayer.tscn")
		if tut_scene:
			tutorial_layer = tut_scene.instantiate()
			add_child(tutorial_layer)
			if dungeon_generator and tutorial_layer.has_method("_on_room_cleared"):
				dungeon_generator.room_cleared.connect(tutorial_layer._on_room_cleared)

	var upgrade_menu := get_node_or_null("UpgradeMenu")
	if upgrade_menu and not upgrade_menu.upgrade_chosen.is_connected(_on_upgrade_chosen):
		upgrade_menu.upgrade_chosen.connect(_on_upgrade_chosen)

	var player_stats_autoload = get_node_or_null("/root/PlayerStats")
	if player_stats_autoload and not player_stats_autoload.player_died.is_connected(_on_player_died):
		player_stats_autoload.player_died.connect(_on_player_died)

	if return_button and not return_button.pressed.is_connected(_on_return_pressed):
		return_button.pressed.connect(_on_return_pressed)

	if pause_menu and pause_menu.has_method("close_menu"):
		pause_menu.close_menu()

	_reset_room_timer()
	_update_timer_ui()

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	room_timer_remaining = maxf(0.0, room_timer_remaining - delta)
	_update_timer_ui()

	if room_timer_remaining <= 0.0 and not timer_expired_logged:
		timer_expired_logged = true
		push_warning("Main2d: Room timer reached zero.")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _is_dead:
		_set_paused_state(not get_tree().paused)
		get_viewport().set_input_as_handled()

func _on_room_changed(room_id: int) -> void:
	if room_id not in visited_rooms:
		visited_rooms.append(room_id)
		_reset_room_timer()
	_update_timer_ui()

func _on_room_cleared(room_id: int) -> void:
	rooms_cleared += 1
	var upgrade_menu := get_node_or_null("UpgradeMenu")	
	
	if upgrade_menu and upgrade_menu.has_method("show_menu"):
		upgrade_menu.show_menu(room_id)

func _on_enemy_defeated() -> void:
	enemies_killed += 1

func _on_player_died() -> void:
	if _is_dead: return
	_is_dead = true
	get_tree().paused = true
	var gold_reward = (enemies_killed * 10) + (rooms_cleared * 50)
	
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.gold += gold_reward
		save_mgr.save_game()
	
	if death_overlay:
		death_overlay.visible = true
		death_overlay.modulate.a = 0.0
		var t = create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(death_overlay, "modulate:a", 1.0, 2.0)

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_upgrade_chosen(_upgrade: Dictionary) -> void:
	var player_stats_autoload = get_node_or_null("/root/PlayerStats")
	if hud and player_stats_autoload and player_stats_autoload.stats:
		hud.update_stats(player_stats_autoload.stats)

func _set_paused_state(paused_value: bool) -> void:
	if pause_menu:
		if paused_value:
			if pause_menu.has_method("open_menu"):
				pause_menu.open_menu()
		elif pause_menu.has_method("close_menu"):
			pause_menu.close_menu()

	get_tree().paused = paused_value

func _reset_room_timer() -> void:
	room_timer_remaining = ROOM_TIMER_SECONDS
	timer_expired_logged = false

func _update_timer_ui() -> void:
	var timer_color := Color(1, 1, 1, 1)
	if room_timer_remaining <= CRITICAL_SECONDS:
		timer_color = Color(1, 0.24, 0.2, 1)
	elif room_timer_remaining <= WARNING_SECONDS:
		timer_color = Color(1, 0.85, 0.2, 1)

	if hud:
		hud.update_room_timer(room_timer_remaining, ROOM_TIMER_SECONDS, timer_color)

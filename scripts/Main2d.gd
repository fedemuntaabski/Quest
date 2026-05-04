extends Node2D

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────
const ROOM_TIMER_SECONDS: float = 120.0
const WARNING_SECONDS: float = 60.0
const CRITICAL_SECONDS: float = 15.0

# ─────────────────────────────────────────────
# NODES
# ─────────────────────────────────────────────
@onready var dungeon_generator: DungeonGenerator = $MapManager/DungeonGenerator
@onready var hud: HUDController = $HUD
@onready var pause_menu: Node = $PauseMenu
@onready var death_overlay: CanvasLayer = $DeathOverlay

@onready var retry_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var exit_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/ExitButton
@onready var death_gold_label: Label = $DeathOverlay/CenterContainer/VBoxContainer/GoldLabel

@onready var upgrade_menu: CanvasLayer = $UpgradeMenu

@onready var debug_button: Button = $DebugLayer/DebugButton
@onready var debug_cards_button: Button = $CanvasLayer_debug_cartas/Button

@onready var map_manager: MapManager = $MapManager



# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────
var room_timer_remaining: float = ROOM_TIMER_SECONDS
var timer_expired_logged: bool = false

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

	_connect_signals()
	_load_tutorial_if_needed()

	var player := $MapManager/Player
	dungeon_generator.generate_dungeon(player)  # 🔥 ESTO FALTABA

	_reset_room_timer()
	_update_timer_ui()





# ─────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────
func _connect_signals() -> void:
	_connect_dungeon()
	_connect_player()
	_connect_ui()
	



func _connect_dungeon() -> void:
	if not dungeon_generator:
		return

	if not dungeon_generator.room_changed.is_connected(_on_room_changed):
		dungeon_generator.room_changed.connect(_on_room_changed)

	if not dungeon_generator.room_cleared.is_connected(_on_room_cleared):
		dungeon_generator.room_cleared.connect(_on_room_cleared)

	if not dungeon_generator.enemy_defeated_global.is_connected(_on_enemy_defeated):
		dungeon_generator.enemy_defeated_global.connect(_on_enemy_defeated)


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

	if dungeon_generator and tutorial_layer.has_method("_on_room_cleared"):
		dungeon_generator.room_cleared.connect(tutorial_layer._on_room_cleared)


# ─────────────────────────────────────────────
# LOOP
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	
	if get_tree().paused:
		return

	room_timer_remaining = maxf(0.0, room_timer_remaining - delta)
	_update_timer_ui()



	if room_timer_remaining <= 0.0 and not timer_expired_logged:
		timer_expired_logged = true
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

	_update_timer_ui()

	if hud:
		hud.update_current_room(room_id)

		if dungeon_generator:
			hud.update_enemies_remaining(
				dungeon_generator._room_enemy_counts.get(room_id, 0)
			)


func _on_room_cleared(room_id: int) -> void:
	rooms_cleared += 1

	if upgrade_menu and upgrade_menu.has_method("show_menu"):
		upgrade_menu.show_menu(room_id)


func _on_enemy_defeated() -> void:
	enemies_killed += 1

	if hud and dungeon_generator:
		hud.update_enemies_remaining(
			dungeon_generator._room_enemy_counts.get(
				dungeon_generator.active_room_id, 0
			)
		)


func _on_player_died() -> void:
	if _is_dead:
		return

	_is_dead = true
	get_tree().paused = true

	var gold_reward := enemies_killed * 10 + rooms_cleared * 50

	if death_gold_label:
		death_gold_label.text = "Oro ganado: %d" % gold_reward

	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.gold += gold_reward
		save_mgr.save_game()

	if death_overlay:
		death_overlay.visible = true
		death_overlay.modulate.a = 0.0

		var t := create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(death_overlay, "modulate:a", 1.0, 2.0)




func _update_hud_stats() -> void:
	var player_stats = get_node_or_null("/root/PlayerStats")

	if hud and player_stats and player_stats.stats:
		hud.update_stats(player_stats.stats)


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


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# ─────────────────────────────────────────────
# TIMER
# ─────────────────────────────────────────────
func _reset_room_timer() -> void:
	room_timer_remaining = ROOM_TIMER_SECONDS
	timer_expired_logged = false


func _update_timer_ui() -> void:
	var color := Color.WHITE

	if room_timer_remaining <= CRITICAL_SECONDS:
		color = Color(1, 0.24, 0.2)
	elif room_timer_remaining <= WARNING_SECONDS:
		color = Color(1, 0.85, 0.2)

	if hud:
		hud.update_room_timer(room_timer_remaining, ROOM_TIMER_SECONDS, color)

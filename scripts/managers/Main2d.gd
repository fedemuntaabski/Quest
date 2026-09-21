extends Node2D

# Main2d: minimal gameplay scaffold.
# Spawns the selected hero (real stats/AP from SaveManager/PlayerStats) into
# an empty test grid, drives a single-actor TurnManager loop, and wires the
# pause/death overlays. No dungeon, combat or card systems.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const SPAWN_POSITION := Vector2.ZERO

# ─────────────────────────────────────────────
# NODES
# ─────────────────────────────────────────────
@onready var hud: HUDController = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var death_overlay: CanvasLayer = $DeathOverlay

@onready var retry_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var exit_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/ExitButton
@onready var death_gold_label: Label = $DeathOverlay/CenterContainer/VBoxContainer/GoldLabel

var game_state_manager: GameStateManager
var player: Player
var turn_manager: TurnManager

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────
var death_handler: Main2dDeathHandler
var active_character_id: String = ""
var _is_dead: bool = false
var _run_gold_start: int = 0

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_content_scaling()

	death_handler = Main2dDeathHandler.new()
	death_handler.setup(self, death_overlay, death_gold_label)

	var save_mgr := ManagerLocator.get_save_manager()
	active_character_id = save_mgr.get_selected_character_id() if save_mgr else CharacterDatabase.get_default_id()

	_ensure_game_state_manager()
	_spawn_player()
	_setup_turn_manager()
	_connect_signals()

	var currency := ManagerLocator.get_currency_manager() as CurrencyManager
	if currency:
		_run_gold_start = int(currency.get_gold())

func _setup_content_scaling() -> void:
	var root_window: Window = get_tree().root
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func _ensure_game_state_manager() -> void:
	game_state_manager = get_node_or_null("GameStateManager") as GameStateManager
	if game_state_manager == null:
		game_state_manager = GameStateManager.new()
		game_state_manager.name = "GameStateManager"
		add_child(game_state_manager)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	player.name = "Player"
	player.position = SPAWN_POSITION
	add_child(player)
	QuestLogger.info(QuestLogger.Category.GENERAL, "Main2d: spawned character '%s'" % active_character_id)

func _setup_turn_manager() -> void:
	turn_manager = TurnManager.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)
	turn_manager.register_actor(player)
	turn_manager.start()

# ─────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────
func _connect_signals() -> void:
	var player_stats := ManagerLocator.get_player_stats()
	if player_stats and not player_stats.player_died.is_connected(_on_player_died):
		player_stats.player_died.connect(_on_player_died)

	if retry_button and not retry_button.pressed.is_connected(_reload_current_scene):
		retry_button.pressed.connect(_reload_current_scene)

	if exit_button and not exit_button.pressed.is_connected(_go_to_main_menu):
		exit_button.pressed.connect(_go_to_main_menu)

	if pause_menu:
		pause_menu.close()
		if not pause_menu.exit_requested.is_connected(_go_to_main_menu):
			pause_menu.exit_requested.connect(_go_to_main_menu)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _is_dead:
		var can_toggle_pause := pause_menu != null \
			and (pause_menu.is_open or (game_state_manager and game_state_manager.is_active()))
		if can_toggle_pause:
			pause_menu.toggle()
		get_viewport().set_input_as_handled()

# ─────────────────────────────────────────────
# GAME EVENTS
# ─────────────────────────────────────────────
func _on_player_died() -> void:
	if _is_dead:
		return

	_is_dead = true

	if game_state_manager:
		game_state_manager.request_death()
	else:
		if turn_manager:
			turn_manager.stop()
		if pause_menu:
			pause_menu.close()
		get_tree().paused = true

	if death_handler:
		death_handler.show_death_screen(0, 0, _get_run_gold_earned())

func _get_run_gold_earned() -> int:
	var currency := ManagerLocator.get_currency_manager() as CurrencyManager
	if currency:
		return max(0, int(currency.get_gold() - _run_gold_start))
	return 0

# ─────────────────────────────────────────────
# PAUSE / SCENE FLOW
# ─────────────────────────────────────────────
func _go_to_main_menu() -> void:
	_cleanup_and_change_scene("res://scenes/MainMenu.tscn")

func _reload_current_scene() -> void:
	_cleanup_and_change_scene("", true)

func _cleanup_and_change_scene(target_scene: String, reload: bool = false) -> void:
	ManagerLocator.flush_saves()
	get_tree().paused = false
	if reload:
		get_tree().reload_current_scene()
	elif not target_scene.is_empty():
		get_tree().change_scene_to_file(target_scene)

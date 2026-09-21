extends Node2D

# Main2d: minimal gameplay scaffold.
# Spawns the selected hero (real stats/AP from SaveManager/PlayerStats) into
# an empty test grid, drives a single-actor TurnManager loop, and wires the
# pause/death overlays. No dungeon, combat or card systems.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const SPAWN_CELL := Vector2i(1, 1)

# ─────────────────────────────────────────────
# NODES
# ─────────────────────────────────────────────
@onready var floor_layer: TileMapLayer = $Floor
@onready var highlight_layer: TileMapLayer = $Highlight
@onready var player_action_controller: PlayerActionController = $PlayerActionController
@onready var ap_label: Label = $PlayerActionController/ApLabel
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

	death_handler = Main2dDeathHandler.new()
	death_handler.setup(self, death_overlay, death_gold_label)

	var save_mgr := ManagerLocator.get_save_manager()
	active_character_id = save_mgr.get_selected_character_id() if save_mgr else CharacterDatabase.get_default_id()

	_ensure_game_state_manager()
	_spawn_player()
	_setup_turn_manager()
	_setup_player_action_controller()
	_connect_signals()

	var currency := ManagerLocator.get_currency_manager() as CurrencyManager
	if currency:
		_run_gold_start = int(currency.get_gold())

func _ensure_game_state_manager() -> void:
	game_state_manager = get_node_or_null("GameStateManager") as GameStateManager
	if game_state_manager == null:
		game_state_manager = GameStateManager.new()
		game_state_manager.name = "GameStateManager"
		add_child(game_state_manager)

func _spawn_player() -> void:
	var character_data := CharacterDatabase.get_by_id(active_character_id)
	player = PLAYER_SCENE.instantiate() as Player
	player.name = "Player"
	player.configure(character_data)
	add_child(player)
	player.set_grid_position(SPAWN_CELL, floor_layer)
	QuestLogger.info(QuestLogger.Category.GENERAL, "Main2d: spawned character '%s' at %s" % [active_character_id, SPAWN_CELL])

func _setup_turn_manager() -> void:
	turn_manager = TurnManager.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)
	turn_manager.register_actor(player)
	turn_manager.start()

func _setup_player_action_controller() -> void:
	if player_action_controller:
		player_action_controller.setup(player, floor_layer, highlight_layer, ap_label, turn_manager)

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
	var orchestrator := _get_orchestrator()
	if orchestrator:
		orchestrator.return_to_main_menu()

func _reload_current_scene() -> void:
	var orchestrator := _get_orchestrator()
	if orchestrator:
		orchestrator.reload_gameplay()

func _get_orchestrator() -> Main:
	var orchestrator := ManagerLocator.get_main_orchestrator()
	if orchestrator == null:
		QuestLogger.error(QuestLogger.Category.UI, "Main2d: no Main orchestrator in group 'main_orchestrator' — run the project via scenes/Main.tscn (F5), not this scene standalone (F6).")
	return orchestrator

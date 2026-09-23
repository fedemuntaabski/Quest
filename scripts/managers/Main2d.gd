extends Node2D

# Main2d: minimal gameplay scaffold.
# Spawns the selected hero (HP-only stats from SaveManager/PlayerStats) into
# a static room-graph test map (RoomManager), drives the DoorTurnSystem stub
# (global turn advances on door-open, ticks ResourceManager, reveals rooms),
# and wires the pause/death overlays. No combat, cards, or real enemy/dungeon-
# generation systems.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const NEXO_SCENE := preload("res://scenes/world/Nexo.tscn")
const SPAWN_ZONE_ID := "start_room"

## Static test layout: 5 rooms + 4 corridors, grouped into 5 reveal groups.
## Rects are in cell space (tile = 64px, read from the Floor tileset at
## runtime); "group" is the DoorTurnSystem room_id that reveals this zone.
const LAYOUT := {
	"zones": {
		"start_room":  {"kind": "room",     "pos": Vector2i(1, 7),  "size": Vector2i(5, 5), "group": "start"},
		"corr_hub":    {"kind": "corridor", "pos": Vector2i(7, 9),  "size": Vector2i(3, 1), "group": "hub"},
		"hub_room":    {"kind": "room",     "pos": Vector2i(10, 7), "size": Vector2i(5, 5), "group": "hub"},
		"corr_north":  {"kind": "corridor", "pos": Vector2i(12, 3), "size": Vector2i(1, 3), "group": "north"},
		"north_room":  {"kind": "room",     "pos": Vector2i(10, 0), "size": Vector2i(5, 3), "group": "north"},
		"corr_east":   {"kind": "corridor", "pos": Vector2i(16, 9), "size": Vector2i(3, 1), "group": "east"},
		"east_room":   {"kind": "room",     "pos": Vector2i(19, 7), "size": Vector2i(5, 5), "group": "east"},
		"corr_vault":  {"kind": "corridor", "pos": Vector2i(21, 3), "size": Vector2i(1, 3), "group": "vault"},
		"vault_room":  {"kind": "room",     "pos": Vector2i(19, 0), "size": Vector2i(5, 3), "group": "vault", "is_exit_room": true},
	},
	"connections": [
		["start_room", "corr_hub"], ["corr_hub", "hub_room"],
		["hub_room", "corr_north"], ["corr_north", "north_room"],
		["hub_room", "corr_east"], ["corr_east", "east_room"],
		["east_room", "corr_vault"], ["corr_vault", "vault_room"],
	],
	"groups": {
		"start": {"zones": ["start_room"], "visited": true},
		"hub":   {"zones": ["corr_hub", "hub_room"], "visited": false},
		"north": {"zones": ["corr_north", "north_room"], "visited": false},
		"east":  {"zones": ["corr_east", "east_room"], "visited": false},
		"vault": {"zones": ["corr_vault", "vault_room"], "visited": false},
	},
}

# ─────────────────────────────────────────────
# NODES
# ─────────────────────────────────────────────
@onready var floor_layer: TileMapLayer = $Floor
@onready var room_manager: RoomManager = $RoomManager
@onready var player_action_controller: PlayerActionController = $PlayerActionController
@onready var doors_root: Node2D = $Doors
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var death_overlay: CanvasLayer = $DeathOverlay
@onready var victory_overlay: CanvasLayer = $VictoryOverlay

@onready var retry_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var exit_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/ExitButton
@onready var death_gold_label: Label = $DeathOverlay/CenterContainer/VBoxContainer/GoldLabel

@onready var return_button: Button = $VictoryOverlay/CenterContainer/VBoxContainer/ReturnButton
@onready var victory_gold_label: Label = $VictoryOverlay/CenterContainer/VBoxContainer/GoldLabel

var game_state_manager: GameStateManager
var player: Player
var door_turn_system: DoorTurnSystem
var room_power_system: RoomPowerSystem
var module_build_system: ModuleBuildSystem
var enemy_manager: EnemyManager
var extraction_manager: ExtractionManager
var nexo: Nexo
var nexo_controller: NexoController

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────
var death_handler: Main2dDeathHandler
var victory_handler: Main2dVictoryHandler
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

	victory_handler = Main2dVictoryHandler.new()
	victory_handler.setup(self, victory_overlay, victory_gold_label)

	var save_mgr := ManagerLocator.get_save_manager()
	active_character_id = save_mgr.get_selected_character_id() if save_mgr else CharacterDatabase.get_default_id()

	_ensure_game_state_manager()
	_setup_door_turn_system()
	_setup_room_manager()
	_setup_room_power_system()
	_setup_module_build_system()
	_setup_enemy_manager()
	_setup_extraction_manager()
	_register_groups_and_doors()
	_spawn_player()
	_spawn_nexo()
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
	player.set_zone(SPAWN_ZONE_ID, room_manager.get_center(SPAWN_ZONE_ID), floor_layer)
	QuestLogger.info(QuestLogger.Category.GENERAL, "Main2d: spawned character '%s' at zone '%s'" % [active_character_id, SPAWN_ZONE_ID])

func _setup_door_turn_system() -> void:
	door_turn_system = DoorTurnSystem.new()
	door_turn_system.name = "DoorTurnSystem"
	add_child(door_turn_system)
	door_turn_system.room_revealed.connect(_on_room_revealed)

func _setup_room_manager() -> void:
	room_manager.setup(floor_layer, door_turn_system)
	room_manager.build_from_layout(LAYOUT)

func _setup_room_power_system() -> void:
	room_power_system = RoomPowerSystem.new()
	room_power_system.name = "RoomPowerSystem"
	add_child(room_power_system)
	room_power_system.setup(room_manager)

func _setup_module_build_system() -> void:
	module_build_system = ModuleBuildSystem.new()
	module_build_system.name = "ModuleBuildSystem"
	add_child(module_build_system)
	module_build_system.setup(room_manager)

func _setup_enemy_manager() -> void:
	enemy_manager = EnemyManager.new()
	enemy_manager.name = "EnemyManager"
	add_child(enemy_manager)
	enemy_manager.setup(room_manager)

func _setup_extraction_manager() -> void:
	extraction_manager = ExtractionManager.new()
	extraction_manager.name = "ExtractionManager"
	add_child(extraction_manager)
	extraction_manager.setup(room_manager, enemy_manager)

func _spawn_nexo() -> void:
	nexo = NEXO_SCENE.instantiate() as Nexo
	nexo.name = "Nexo"
	nexo.global_position = room_manager.get_center("start_room")
	add_child(nexo)

	nexo_controller = NexoController.new()
	nexo_controller.name = "NexoController"
	add_child(nexo_controller)
	nexo_controller.setup(nexo, room_manager)

func _register_groups_and_doors() -> void:
	var groups_def: Dictionary = LAYOUT["groups"]
	for group_id in groups_def.keys():
		var group_def: Dictionary = groups_def[group_id]
		door_turn_system.register_room(group_id, room_manager.get_group_cells(group_id), group_def.get("visited", false))

	for child in doors_root.get_children():
		room_manager.register_door(child as Door)

	room_manager.on_group_revealed("start")

func _on_room_revealed(group_id: String, _cells: Array[Vector2i]) -> void:
	var door := room_manager.get_door_for_group(group_id)
	if door:
		var door_cell: Array[Vector2i] = [door.cell]
		floor_layer.fill_cells(door_cell)

	room_manager.on_group_revealed(group_id)

	if player_action_controller:
		player_action_controller.refresh_zones()

func _setup_player_action_controller() -> void:
	if player_action_controller:
		player_action_controller.setup(player, floor_layer, room_manager, door_turn_system)

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

	if return_button and not return_button.pressed.is_connected(_go_to_main_menu):
		return_button.pressed.connect(_go_to_main_menu)

	if game_state_manager and not game_state_manager.victory_entered.is_connected(_on_victory):
		game_state_manager.victory_entered.connect(_on_victory)

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
		if pause_menu:
			pause_menu.close()
		get_tree().paused = true

	if death_handler:
		death_handler.show_death_screen(0, 0, _get_run_gold_earned())

func _on_victory() -> void:
	if pause_menu:
		pause_menu.close()

	if victory_handler:
		victory_handler.show_victory_screen(_get_run_gold_earned())

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

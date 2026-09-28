extends Node2D

# Main2d: minimal gameplay scaffold.
# Spawns the selected hero (HP-only stats from SaveManager/PlayerStats) into
# a per-floor seeded MapGenerator map (fallback: FALLBACK_LAYOUT) built by
# RoomManager, drives the DoorTurnSystem stub
# (global turn advances on door-open, ticks ResourceManager, reveals rooms),
# and wires the pause/death overlays. No combat, cards, or real enemy/dungeon-
# generation systems.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const NEXO_SCENE := preload("res://scenes/world/Nexo.tscn")
const DOOR_SCENE := preload("res://scenes/Door.tscn")
## Nexo sits above the start room's center: the lit start room's MAJOR build
## slot occupies the center itself (RoomZone.BUILDING_SLOT_OFFSETS[0]).
const NEXO_OFFSET := Vector2(0, -56)
## Hand-authored map (the pre-generator 5-room layout). Used when
## force_fallback_layout is on or the generated map fails validation.
const FALLBACK_LAYOUT: MapLayout = preload("res://resources/maps/fallback_layout.tres")

## Debug: skip MapGenerator and always play FALLBACK_LAYOUT.
@export var force_fallback_layout: bool = false
## Debug/tests: floor index used when run without the Main orchestrator.
@export var standalone_floor: int = 1

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
@onready var victory_label: Label = $VictoryOverlay/CenterContainer/VBoxContainer/VictoryLabel
@onready var next_floor_button: Button = $VictoryOverlay/CenterContainer/VBoxContainer/NextFloorButton

var game_state_manager: GameStateManager
var player: Player
var door_turn_system: DoorTurnSystem
var room_power_system: RoomPowerSystem
var module_build_system: ModuleBuildSystem
var enemy_manager: EnemyManager
var extraction_manager: ExtractionManager
var floor_manager: FloorManager
var exit_indicator: ExitIndicator
var nexo: Nexo
var nexo_controller: NexoController
var map_layout: MapLayout

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
	_setup_floor_manager()
	_setup_room_manager()
	_setup_room_power_system()
	_setup_module_build_system()
	_setup_enemy_manager()
	_setup_extraction_manager()
	_register_groups_and_doors()
	_setup_exit_indicator()
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
	var spawn_zone_id := room_manager.get_start_zone_id()
	player.set_zone(spawn_zone_id, room_manager.get_center(spawn_zone_id), floor_layer)
	QuestLogger.info(QuestLogger.Category.GENERAL, "Main2d: spawned character '%s' at zone '%s'" % [active_character_id, spawn_zone_id])

func _setup_door_turn_system() -> void:
	door_turn_system = DoorTurnSystem.new()
	door_turn_system.name = "DoorTurnSystem"
	add_child(door_turn_system)
	door_turn_system.room_revealed.connect(_on_room_revealed)

func _setup_room_manager() -> void:
	room_manager.setup(floor_layer, door_turn_system)
	map_layout = _build_map_layout()
	room_manager.build_from_map(map_layout)


func _build_map_layout() -> MapLayout:
	if force_fallback_layout:
		return FALLBACK_LAYOUT
	var layout := MapGenerator.generate(floor_manager.map_seed, floor_manager.room_count(), floor_manager.branch_chance())
	var problems := layout.validate()
	if not problems.is_empty():
		QuestLogger.error(QuestLogger.Category.MAP, "Main2d: generated map (seed %d) invalid, using fallback: %s" % [layout.map_seed, problems])
		return FALLBACK_LAYOUT
	return layout

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
	enemy_manager.setup(room_manager, door_turn_system, floor_manager)

func _setup_floor_manager() -> void:
	floor_manager = FloorManager.new()
	floor_manager.name = "FloorManager"
	add_child(floor_manager)
	var orchestrator := ManagerLocator.get_main_orchestrator()
	if orchestrator:
		floor_manager.setup(orchestrator.current_floor, orchestrator.run_seed)
	else:
		floor_manager.setup(standalone_floor, randi())
	door_turn_system.room_revealed.connect(floor_manager.on_room_discovered)
	floor_manager.floor_completed.connect(_on_floor_completed)

func _setup_extraction_manager() -> void:
	extraction_manager = ExtractionManager.new()
	extraction_manager.name = "ExtractionManager"
	add_child(extraction_manager)
	extraction_manager.setup(room_manager, enemy_manager, floor_manager.extraction_interval())
	extraction_manager.victory_declared.connect(floor_manager.complete_floor)

func _setup_exit_indicator() -> void:
	exit_indicator = ExitIndicator.new()
	exit_indicator.name = "ExitIndicator"
	add_child(exit_indicator)
	exit_indicator.setup(room_manager, door_turn_system, extraction_manager)


func _spawn_nexo() -> void:
	nexo = NEXO_SCENE.instantiate() as Nexo
	nexo.name = "Nexo"
	nexo.global_position = room_manager.get_center(room_manager.get_start_zone_id()) + NEXO_OFFSET
	add_child(nexo)

	nexo_controller = NexoController.new()
	nexo_controller.name = "NexoController"
	add_child(nexo_controller)
	nexo_controller.setup(nexo, room_manager)

func _register_groups_and_doors() -> void:
	var start_group := room_manager.get_group_id(room_manager.get_start_zone_id())
	for group_id in room_manager.get_group_ids():
		door_turn_system.register_room(group_id, room_manager.get_group_cells(group_id), group_id == start_group)

	# One Door per corridor, at room_a's wall; opening it reveals room_b's group.
	for corridor in map_layout.corridors:
		var door := DOOR_SCENE.instantiate() as Door
		door.name = "Door_%s" % corridor.id
		door.door_id = corridor.id
		door.target_room_id = room_manager.get_group_id(corridor.room_b)
		door.from_zone_id = corridor.room_a
		door.cell = corridor.door_cell
		doors_root.add_child(door)
		room_manager.register_door(door)

	room_manager.refresh_visibility()
	room_manager.validate_graph()
	# The start room is lit for free (no dust paid → nothing to refund).
	room_manager.set_zone_powered(room_manager.get_start_zone_id(), true)

func _on_room_revealed(group_id: String, _cells: Array[Vector2i]) -> void:
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

	if next_floor_button and not next_floor_button.pressed.is_connected(_go_to_next_floor):
		next_floor_button.pressed.connect(_go_to_next_floor)

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

## Fires before victory_entered (ExtractionManager emits victory_declared
## before requesting the VICTORY state), so the overlay is ready when shown.
func _on_floor_completed(completed_floor: int) -> void:
	var has_next := not floor_manager.is_final_floor()
	if next_floor_button:
		next_floor_button.visible = has_next
		next_floor_button.text = "Descender al piso %d" % (completed_floor + 1)
	if victory_label and has_next:
		victory_label.text = "¡Piso %d superado!" % completed_floor

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

func _go_to_next_floor() -> void:
	var orchestrator := _get_orchestrator()
	if orchestrator:
		orchestrator.advance_floor()

func _reload_current_scene() -> void:
	var orchestrator := _get_orchestrator()
	if orchestrator:
		orchestrator.reload_gameplay()

func _get_orchestrator() -> Main:
	var orchestrator := ManagerLocator.get_main_orchestrator()
	if orchestrator == null:
		QuestLogger.error(QuestLogger.Category.UI, "Main2d: no Main orchestrator in group 'main_orchestrator' — run the project via scenes/Main.tscn (F5), not this scene standalone (F6).")
	return orchestrator

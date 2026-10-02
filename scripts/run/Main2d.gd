extends Node2D

# Main2d: minimal gameplay scaffold.
# Spawns the party (PartyConfig: the selected hero + companions; HP-only
# stats from SaveManager/PlayerStats; Tab/portrait selects who moves) into
# a per-floor seeded MapGenerator map (fallback: FALLBACK_LAYOUT) built by
# RoomManager, drives the DoorTurnSystem stub
# (global turn advances on door-open, ticks ResourceManager, reveals rooms),
# and wires the pause/death overlays. No combat, cards, or real enemy/dungeon-
# generation systems.

const PLAYER_SCENE := preload("res://scenes/entities/Player.tscn")
const NEXO_SCENE := preload("res://scenes/world/Nexo.tscn")
const TILE_RENDERER_SCENE := preload("res://scenes/world/MapTileRenderer.tscn")
const DOOR_SCENE := preload("res://scenes/world/Door.tscn")
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
## Heroes spawned every floor (session 12).
@export var party_config: PartyConfig = preload("res://resources/characters/party_config.tres")

# ─────────────────────────────────────────────
# NODES
# ─────────────────────────────────────────────
@onready var floor_layer: TileMapLayer = $Floor
@onready var room_manager: RoomManager = $RoomManager
@onready var player_action_controller: PlayerActionController = $PlayerActionController
@onready var doors_root: Node2D = $Doors
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var death_overlay: DeathOverlay = $DeathOverlay
@onready var victory_overlay: VictoryOverlay = $VictoryOverlay

var game_state_manager: GameStateManager
## Party in spawn order; `player` = heroes[0] (the hero picked in
## HeroSelectMenu, holder of the only camera) — not the selected one.
var heroes: Array[Player] = []
var player: Player
var camera: GameCamera
var door_turn_system: DoorTurnSystem
var enemy_manager: EnemyManager
var extraction_manager: ExtractionManager
var floor_manager: FloorManager
var exit_indicator: ExitIndicator
var nexo: Nexo
var nexo_controller: NexoController
var map_layout: MapLayout
var tile_renderer: MapTileRenderer

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────
var _is_dead: bool = false
var pause_controller: PauseController
var hero_input: HeroInputController
var loot_spawner: LootSpawner

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_game_state_manager()
	_setup_door_turn_system()
	_setup_floor_manager()
	_setup_room_manager()
	_setup_enemy_manager()
	_setup_extraction_manager()
	_register_groups_and_doors()
	_setup_exit_indicator()
	_spawn_heroes()
	_spawn_nexo()
	_setup_player_action_controller()
	_setup_controllers()
	_connect_signals()

func _setup_controllers() -> void:
	pause_controller = PauseController.new()
	pause_controller.name = "PauseController"
	add_child(pause_controller)
	pause_controller.setup(game_state_manager)

	hero_input = HeroInputController.new()
	hero_input.name = "HeroInputController"
	add_child(hero_input)
	hero_input.setup(heroes, camera, _is_gameplay_active)

	loot_spawner = LootSpawner.new()
	loot_spawner.name = "LootSpawner"
	add_child(loot_spawner)
	loot_spawner.setup(room_manager, door_turn_system, floor_manager)

func _ensure_game_state_manager() -> void:
	game_state_manager = get_node_or_null("GameStateManager") as GameStateManager
	if game_state_manager == null:
		game_state_manager = GameStateManager.new()
		game_state_manager.name = "GameStateManager"
		add_child(game_state_manager)

## Every hero in the start room, like every floor. clear_party() first, so the
## first hero registered (heroes[0]) starts selected; run levels carry over.
func _spawn_heroes() -> void:
	var ps := ManagerLocator.get_player_stats()
	if ps:
		ps.clear_party()
	var session := ManagerLocator.get_game_session()
	var ids: Array[String]
	if session and session.has_selection():
		ids = session.get_party_ids()
	else:  # no HeroSelectMenu pick (standalone floor, tests): saved hero + PartyConfig companions
		var save_mgr := ManagerLocator.get_save_manager()
		ids = party_config.get_party_ids(save_mgr.get_selected_character_id() if save_mgr else CharacterDatabase.get_default_id())
	ids.resize(mini(ids.size(), party_config.party_size))
	var spawn_zone_id := room_manager.get_start_zone_id()
	for i in ids.size():
		var hero := PLAYER_SCENE.instantiate() as Player
		hero.name = "Player" if i == 0 else "Player%d" % (i + 1)
		hero.configure(CharacterDatabase.get_by_id(ids[i]))
		hero.sprite_offset = party_config.sprite_offset(i, ids.size())
		if i > 0:
			# ponytail: one camera, on heroes[0], following the selection. Move it
			# to Main2d if a hero can ever be freed mid-floor (permadeath).
			hero.get_node("Camera2D").free()
		add_child(hero)
		hero.set_zone(spawn_zone_id, room_manager.get_center(spawn_zone_id), floor_layer)
		heroes.append(hero)
	player = heroes[0]
	camera = player.get_node("Camera2D") as GameCamera
	var selection := ManagerLocator.get_selection_manager()
	if selection:
		selection.on_party_spawned(ids)
	camera.follow(_primary_hero())
	QuestLogger.info(QuestLogger.Category.GENERAL, "Main2d: spawned party %s at zone '%s'" % [ids, spawn_zone_id])


## The primary selected hero (SelectionManager); heroes[0] as a fallback.
func _primary_hero() -> Player:
	var selection := ManagerLocator.get_selection_manager()
	var id: String = selection.get_primary_id() if selection else ""
	for hero in heroes:
		if hero.stats.hero_id == id:
			return hero
	return heroes[0]


## Any selection change (click, portrait, F-keys, group, Tab): the primary hero
## takes the controller's highlight and the camera.
func _on_selection_changed(_selected_ids: Array[String]) -> void:
	var primary := _primary_hero()
	player_action_controller.set_player(primary)
	camera.follow(primary)

func _setup_door_turn_system() -> void:
	door_turn_system = DoorTurnSystem.new()
	door_turn_system.name = "DoorTurnSystem"
	add_child(door_turn_system)
	door_turn_system.room_revealed.connect(_on_room_revealed)

func _setup_room_manager() -> void:
	room_manager.setup(floor_layer, door_turn_system)
	map_layout = _build_map_layout()
	room_manager.build_from_map(map_layout)
	floor_manager.room_manager = room_manager
	# Art: tiles are drawn by the renderer; `Floor` stays as the hidden logical grid.
	tile_renderer = TILE_RENDERER_SCENE.instantiate() as MapTileRenderer
	tile_renderer.name = "MapTileRenderer"
	add_child(tile_renderer)
	tile_renderer.build(map_layout, room_manager.visual_config)
	room_manager.tile_renderer = tile_renderer
	floor_layer.visible = false


func _build_map_layout() -> MapLayout:
	if force_fallback_layout:
		return FALLBACK_LAYOUT
	var layout := MapGenerator.generate_floor(floor_manager.map_seed, floor_manager.config, floor_manager.floor_index)
	var problems := layout.validate()
	if not problems.is_empty():
		QuestLogger.error(QuestLogger.Category.MAP, "Main2d: generated map (seed %d) invalid, using fallback: %s" % [layout.map_seed, problems])
		return FALLBACK_LAYOUT
	return layout

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
	nexo.max_hp = floor_manager.config.nexo_max_hp if floor_manager and floor_manager.config else nexo.max_hp
	add_child(nexo)
	nexo.destroyed.connect(_on_player_died)  # same defeat as a dead hero

	nexo_controller = NexoController.new()
	nexo_controller.name = "NexoController"
	add_child(nexo_controller)
	nexo_controller.setup(nexo, room_manager)

func _register_groups_and_doors() -> void:
	var start_group := room_manager.get_group_id(room_manager.get_start_zone_id())
	for group_id in room_manager.get_group_ids():
		door_turn_system.register_room(group_id, room_manager.get_group_cells(group_id), group_id == start_group)

	# One Door per corridor, at room_a's wall; opening it reveals the corridor's
	# group (room_b's group, or the loop corridor alone).
	for corridor in map_layout.corridors:
		var door := DOOR_SCENE.instantiate() as Door
		door.name = "Door_%s" % corridor.id
		door.door_id = corridor.id
		door.target_room_id = room_manager.get_group_id(corridor.id)
		door.from_zone_id = corridor.room_a
		door.cell = corridor.door_cell
		door.east_west = corridor.is_east_west(map_layout.get_room(corridor.room_a))
		doors_root.add_child(door)
		room_manager.register_door(door)

	# Room-type build slots (Generator room: a second MAJOR slot).
	for room in map_layout.rooms:
		var rule := floor_manager.room_type_rule(room.get_room_type()) if floor_manager else null
		if rule and rule.extra_major_slots > 0:
			room_manager.get_zone_node(room.id).extra_major_slots = rule.extra_major_slots

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
		player_action_controller.setup(_primary_hero(), floor_layer, room_manager, door_turn_system)

# ─────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────
func _connect_signals() -> void:
	var player_stats := ManagerLocator.get_player_stats()
	if player_stats and not player_stats.player_died.is_connected(_on_player_died):
		player_stats.player_died.connect(_on_player_died)
	var selection := ManagerLocator.get_selection_manager()
	if selection and not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)

	death_overlay.retry_requested.connect(_reload_current_scene)
	death_overlay.exit_requested.connect(_go_to_main_menu)
	victory_overlay.next_floor_requested.connect(_go_to_next_floor)
	victory_overlay.return_requested.connect(_go_to_main_menu)

	if pause_menu:
		pause_menu.close()
		if not pause_menu.exit_requested.is_connected(_go_to_main_menu):
			pause_menu.exit_requested.connect(_go_to_main_menu)

	if game_state_manager and not game_state_manager.victory_entered.is_connected(_on_victory):
		game_state_manager.victory_entered.connect(_on_victory)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _is_dead:
		var can_toggle_pause := pause_menu != null \
			and (pause_menu.is_open or (game_state_manager and game_state_manager.is_active()))
		if can_toggle_pause:
			pause_menu.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tactical_pause") and _is_gameplay_active():
		pause_controller.toggle()
		get_viewport().set_input_as_handled()
	elif _is_gameplay_active() and hero_input.handle_key(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hero_cycle") and _is_gameplay_active():
		# Consumed so Tab never also moves GUI focus (ui_focus_next).
		var player_stats := ManagerLocator.get_player_stats()
		if player_stats:
			player_stats.cycle_active_hero()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	var vfx := get_tree().get_first_node_in_group("vfx_manager") if is_inside_tree() else null
	if vfx:
		vfx.clear()

func _is_gameplay_active() -> bool:
	return not _is_dead and (game_state_manager == null or game_state_manager.is_active())

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

	death_overlay.show_screen()

func _on_victory() -> void:
	if pause_menu:
		pause_menu.close()

	victory_overlay.show_screen()

## Fires before victory_entered (ExtractionManager emits victory_declared
## before requesting the VICTORY state), so the overlay is ready when shown.
func _on_floor_completed(completed_floor: int) -> void:
	victory_overlay.set_floor_result(completed_floor, not floor_manager.is_final_floor())

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

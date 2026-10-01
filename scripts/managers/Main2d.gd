extends Node2D

# Main2d: minimal gameplay scaffold.
# Spawns the party (PartyConfig: the selected hero + companions; HP-only
# stats from SaveManager/PlayerStats; Tab/portrait selects who moves) into
# a per-floor seeded MapGenerator map (fallback: FALLBACK_LAYOUT) built by
# RoomManager, drives the DoorTurnSystem stub
# (global turn advances on door-open, ticks ResourceManager, reveals rooms),
# and wires the pause/death overlays. No combat, cards, or real enemy/dungeon-
# generation systems.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const NEXO_SCENE := preload("res://scenes/world/Nexo.tscn")
const TILE_RENDERER_SCENE := preload("res://scenes/world/MapTileRenderer.tscn")
const DOOR_SCENE := preload("res://scenes/Door.tscn")
## Nexo sits above the start room's center: the lit start room's MAJOR build
## slot occupies the center itself (RoomZone.BUILDING_SLOT_OFFSETS[0]).
const NEXO_OFFSET := Vector2(0, -56)
## Loot rooms show a floating chest at the same spot when they are discovered.
const LOOT_CHEST_OFFSET := Vector2(0, -56)
const PICKUP_SCENE := preload("res://scenes/world/Pickup.tscn")
## Hand-authored map (the pre-generator 5-room layout). Used when
## force_fallback_layout is on or the generated map fails validation.
const FALLBACK_LAYOUT: MapLayout = preload("res://resources/maps/fallback_layout.tres")

## Extra px around a hero's body that still count as a click on it.
const HERO_PICK_MARGIN := 10.0
## Real-time window (ms) for the second tap of a group key.
const GROUP_DOUBLE_TAP_MS := 300

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
@onready var death_overlay: CanvasLayer = $DeathOverlay
@onready var victory_overlay: CanvasLayer = $VictoryOverlay

@onready var retry_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var exit_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/ExitButton

@onready var return_button: Button = $VictoryOverlay/CenterContainer/VBoxContainer/ReturnButton
@onready var victory_label: Label = $VictoryOverlay/CenterContainer/VBoxContainer/VictoryLabel
@onready var next_floor_button: Button = $VictoryOverlay/CenterContainer/VBoxContainer/NextFloorButton

var game_state_manager: GameStateManager
## Party in spawn order; `player` = heroes[0] (the hero picked in
## HeroSelectMenu, holder of the only camera) — not the selected one.
var heroes: Array[Player] = []
var player: Player
var camera: GameCamera
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
var tile_renderer: MapTileRenderer

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────
var death_handler: Main2dDeathHandler
var victory_handler: Main2dVictoryHandler
var active_character_id: String = ""
var _is_dead: bool = false
## Space: Engine.time_scale 0 (Tweens/Timers/physics delta stop, HUD/building
## still work). Kept across the Esc pause, which forces 1 while open.
var _tactical_paused: bool = false
var _last_group_key: int = 0
var _last_group_msec: int = -10000

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	death_handler = Main2dDeathHandler.new()
	death_handler.setup(self, death_overlay)

	victory_handler = Main2dVictoryHandler.new()
	victory_handler.setup(self, victory_overlay)

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
	_spawn_heroes()
	_spawn_nexo()
	_setup_player_action_controller()
	_connect_signals()

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
	var ids: Array[String] = session.get_party_ids() if session and session.has_selection() else party_config.get_party_ids(active_character_id)
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
	for zone_id in room_manager.get_group_zone_ids(group_id):
		if room_manager.get_room_type(zone_id) == RoomData.RoomType.LOOT:
			var chest := PICKUP_SCENE.instantiate() as Pickup
			chest.kind = Pickup.Kind.CHEST
			chest.position = room_manager.get_center(zone_id) + LOOT_CHEST_OFFSET
			chest.z_index = 2
			add_child(chest)

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

	if game_state_manager and not game_state_manager.state_changed.is_connected(_on_state_changed):
		game_state_manager.state_changed.connect(_on_state_changed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _is_dead:
		var can_toggle_pause := pause_menu != null \
			and (pause_menu.is_open or (game_state_manager and game_state_manager.is_active()))
		if can_toggle_pause:
			pause_menu.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tactical_pause") and _is_gameplay_active():
		# Only consumed while playing: with the pause menu/overlays up, Space
		# stays ui_accept for their buttons.
		_tactical_paused = not _tactical_paused
		_apply_time_scale()
		get_viewport().set_input_as_handled()
	elif _is_gameplay_active() and _handle_selection_key(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hero_cycle") and _is_gameplay_active():
		# Consumed so Tab never also moves GUI focus (ui_focus_next).
		var player_stats := ManagerLocator.get_player_stats()
		if player_stats:
			player_stats.cycle_active_hero()
		get_viewport().set_input_as_handled()

## Left click on a hero selects it (Ctrl adds/removes). Consumed on purpose so the
## RoomZone under the hero doesn't also read it as a move order; a click anywhere
## else stays a move order. Not while a module is armed (its slots need the click).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _is_gameplay_active():
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.building_menu and hud.building_menu.is_armed():
		return
	var hero := pick_hero_at(get_canvas_transform().affine_inverse() * event.position)
	if hero == null:
		return
	click_hero(hero, event.ctrl_pressed)
	get_viewport().set_input_as_handled()


## Living hero whose drawn body contains `world_pos` (the closest one), or null.
func pick_hero_at(world_pos: Vector2) -> Player:
	var best: Player = null
	var best_dist := INF
	for hero in heroes:
		if not hero.can_accept_input():
			continue
		var dist := world_pos.distance_to(hero.to_global(hero.animated_sprite.body_center()))
		if dist <= hero.animated_sprite.fit_radius() + HERO_PICK_MARGIN and dist < best_dist:
			best = hero
			best_dist = dist
	return best


func click_hero(hero: Player, additive: bool) -> void:
	var selection := ManagerLocator.get_selection_manager()
	if selection == null:
		return
	if additive:
		selection.toggle(hero.stats.hero_id)
	else:
		selection.select_only(hero.stats.hero_id)


## F1/F2 select hero 1/2 (Ctrl adds/removes), Ctrl+1..3 assigns the current
## selection to a control group, 1..3 recalls it (a second tap within
## GROUP_DOUBLE_TAP_MS also centers the camera on it). true = key consumed.
func _handle_selection_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var selection := ManagerLocator.get_selection_manager()
	if selection == null:
		return false
	for i in mini(heroes.size(), 2):
		if event.is_action_pressed("select_hero_%d" % (i + 1)):
			click_hero(heroes[i], event.ctrl_pressed)
			return true
	for n in range(1, selection.GROUP_COUNT + 1):
		if event.is_action_pressed("group_assign_%d" % n, false, true):
			selection.assign_group(n)
			return true
		if event.is_action_pressed("group_select_%d" % n, false, true):
			if selection.select_group(n):
				var now := Time.get_ticks_msec()
				if n == _last_group_key and now - _last_group_msec <= GROUP_DOUBLE_TAP_MS:
					_center_camera_on_selection()
				_last_group_key = n
				_last_group_msec = now
			return true
	return false


func _center_camera_on_selection() -> void:
	var selection := ManagerLocator.get_selection_manager()
	var sum := Vector2.ZERO
	var count := 0
	for hero in heroes:
		if selection.is_selected(hero.stats.hero_id):
			sum += hero.global_position
			count += 1
	if count > 0:
		camera.focus_on(sum / count)


func _exit_tree() -> void:
	Engine.time_scale = 1.0

func is_tactically_paused() -> bool:
	return _tactical_paused

func _is_gameplay_active() -> bool:
	return not _is_dead and (game_state_manager == null or game_state_manager.is_active())

func _on_state_changed(_new_state: int, _old_state: int) -> void:
	_apply_time_scale()

## Esc pause/death/victory run at 1 (their overlays tween); back to ACTIVE
## restores the tactical pause.
func _apply_time_scale() -> void:
	var frozen := _tactical_paused and _is_gameplay_active()
	Engine.time_scale = 0.0 if frozen else 1.0
	get_tree().call_group("hud", "set_pause_label", frozen)

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
		death_handler.show_death_screen()

func _on_victory() -> void:
	if pause_menu:
		pause_menu.close()

	if victory_handler:
		victory_handler.show_victory_screen()

## Fires before victory_entered (ExtractionManager emits victory_declared
## before requesting the VICTORY state), so the overlay is ready when shown.
func _on_floor_completed(completed_floor: int) -> void:
	var has_next := not floor_manager.is_final_floor()
	if next_floor_button:
		next_floor_button.visible = has_next
		next_floor_button.text = "Descender al piso %d" % (completed_floor + 1)
	if victory_label and has_next:
		victory_label.text = "¡Piso %d superado!" % completed_floor

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

extends Node
class_name Main

## Main: root scene orchestrator. Owns WorldContainer (Main2d.tscn),
## UIContainer (MainMenu/WaitingRoom.tscn), HUDContainer (HUD.tscn) and a
## TransitionOverlay fade. Replaces ad-hoc get_tree().change_scene_to_file()
## calls so gameplay/menu subscenes can be swapped without reloading the
## whole tree (autoloads, main_orchestrator group lookup, etc. stay alive).

const MAIN_MENU_SCENE := preload("res://scenes/menus/MainMenu.tscn")
const WAITING_ROOM_SCENE := preload("res://scenes/menus/WaitingRoom.tscn")
const MAIN2D_SCENE := preload("res://scenes/Main2d.tscn")
const HUD_SCENE := preload("res://scenes/hud/HUD.tscn")

const FADE_DURATION := 0.25
## progresion-10: "Piso N — Name" card held on the black screen between floors.
const FLOOR_CARD_SEC := 0.9

@onready var world_container: Node2D = $WorldContainer
@onready var ui_container: CanvasLayer = $UIContainer
@onready var hud_container: Node = $HUDContainer
@onready var transition_rect: ColorRect = $TransitionOverlay/ColorRect

var _is_transitioning: bool = false
## Run-scoped floor counter (1-based). Lives here, not in Main2d, because
## Main2d is freed/re-instantiated between floors. Read by Main2d → FloorManager.
var current_floor: int = 1
## Picked per run in _begin_new_run(); FloorManager derives each floor's map
## seed from it, so floors differ within a run and Retry gives a new dungeon.
var run_seed: int = 0
## intro-tutorial-17: the premise screen before floor 1 (once per install, see
## _play_intro_if_due). Off under --script so no test waits on it; tests turn it on.
var play_intro: bool = not OS.get_cmdline_args().has("--script")
## The IntroScreen on screen, if any (tests skip it).
var intro_screen: IntroScreen
## guardado-19: a saved run continue_run() hands to start_gameplay (restored
## right after _begin_new_run).
var _pending_run: Dictionary = {}


func _ready() -> void:
	add_to_group("main_orchestrator")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_content_scaling()
	show_main_menu()


func _setup_content_scaling() -> void:
	var root_window: Window = get_tree().root
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


# ─────────────────────────────────────────────
# PUBLIC ORCHESTRATION API
# ─────────────────────────────────────────────
func show_main_menu() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	await _fade_to_black()
	await _clear_containers(true, true, true)
	_play_menu_music()
	_current_ui_add(MAIN_MENU_SCENE.instantiate())
	await _fade_from_black()

	_is_transitioning = false


func return_to_main_menu() -> void:
	if _is_transitioning:
		return
	ManagerLocator.flush_saves()
	get_tree().paused = false
	Engine.time_scale = 1.0  # tactical pause must not leak into the fade/next floor
	var net := Net.session()
	if net:
		net.leave("menu")  # coop-12: never keep a lobby/peer open behind the menu
	await show_main_menu()


## `floor_index` > 1 only when a co-op client (re)joins a run in progress.
## coop-12: a network start can arrive mid-transition (menu fade): it waits for it.
## intro-tutorial-17: `tutorial` = the menu's Tutorial (GameSession.tutorial).
func start_gameplay(floor_index: int = 1, tutorial: bool = false) -> void:
	await _wait_transition()
	_is_transitioning = true

	await _fade_to_black()
	await _clear_containers(true, true, true)
	var session := ManagerLocator.get_game_session()
	if session:
		session.tutorial = tutorial
	_begin_new_run()
	current_floor = floor_index
	if not _pending_run.is_empty():
		_restore_run(_pending_run)
		_pending_run = {}
	elif not tutorial and not Net.is_online():
		_clear_saved_run()  # guardado-19: a new offline run replaces the saved one
	if floor_index == 1 and not Net.is_online():
		await _play_intro_if_due()
	await _show_floor_card()
	_current_world_add(MAIN2D_SCENE.instantiate())
	_current_hud_add(HUD_SCENE.instantiate())
	await _fade_from_black()

	_is_transitioning = false


## guardado-19: the slot's saved run, from the start of its floor. false = none.
func continue_run() -> bool:
	var save_mgr := ManagerLocator.get_save_manager()
	var run: Dictionary = save_mgr.get_saved_run() if save_mgr else {}
	if run.is_empty():
		return false
	_pending_run = run
	await start_gameplay(int(run["floor"]))
	return true


## The menu's Tutorial: fixed heroes (Tutorial.HEROES), fixed map, no slot needed.
func start_tutorial() -> void:
	var session := ManagerLocator.get_game_session()
	if session:
		session.set_selection(Tutorial.HEROES)
	await start_gameplay(1, true)


func _play_menu_music() -> void:
	var audio := ManagerLocator.get_audio()
	if audio:
		audio.play_music(audio.MUSIC_MENU)


## Premise screen over the black transition, once per install: same switch and file
## as the first-time help (SettingsManager id "intro", which under --script never
## reaches the disk). Offline only: online nobody waits for one player reading.
func _play_intro_if_due() -> void:
	var settings := ManagerLocator.get_settings_manager()
	if not play_intro or settings == null or not settings.should_show_help(IntroScreen.HELP_ID):
		return
	settings.mark_help_seen(IntroScreen.HELP_ID)
	_play_menu_music()  # audio-18: the intro keeps the menu theme (Retry comes from a floor)
	intro_screen = IntroScreen.new()
	intro_screen.name = "IntroScreen"
	transition_rect.get_parent().add_child(intro_screen)
	await intro_screen.finished
	intro_screen.queue_free()
	intro_screen = null


func _wait_transition() -> void:
	while _is_transitioning:
		await get_tree().process_frame


func go_to_waiting_room() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	await _fade_to_black()
	await _clear_containers(true, true, true)
	_current_ui_add(WAITING_ROOM_SCENE.instantiate())
	await _fade_from_black()

	_is_transitioning = false


## Retry after death: restarts the run from floor 1.
func reload_gameplay() -> void:
	await _reload_world(true)


## Floor cleared: same run, next floor. Resources carry over.
func advance_floor() -> void:
	await _wait_transition()
	current_floor += 1
	await _reload_world(false)


func _reload_world(new_run: bool) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	ManagerLocator.flush_saves()
	get_tree().paused = false
	Engine.time_scale = 1.0  # tactical pause must not leak into the fade/next floor

	await _fade_to_black()
	await _clear_containers(true, false, true)
	if new_run:
		_begin_new_run()
	else:
		_save_run()  # guardado-19: after the old floor is gone (it runs during the fade: a last kill counts)
	await _show_floor_card()
	_current_world_add(MAIN2D_SCENE.instantiate())
	_current_hud_add(HUD_SCENE.instantiate())
	await _fade_from_black()

	_is_transitioning = false


## ResourceManager is an autoload, so without this a run inherits the
## previous run's resources (and the very first run starts at 0 embers).
func _begin_new_run() -> void:
	current_floor = 1
	# coop-12: every peer plays the host's seed (same maps: generation is deterministic).
	run_seed = Net.session().run_seed if Net.is_online() else randi()
	FloorManager.reset_seen_types()
	var resource_manager := ManagerLocator.get_resource_manager()
	if resource_manager:
		var mult := FloorManager.resolve_difficulty().start_resource_mult  # progresion-10
		resource_manager.reset_resources(roundi(15 * mult), roundi(15 * mult), roundi(10 * mult), roundi(20 * mult))
		resource_manager.reset_research()
	var player_stats := ManagerLocator.get_player_stats()
	if player_stats:
		player_stats.reset_run_upgrades()
		player_stats.clear_found_items()
	var selection := ManagerLocator.get_selection_manager()
	if selection:
		selection.reset()
	var session := ManagerLocator.get_game_session()
	if session:
		session.reset_run()  # recruits and lost heroes (heroes-9); the pick stays


# ─────────────────────────────────────────────
# RUN SAVE (guardado-19)
# ─────────────────────────────────────────────
## What a floor needs to start again exactly as it did: the map comes back from
## run_seed (generation is deterministic), HP is full at every floor start.
## Called between floors, so nothing of the old Main2d is read.
func capture_run() -> Dictionary:
	var session := ManagerLocator.get_game_session()
	var seen: Array = FloorManager._seen_types.keys()
	seen.sort()
	return {
		"floor": current_floor,
		"run_seed": run_seed,
		"difficulty": session.difficulty,
		"heroes": session.selected_hero_ids.duplicate(),
		"recruited": session.recruited_ids.duplicate(),
		"lost": session.lost_ids.duplicate(),
		"run_stats": session.run_stats.duplicate(),
		"stats": ManagerLocator.get_player_stats().get_run_state(),
		"inv": ManagerLocator.get_party_inventory().get_state(),
		"res": ManagerLocator.get_resource_manager().get_state(),
		"seen_types": seen,
	}


## Offline only, never the Tutorial, only with a picked slot (SaveManager checks).
func _save_run() -> void:
	var session := ManagerLocator.get_game_session()
	var save_mgr := ManagerLocator.get_save_manager()
	if Net.is_online() or save_mgr == null or session == null or session.tutorial:
		return
	save_mgr.save_run(capture_run())


func _clear_saved_run() -> void:
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.clear_run()


## Puts a capture_run() back, after _begin_new_run() reset everything.
func _restore_run(run: Dictionary) -> void:
	current_floor = int(run["floor"])
	run_seed = int(run["run_seed"])
	var session := ManagerLocator.get_game_session()
	session.tutorial = false
	session.difficulty = str(run.get("difficulty", session.difficulty))
	session.selected_hero_ids.assign(run.get("heroes", []))
	session.recruited_ids.assign(run.get("recruited", []))
	session.lost_ids.assign(run.get("lost", []))
	session.run_stats = (run.get("run_stats", session.new_run_stats()) as Dictionary).duplicate()
	for type in run.get("seen_types", []):
		FloorManager._seen_types[type] = true
	ManagerLocator.get_player_stats().apply_run_state(run.get("stats", {}))
	ManagerLocator.get_party_inventory().apply_state(run.get("inv", {}))
	ManagerLocator.get_resource_manager().apply_state(run.get("res", {}))
	QuestLogger.info(QuestLogger.Category.SAVE, "Run restored: floor %d, seed %d." % [current_floor, run_seed])


# ─────────────────────────────────────────────
# INTERNAL HELPERS
# ─────────────────────────────────────────────
func _current_world_add(node: Node) -> void:
	world_container.add_child(node)


func _current_ui_add(node: Node) -> void:
	ui_container.add_child(node)


func _current_hud_add(node: Node) -> void:
	hud_container.add_child(node)


## Floor title over the black transition screen (FloorTheme.display_name); the
## label is a child of the fading ColorRect, so it fades out with it.
func _show_floor_card() -> void:
	var label := transition_rect.get_node_or_null("FloorCard") as Label
	if label == null:
		label = Label.new()
		label.name = "FloorCard"
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", Accessibility.font(44))
		label.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT)
		transition_rect.add_child(label)
	var theme := FloorManager.DEFAULT_CONFIG.theme(current_floor)
	label.text = "Piso %d — %s" % [current_floor, theme.display_name] if theme else "Piso %d" % current_floor
	label.modulate.a = 0.0
	var tween := create_tween().set_ignore_time_scale()
	tween.tween_property(label, "modulate:a", 1.0, FLOOR_CARD_SEC * 0.3)
	tween.tween_interval(FLOOR_CARD_SEC * 0.7)
	await tween.finished


func _fade_to_black(duration: float = FADE_DURATION) -> void:
	var tw := MenuTransitionFX.play_entrance(self,
		[{"node": transition_rect, "max_alpha": 1.0}], [], duration,
		Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, Vector2.ONE)
	if tw:
		await tw.finished


func _fade_from_black(duration: float = FADE_DURATION) -> void:
	var tw := MenuTransitionFX.play_exit(self,
		[{"node": transition_rect, "max_alpha": 1.0}], [], duration, Vector2.ONE,
		Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	if tw:
		await tw.finished


func _clear_containers(clear_world: bool, clear_ui: bool, clear_hud: bool) -> void:
	if clear_world:
		for c in world_container.get_children():
			c.queue_free()
	if clear_ui:
		for c in ui_container.get_children():
			c.queue_free()
	if clear_hud:
		for c in hud_container.get_children():
			c.queue_free()
	if clear_world or clear_ui or clear_hud:
		await get_tree().process_frame

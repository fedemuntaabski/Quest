extends SceneTree

## primera-partida-16: one test per first-game help, over a live Main2d + HUD, plus
## the two small fixes on the same screens (BuildingMenu tabs, slot highlight).
##   godot --headless --path . --script res://tests/test_ayudas.gd

const HELP_FILE := "user://test_first_help.cfg"

var failures: Array[String] = []
var main2d: Node
var hud: HUDController
var settings: Node


func _initialize() -> void:
	await process_frame
	settings = root.get_node("SettingsManager")
	_test_seen_survives_only_when_persisting()
	settings.reset_help()
	var main_scene := load("res://scenes/Main2d.tscn") as PackedScene
	main2d = main_scene.instantiate()
	root.add_child(main2d)
	hud = (load("res://scenes/hud/HUD.tscn") as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	await process_frame

	_test_controls_help()
	_test_objective_steps()
	await _test_tabs_not_clipped()
	_test_tab_subtitles()
	_test_armed_slot_visible()
	await _test_click_on_slot_under_hero()
	_test_dark_room_help()
	_test_light_prompt()
	await _test_refusal_card()
	_test_help_survives_a_toast()
	_test_carrier_visible()
	_test_downed_help()
	_test_dropped_relic_marker()
	await _test_click_on_dropped_relic_is_not_a_revive()

	if failures.is_empty():
		print("test_ayudas: OK (14 ayudas/arreglos)")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)


## A suite run never touches the real file; a real game remembers across sessions.
func _test_seen_survives_only_when_persisting() -> void:
	_check(not settings.help_persist, "--script runs must not persist the seen help")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HELP_FILE))
	settings.help_path = HELP_FILE
	settings.mark_help_seen("x")
	settings.load_help()
	_check(settings.should_show_help("x"), "help_persist off wrote the seen help to disk")
	settings.help_persist = true
	settings.mark_help_seen("x")
	settings.load_help()
	_check(not settings.should_show_help("x"), "the seen help did not survive a reload")
	settings.reset_help()
	settings.load_help()
	_check(settings.should_show_help("x"), "reset_help did not bring the help back")
	settings.first_help_enabled = false
	_check(not settings.should_show_help("y"), "the Options switch does not silence help")
	settings.first_help_enabled = true
	settings.help_persist = false
	settings.help_path = settings.HELP_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HELP_FILE))


func _test_controls_help() -> void:
	_check(hud.help_card.shown_id == "controles", "floor start did not show the controls help")
	_check("Clic derecho" in hud.help_card.get_body_text(), "controls help does not explain right click")
	_check(not "%s" in hud.help_card.get_body_text(), "controls help did not get the current key")
	_check(hud.help_card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the help card must not take clicks")


func _test_objective_steps() -> void:
	var panel := hud.objective_panel
	_check(panel.get_parent().name == "TopLeft", "objective is not under the floor label")
	_check(panel.current_step() == 0, "floor start is not step 0")
	_check(panel.get_lines()[0].begins_with(ObjectivePanel.STEP_NOW), "step 0 not marked as current")
	for door: Door in main2d.doors_root.get_children():
		_open(door)
	_check(panel.current_step() == 1, "exit discovered is not step 1")
	_check(panel.get_lines()[0].begins_with(ObjectivePanel.STEP_DONE), "step 0 not marked done")


func _test_tabs_not_clipped() -> void:
	var menu := hud.building_menu
	menu.open_category(menu.RESEARCH_TAB)
	await process_frame
	await process_frame
	_check(not menu.tabs.get_offset_buttons_visible(), "Investigación tab cuts the tab bar")
	_check(menu.tabs.get_tab_rect(0).position.x >= 0.0, "Mayores scrolled out of the tab bar")
	menu.close_menu()


func _test_tab_subtitles() -> void:
	var menu := hud.building_menu
	menu.open_category(0)
	_check("talleres" in menu.title.text, "Mayores has no subtitle: " + menu.title.text)
	menu.open_category(1)
	_check("defensas" in menu.title.text, "Menores has no subtitle: " + menu.title.text)
	menu.close_menu()


func _test_armed_slot_visible() -> void:
	var menu := hud.building_menu
	menu.open_category(0)
	(menu.options.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	var armed: BuildingSlot = menu._armed_slots[0]
	_check(armed.scale.x > 1.5, "armed slot is not bigger")
	_check(armed.z_index > main2d.heroes[0].z_index, "armed slot stays under the heroes")
	menu.close_menu()
	_check(armed.scale == Vector2.ONE and armed.z_index == 2, "slot did not go back to normal")


## Heroes spawn on the center slot: a real click through the viewport must build there.
func _test_click_on_slot_under_hero() -> void:
	var menu := hud.building_menu
	root.get_node("ResourceManager").add_resource("iron", 50)
	menu.open_category(0)
	(menu.options.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	var slot: BuildingSlot = menu._armed_slots[0]
	var world_pos := slot.global_position
	var hero: Player = main2d.heroes[0]
	var hero_start := hero.global_position
	hero.global_position = world_pos - hero.animated_sprite.body_center()
	_check(main2d.hero_input.pick_hero_at(world_pos) != null, "setup: a hero should stand on the slot")
	# juego-22: the camera follows the moved hero with smoothing; a screen point taken
	# before it settles lands elsewhere (the 2-in-8 flake of juego-21).
	var last := Transform2D()
	for _i in 180:
		await process_frame
		if root.get_canvas_transform().is_equal_approx(last):
			break
		last = root.get_canvas_transform()
	var screen_pos: Vector2 = root.get_canvas_transform() * world_pos
	var motion := InputEventMouseMotion.new()
	motion.position = screen_pos
	motion.global_position = screen_pos
	root.push_input(motion, true)
	await physics_frame
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_pos
	press.global_position = screen_pos
	root.push_input(press, true)
	await physics_frame
	await process_frame
	await process_frame
	_check(not slot.is_empty(), "a click on a slot under a hero did not build")
	_check(not menu.is_armed(), "the menu stayed armed after building")
	hero.global_position = hero_start
	menu.close_menu()


func _test_dark_room_help() -> void:
	_check(hud.help_card.queued().has("sala_oscura") or hud.help_card.shown_id == "sala_oscura", "discovering a dark room did not queue its help")
	_check(not settings.should_show_help("sala_oscura"), "dark room help not marked as seen")


func _test_light_prompt() -> void:
	var rooms: RoomManager = main2d.room_manager
	var hint: LightHint = rooms.get_dark_rooms()[0].find_children("*", "LightHint", true, false)[0]
	var label := hint.get_node("Label") as Label
	_check("\n" in label.text and "Brasas" in label.text, "prompt is not on two lines: " + label.text)
	_check(label.material != null, "prompt goes dark with the room")


func _test_refusal_card() -> void:
	var relic: Relic = main2d.relic
	# Step 1: the hero is in the start room; go elsewhere to get the refusal.
	var hero: Player = main2d.heroes[0]
	var start := hero.current_zone_id
	hero.current_zone_id = main2d.room_manager.get_exit_zone_id()
	main2d.heroes[1].current_zone_id = hero.current_zone_id
	main2d.relic_controller._on_relic_clicked(relic)
	_check(hud._hint_panel.visible and "Acercate" in hud._hint_body.text, "Relic refusal is not on the card")
	var door := Door.new()
	door.door_id = "nope"
	await root.get_node("NetCommands").request("open_door", {"door": "nope", "heroes": [hero.stats.hero_id]})
	_check(hud._hint_title.text == "No se puede", "a refused command is not on the card")
	door.free()
	hero.current_zone_id = start
	main2d.heroes[1].current_zone_id = start


func _test_help_survives_a_toast() -> void:
	var shown := hud.help_card.shown_id
	hud.show_local_hint("Aviso", "Se está leyendo", QuestPalette.GOLD)
	hud._on_bestiary_unlocked("skeleton", BestiaryEntry.Tier.SEEN)
	_check(hud._hint_body.text == "Se está leyendo", "a bestiary toast replaced a notice")
	_check(hud.help_card.shown_id == shown, "a toast touched the help card")


func _test_carrier_visible() -> void:
	var hero: Player = main2d.heroes[0]
	main2d.relic_controller.confirm_pickup(hero)
	_check(hero.is_carrying_relic and hero.is_carry_icon_visible(), "no Relic icon over the carrier")
	var portrait: HeroPortrait = hud._portraits[hero.stats.hero_id]
	_check(portrait.relic_icon.visible and portrait.relic_icon.texture != null, "no Relic icon on the carrier's portrait")
	_check(hud._hint_title.text == "¡Reliquia recogida!" and hero.character_data.display_name in hud._hint_body.text, "pickup does not say who carries it")
	_check(hud.objective_panel.current_step() == 2, "pickup did not move the objective")


func _test_downed_help() -> void:
	var hero: Player = main2d.heroes[0]
	hero.stats.take_damage(100000)
	_check(hud.help_card.queued().has("heroe_caido") or hud.help_card.shown_id == "heroe_caido", "first fall did not queue its help")
	var text: String = HelpCard.HELP["heroe_caido"][1]
	_check("Comida" in text and "aliado" in text and "se pierde" in text, "fall help is missing a rule")


func _test_dropped_relic_marker() -> void:
	var hero: Player = main2d.heroes[0]
	var relic: Relic = main2d.relic
	var portrait: HeroPortrait = hud._portraits[hero.stats.hero_id]
	_check(relic.is_dropped() and relic.is_drop_marker_visible(), "dropped Relic has no marker")
	_check(not hero.is_carry_icon_visible() and not portrait.relic_icon.visible, "the fallen hero still shows the Relic")
	_check(hud.minimap.relic_drop_zone() == relic.drop_zone_id, "minimap does not mark the dropped Relic")
	_check(hud._hint_title.text == "¡Reliquia caída!", "the drop has no notice")
	_check("Recuperá" in hud.objective_panel.get_lines()[2], "objective ignores the dropped Relic")


## The Relic lies on the body: without the guard this click paid a revive.
func _test_click_on_dropped_relic_is_not_a_revive() -> void:
	var relic: Relic = main2d.relic
	var controller: HeroInputController = main2d.hero_input
	var body: Player = main2d.heroes[0]
	var click := relic.global_position.move_toward(body.to_global(body.animated_sprite.body_center()), 16.0)
	_check(controller.pick_hero_at(click, true) == body, "setup: this click should land on the body too")
	_check(controller.is_on_dropped_relic(click), "the click over the dropped Relic is taken as a revive")
	var other: Player = main2d.heroes[1]
	other.current_zone_id = relic.drop_zone_id
	main2d.relic_controller.confirm_pickup(other)
	await process_frame
	_check(not relic.is_drop_marker_visible() and hud.minimap.relic_drop_zone() == "", "marker stayed after the pickup")
	_check(other.is_carry_icon_visible(), "the new carrier has no icon")


func _open(door: Door) -> void:
	if door.is_open or door.is_secret:
		return
	if main2d.door_turn_system.open_room(door.target_room_id):
		door.disable_door()

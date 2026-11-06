extends SceneTree

## intro-tutorial-17: the menu's Tutorial on the real Main orchestrator, one check
## per step, each driven by the same path a player's input takes (RoomZone click
## signals, the build menu, NetCommands, RelicController), never by time:
##   setup (fixed heroes, fixed map), 1 select, 2 open door, 3 right-click move,
##   4 middle-click light, 5 build, 6 find the exit, 7 take the Reliquia,
##   8 carry it out (victory screen -> menu only), + no records, no bestiary,
##   early events kept, first-time help not spent.
##   godot --headless --path . --script res://tests/test_tutorial.gd

const MAIN_PATH := "res://scenes/Main.tscn"
const SLOT := 93
const HUGE_HP := 100000

var failures: Array[String] = []
var _main: Main
var main2d: Node
var hud: HUDController
var tutorial: Tutorial
var rm: RoomManager


func _initialize() -> void:
	await process_frame
	_main = (load(MAIN_PATH) as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _frames(20)
	root.get_node("SaveManager").load_game(SLOT)  # a loaded slot: records/bestiary would write
	root.get_node("SettingsManager").reset_help()
	await _main.start_tutorial()
	await _frames(10)
	main2d = _main.world_container.get_child(0)
	hud = _main.hud_container.get_child(0) as HUDController
	tutorial = main2d.tutorial
	rm = main2d.room_manager

	_check_setup()
	_check_early_events_kept()
	await _step_select()
	await _step_open_door()
	await _step_move()
	await _step_light()
	await _step_build()
	await _step_find_exit()
	await _step_take_relic()
	await _step_carry()
	_check_nothing_recorded()

	paused = false
	Engine.time_scale = 1.0
	await _main.return_to_main_menu()
	await _frames(10)
	_main.queue_free()
	await _frames(5)
	root.get_node("SaveManager").delete_save(SLOT)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_tutorial: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _tough() -> void:
	for hero: Player in main2d.heroes:
		hero.stats.max_hp = HUGE_HP
		hero.stats.current_hp = HUGE_HP
	var relic := ManagerLocator.get_relic()
	if relic:
		relic.max_hp = HUGE_HP
		relic.current_hp = HUGE_HP


## Step `step` is current: the objective panel marks it and the help card shows it.
func _expect_step(step: int, label: String) -> void:
	_expect(tutorial.step == step, "%s: tutorial step is %d, expected %d" % [label, tutorial.step, step])
	var lines := hud.objective_panel.get_lines()
	var now := lines.filter(func(l: String) -> bool: return l.begins_with(ObjectivePanel.STEP_NOW))
	_expect(now.size() == 1 and Tutorial.STEPS[step][0] in now[0], "%s: objective panel shows %s" % [label, lines])
	_expect(hud.help_card.visible and hud.help_card.shown_id == "tutorial_%d" % step, "%s: help card is '%s'" % [label, hud.help_card.shown_id])


func _walk_done() -> void:
	for i in 600:
		if main2d.player_action_controller._busy.is_empty():
			return
		_tough()
		await process_frame


func _check_setup() -> void:
	_expect(tutorial != null and main2d.is_tutorial(), "start_tutorial did not build a Tutorial")
	_expect(main2d.map_layout == preload("res://resources/maps/fallback_layout.tres"), "the Tutorial does not play fallback_layout.tres")
	var ids: Array[String] = []
	for hero: Player in main2d.heroes:
		ids.append(hero.stats.hero_id)
	_expect(ids == Tutorial.HEROES, "the Tutorial party is %s, expected %s" % [ids, Tutorial.HEROES])
	_expect(_main.intro_screen == null, "the intro waited under --script (play_intro must be off)")
	_expect_step(Tutorial.Step.SELECT, "start")
	_expect(root.get_node("SettingsManager").should_show_help("controles"), "the Tutorial spent the first-time controls help")


## A lone Tutorial: an event ahead of its step waits and counts when the step comes.
func _check_early_events_kept() -> void:
	var t := Tutorial.new()
	t.hit(Tutorial.Step.OPEN_DOOR)
	_expect(t.step == Tutorial.Step.SELECT, "an early event skipped the current step")
	t.hit(Tutorial.Step.SELECT)
	_expect(t.step == Tutorial.Step.MOVE, "an early event was not kept (step %d)" % t.step)
	t.free()


func _step_select() -> void:
	root.get_node("SelectionManager").select_only("mage")
	await process_frame
	_expect_step(Tutorial.Step.OPEN_DOOR, "after selecting the mage")
	root.get_node("SelectionManager").set_selection(Tutorial.HEROES)


func _step_open_door() -> void:
	var door: Door = null
	for d in rm.get_all_doors():
		if d.from_zone_id == rm.get_start_zone_id():
			door = d
	door.door_clicked.emit(door)
	await _frames(2)
	await _walk_done()
	_expect(door.is_open, "the start room's door did not open")
	_expect_step(Tutorial.Step.MOVE, "after opening the door")


func _step_move() -> void:
	var start := rm.get_start_zone_id()
	rm.get_zone_node(main2d.heroes[0].current_zone_id).clicked.emit(rm.get_zone_node(main2d.heroes[0].current_zone_id))
	await process_frame
	_expect(tutorial.step == Tutorial.Step.MOVE, "a click on the heroes' own zone counted as a move")
	var zone := rm.get_zone_node(start)
	zone.clicked.emit(zone)
	await _frames(2)
	await _walk_done()
	_expect(main2d.heroes[0].current_zone_id == start, "the right-click order did not walk back")
	_expect_step(Tutorial.Step.LIGHT, "after the right-click move")


func _step_light() -> void:
	var hub := ""
	for zone_id in rm.get_group_zone_ids("hub_room"):
		if rm.get_zone_kind(zone_id) == "room":
			hub = zone_id
	rm.get_zone_node(hub).toggle_light()
	await process_frame
	_expect(rm.is_zone_lit(hub), "the new room did not light (embers %d)" % root.get_node("ResourceManager").get_resource("embers"))
	_expect_step(Tutorial.Step.BUILD, "after lighting")


func _step_build() -> void:
	var menu := hud.building_menu
	menu.open_category(0)
	(menu.options.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	_expect(not menu._armed_slots.is_empty(), "no free slot in the lit room")
	if not menu._armed_slots.is_empty():
		menu.open_menu(menu._armed_slots[0])
	await process_frame
	menu.close_menu()
	_expect_step(Tutorial.Step.FIND_EXIT, "after building")


func _step_find_exit() -> void:
	var opened := true
	while opened:
		opened = false
		for door in rm.get_all_doors():
			if door.is_open or not rm.is_zone_revealed(door.from_zone_id):
				continue
			main2d.door_turn_system.open_room(door.target_room_id)
			door.disable_door()
			opened = true
			await process_frame
			_tough()
	_expect(rm.is_zone_revealed(rm.get_exit_zone_id()), "the exit is not revealed")
	_expect_step(Tutorial.Step.TAKE_RELIC, "after finding the exit")


func _step_take_relic() -> void:
	var hero: Player = main2d.heroes[0]
	hero.set_zone(rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()), main2d.floor_layer)
	main2d.relic_controller.confirm_pickup(hero)
	await process_frame
	_expect(hero.is_carrying_relic, "the hero did not take the Reliquia")
	_expect_step(Tutorial.Step.CARRY, "after taking the Reliquia")


func _step_carry() -> void:
	var hero: Player = main2d.heroes[0]
	_tough()
	Engine.time_scale = 4.0
	await main2d.player_action_controller.move_heroes([hero] as Array[Player], rm.get_exit_zone_id())
	Engine.time_scale = 1.0
	await _frames(20)
	_expect(tutorial.is_done(), "carrying the Reliquia out did not end the Tutorial (step %d)" % tutorial.step)
	var overlay: VictoryOverlay = main2d.victory_overlay
	_expect(overlay.visible, "no end screen after the Tutorial")
	_expect(overlay._title.text == "¡Tutorial completado!", "end title: " + overlay._title.text)
	_expect(not overlay._next_floor_button.visible and not overlay._new_run_button.visible, "the Tutorial offers a next floor / new run")
	_expect(overlay._return_button.visible, "the Tutorial end has no way back to the menu")


func _check_nothing_recorded() -> void:
	var bestiary := root.get_node("BestiaryService")
	var before: int = bestiary.entries.size()
	var any: EnemyType = bestiary.get_all_ordered()[0]
	bestiary.register_seen(any, 1)
	bestiary.register_kill(any, 1)
	_expect(bestiary.entries.size() == before and bestiary.unlocked_count() == 0, "the Tutorial wrote the bestiary")
	var result: Dictionary = main2d.finish_run(true)
	_expect((result["new_records"] as Array).is_empty(), "the Tutorial set records")
	var save := root.get_node("SaveManager")
	_expect((save.get_records("normal") as Dictionary).is_empty(), "the Tutorial counted a run: %s" % save.get_records("normal"))

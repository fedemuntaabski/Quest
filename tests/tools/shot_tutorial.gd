extends SceneTree

## Visual check of the intro and of every Tutorial step (needs a real window, NOT
## --headless), through the real Main orchestrator: main menu with TUTORIAL, the
## premise (fading in, then read), then one shot per step, each reached the way
## test_tutorial does it. Saves <out_dir>/tut_*.png.
##   godot --path . --resolution 1920x1080 --script res://tests/tools/shot_tutorial.gd -- <out_dir>

var _dir: String
var _main: Main


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "user://"
	await process_frame
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _wait(3.0)
	await _shot("0_menu")

	root.get_node("SettingsManager").reset_help()
	_main.play_intro = true
	_main.start_tutorial()
	while _main.intro_screen == null:
		await process_frame
	await _wait(1.5)
	await _shot("1_intro_fading")
	await _wait(6.0)
	await _shot("2_intro_read")
	_main.intro_screen.skip()
	while _main.world_container.get_child_count() == 0:
		await process_frame
	await _wait(1.5)

	var main2d := _main.world_container.get_child(0)
	var hud := _main.hud_container.get_child(0) as HUDController
	var rm: RoomManager = main2d.room_manager
	await _shot("3_step_select")

	root.get_node("SelectionManager").select_only("mage")
	await _wait(0.5)
	await _shot("4_step_open_door")
	root.get_node("SelectionManager").set_selection(Tutorial.HEROES)

	for door in rm.get_all_doors():
		if door.from_zone_id == rm.get_start_zone_id():
			door.door_clicked.emit(door)
	await _wait(3.0)
	await _shot("5_step_move")

	var start := rm.get_zone_node(rm.get_start_zone_id())
	start.clicked.emit(start)
	await _wait(3.0)
	await _shot("6_step_light")

	for zone_id in rm.get_group_zone_ids("hub_room"):
		if rm.get_zone_kind(zone_id) == "room":
			rm.get_zone_node(zone_id).toggle_light()
	await _wait(1.0)
	await _shot("7_step_build")

	hud.building_menu.open_category(0)
	(hud.building_menu.options.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	await _wait(0.5)
	await _shot("7b_build_armed")
	hud.building_menu.open_menu(hud.building_menu._armed_slots[0])
	hud.building_menu.close_menu()
	await _wait(0.8)
	await _shot("8_step_find_exit")

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
	await _wait(1.0)
	await _shot("9_step_take_relic")

	var hero: Player = main2d.heroes[0]
	hero.set_zone(rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()), main2d.floor_layer)
	main2d.relic_controller.confirm_pickup(hero)
	await _wait(1.0)
	await _shot("10_step_carry")

	for h: Player in main2d.heroes:
		h.stats.max_hp = 100000
		h.stats.current_hp = 100000
	await main2d.player_action_controller.move_heroes([hero] as Array[Player], rm.get_exit_zone_id())
	await _wait(1.5)
	await _shot("11_done")

	paused = false
	Engine.time_scale = 1.0
	quit(0)


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/tut_%s.png" % [_dir, shot_name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

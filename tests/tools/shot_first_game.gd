extends SceneTree

## Visual check of every first-game moment (needs a real window, NOT --headless),
## through the real Main orchestrator: hero select, floor start, dark room with its
## light prompt, building armed, blocked and confirmed Relic pickup, carrying it,
## and a downed hero. Saves <out_dir>/first_*.png.
##   godot --path . --resolution 1920x1080 --script res://tests/tools/shot_first_game.gd -- <out_dir>

const SLOT := 92

var _dir: String
var _main: Main


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "user://"
	await process_frame
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _wait(3.0)
	var select := HeroSelectMenu.new()
	select.set_anchors_preset(Control.PRESET_FULL_RECT)
	var over_menu := CanvasLayer.new()
	over_menu.layer = 150
	root.add_child(over_menu)
	over_menu.add_child(select)
	select.open()
	await _wait(0.8)
	await _shot("1_premise")
	over_menu.queue_free()
	await _wait(0.2)

	root.get_node("SaveManager").load_game(SLOT)
	root.get_node("GameSession").set_selection(["warrior", "mage"] as Array[String])
	await _main.start_gameplay()
	await _wait(1.5)
	await _shot("2_floor_start")

	var world := _world()
	var hud: HUDController = ManagerLocator.get_hud()
	var rm: RoomManager = world.room_manager

	# Blocked Relic click: the exit isn't discovered yet.
	world.relic_controller._on_relic_clicked(world.relic)
	await _wait(0.3)
	await _shot("3_relic_blocked")

	# Open the first door: a dark room next to the party.
	_open_next_door(world)
	await _wait(0.6)
	var dark_center: Vector2 = rm.get_center(rm.get_dark_rooms()[0].zone_id)
	world.camera.focus_on(dark_center)
	await _wait(0.6)
	await _shot("4_dark_room")
	hud.help_card._show_next()  # the controls card would stay up for 14 s
	await _wait(0.2)
	await _shot("4b_dark_room_help")

	hud.building_menu.open_category(0)
	await _wait(0.3)
	await _shot("5_build_tab")
	var buttons := hud.building_menu.options.find_children("*", "Button", true, false)
	(buttons[0] as Button).pressed.emit()
	world.camera.focus_on(rm.get_center(rm.get_start_zone_id()))
	await _wait(0.6)
	await _shot("6_build_armed")
	hud.building_menu.close_menu()
	hud.building_menu.open_category(hud.building_menu.RESEARCH_TAB)
	await _wait(0.3)
	await _shot("7_research_tab")
	hud.building_menu.close_menu()

	# Everything discovered: the Relic can be taken.
	for i in 40:
		if not _open_next_door(world):
			break
	world.camera.focus_on(rm.get_center(rm.get_start_zone_id()))
	await _wait(0.8)
	world.relic_controller._on_relic_clicked(world.relic)
	await _wait(0.4)
	await _shot("8_relic_dialog")
	world.relic_controller.dialog.hide()
	world.relic_controller.confirm_pickup(world.heroes[0])
	await _wait(1.0)
	await _shot("9_carrying")

	world.heroes[0].stats.take_damage(100000)
	await _wait(0.8)
	await _shot("10_carrier_down")
	hud.help_card._show_next()
	await _wait(0.2)
	await _shot("10b_downed_help")

	root.get_node("SaveManager").delete_save(SLOT)
	quit()


## Opens the next closed door whose side is revealed; false when none is left.
func _open_next_door(world: Node) -> bool:
	var rm: RoomManager = world.room_manager
	for door: Door in world.doors_root.get_children():
		if door.is_open or door.is_secret:
			continue
		var group := door.target_room_id
		if rm.is_group_revealed(group) or not rm.is_zone_revealed(door.from_zone_id):
			continue
		door.disable_door()
		world.door_turn_system.open_room(group)
		return true
	return false


func _world() -> Node:
	return _main.world_container.get_child(_main.world_container.get_child_count() - 1)


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/first_%s.png" % [_dir, shot_name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

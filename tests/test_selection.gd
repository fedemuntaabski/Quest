extends SceneTree

## Session 14: multi-hero selection + control groups over a live Main2d + HUD
## (fallback map, default party warrior + mage). Click / Ctrl+click on the hero,
## portraits (click, Ctrl+click, group label), F1/F2 (+Ctrl), Ctrl+N / N groups
## (double tap centers the camera, build-menu digits win while it is open),
## orders acting on the whole selection (zone + door), the death of a hero,
## groups across floors / new run, and the single-hero party.
##   godot --headless --path . --script res://tests/test_selection.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/HUD.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/managers/Main.gd"
## Longest glide the tests wait for (seconds of real time).
const MOVE_TIMEOUT := 8.0

var failures: Array[String] = []
var sel: Node
var ps: Node


func _initialize() -> void:
	sel = root.get_node("SelectionManager")
	ps = root.get_node("PlayerStats")
	root.get_node("ResourceManager").reset_resources(15, 15, 10, 20)
	ps.reset_run_upgrades()
	sel.reset()

	var world: Array = await _boot()
	var main2d: Node = world[0]
	var hud: HUDController = world[1]
	if main2d.heroes.size() == 2:
		_check_initial(main2d)
		_check_mouse(main2d)
		_check_portraits(main2d, hud)
		_check_keys(main2d)
		await _check_groups_and_camera(main2d, hud)
		await _check_orders(main2d)
		_check_death(main2d, hud)
	else:
		failures.append("expected 2 heroes, got %d" % main2d.heroes.size())
	await _free_world(world)

	await _check_door_order()
	await _check_floors_and_new_run()
	await _check_single_hero()

	sel.reset()
	ps.reset_run_upgrades()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_selection: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _ids(list: Array) -> Array[String]:
	var out: Array[String] = []
	for id in list:
		out.append(id)
	return out


func _boot(party_size: int = 2) -> Array:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.party_config = main2d.party_config.duplicate()
	main2d.party_config.party_size = party_size
	root.add_child(main2d)
	await process_frame
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	var camera: GameCamera = main2d.camera
	camera.config = camera.config.duplicate()
	camera.config.edge_scroll_enabled = false  # headless mouse sits in a corner
	return [main2d, hud]


func _free_world(world: Array) -> void:
	paused = false
	Engine.time_scale = 1.0
	for node: Node in world:
		node.queue_free()
	await process_frame
	await process_frame


func _portrait_of(hud: HUDController, hero: Player) -> HeroPortrait:
	for portrait: HeroPortrait in hud.portraits.get_children():
		if portrait.stats == hero.stats:
			return portrait
	return null


## Real key press through the viewport (HUD _input runs before Main2d's).
func _press(keycode: Key, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.ctrl_pressed = ctrl
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release)


func _selected() -> Array[String]:
	return sel.get_selected_ids()


func _click_hero(main2d: Node, hero: Player, ctrl: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.ctrl_pressed = ctrl
	event.position = main2d.get_canvas_transform() * hero.to_global(hero.animated_sprite.body_center())
	main2d._unhandled_input(event)


# ---------------- SIMPLE / CTRL SELECTION ----------------

func _check_initial(main2d: Node) -> void:
	_expect(_selected() == _ids(["warrior"]), "a new floor should start with the first hero selected: %s" % [_selected()])
	_expect(sel.get_primary_id() == "warrior" and ps.active_hero_id == "warrior", "primary / PlayerStats view")
	_expect(main2d.player_action_controller.player == main2d.heroes[0] and main2d.camera.get_target() == main2d.heroes[0], "controller/camera should start on the primary")


func _check_mouse(main2d: Node) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var far: Vector2 = a.global_position + Vector2(500, 500)
	_expect(main2d.pick_hero_at(a.to_global(a.animated_sprite.body_center())) == a, "pick_hero_at(a)")
	_expect(main2d.pick_hero_at(b.to_global(b.animated_sprite.body_center())) == b, "pick_hero_at(b)")
	_expect(main2d.pick_hero_at(far) == null, "pick_hero_at(empty ground) should be null")

	_click_hero(main2d, b)
	_expect(_selected() == _ids(["mage"]), "click on the second hero should replace the selection: %s" % [_selected()])
	_expect(main2d.player_action_controller.player == b and main2d.camera.get_target() == b, "controller/camera should follow the primary")
	_click_hero(main2d, b, true)
	_expect(_selected() == _ids(["mage"]), "Ctrl+click on the only selected hero must not empty the selection")
	_click_hero(main2d, a, true)
	_expect(_selected() == _ids(["mage", "warrior"]), "Ctrl+click should add: %s" % [_selected()])
	_expect(sel.get_primary_id() == "mage", "the first picked stays primary")
	_click_hero(main2d, b, true)
	_expect(_selected() == _ids(["warrior"]) and main2d.player_action_controller.player == a, "Ctrl+click should remove: %s" % [_selected()])
	_click_hero(main2d, a)
	_expect(_selected() == _ids(["warrior"]), "plain click keeps a sole selection")

	# A click on empty ground is not a hero click: selection stays (it is a move order).
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = main2d.get_canvas_transform() * far
	main2d._unhandled_input(event)
	_expect(_selected() == _ids(["warrior"]), "click on empty ground changed the selection")


# ---------------- PORTRAITS ----------------

func _check_portraits(main2d: Node, hud: HUDController) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var pa := _portrait_of(hud, a)
	var pb := _portrait_of(hud, b)
	_expect(pa.is_selected and not pb.is_selected, "portrait border should mirror the selection")

	pb.portrait_clicked.emit(pb)
	_expect(_selected() == _ids(["mage"]) and pb.is_selected and not pa.is_selected, "portrait click should select only that hero")
	pa.portrait_ctrl_clicked.emit(pa)
	_expect(_selected() == _ids(["mage", "warrior"]) and pa.is_selected and pb.is_selected, "portrait Ctrl+click should add (both borders lit)")
	# Real gui path with the Ctrl modifier.
	var ctrl_click := InputEventMouseButton.new()
	ctrl_click.button_index = MOUSE_BUTTON_LEFT
	ctrl_click.pressed = true
	ctrl_click.ctrl_pressed = true
	pb._on_gui_input(ctrl_click)
	_expect(_selected() == _ids(["warrior"]) and not pb.is_selected, "portrait Ctrl+click via gui_input should remove")
	_expect(not hud.character_popup.visible, "Ctrl+click must not open the sheet")


# ---------------- KEYS / GROUPS ----------------

func _check_keys(main2d: Node) -> void:
	_press(KEY_F2)
	_expect(_selected() == _ids(["mage"]), "F2 -> second hero: %s" % [_selected()])
	_press(KEY_F1)
	_expect(_selected() == _ids(["warrior"]), "F1 -> first hero: %s" % [_selected()])
	_press(KEY_F2, true)
	_expect(_selected() == _ids(["warrior", "mage"]), "Ctrl+F2 should add: %s" % [_selected()])
	_press(KEY_F1, true)
	_expect(_selected() == _ids(["mage"]), "Ctrl+F1 should remove: %s" % [_selected()])
	_press(KEY_F2, true)
	_expect(_selected() == _ids(["mage"]), "Ctrl+F2 on the last selected hero must be a no-op")
	_press(KEY_F1)


func _check_groups_and_camera(main2d: Node, hud: HUDController) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var pa := _portrait_of(hud, a)
	var pb := _portrait_of(hud, b)
	_expect(sel.get_group(1).is_empty() and pa._group_label.text == "", "groups should start empty")

	_press(KEY_F2, true)  # F1 was selected: now warrior + mage
	_press(KEY_1, true)
	_expect(sel.get_group(1) == _ids(["warrior", "mage"]), "Ctrl+1 should store the selection: %s" % [sel.get_group(1)])
	_expect(pa._group_label.text.contains("[1]") and pb._group_label.text.contains("[1]"), "portraits should show the group label")
	_press(KEY_F2)  # only mage
	_press(KEY_2, true)
	_expect(sel.get_group(2) == _ids(["mage"]) and pb._group_label.text.contains("[1]") and pb._group_label.text.contains("[2]"), "second group / labels: '%s'" % pb._group_label.text)
	_expect(not pa._group_label.text.contains("[2]"), "the warrior is not in group 2")

	main2d._last_group_msec = -10000
	_press(KEY_1)
	_expect(_selected() == _ids(["warrior", "mage"]), "1 should recall group 1: %s" % [_selected()])
	_press(KEY_2)
	_expect(_selected() == _ids(["mage"]), "2 should recall group 2: %s" % [_selected()])
	_press(KEY_3)
	_expect(_selected() == _ids(["mage"]), "an empty group must leave the selection alone")

	# Double tap centers the camera on the group; a single tap doesn't.
	var camera: GameCamera = main2d.camera
	main2d._last_group_msec = -10000
	camera.focus_on(camera.global_position + Vector2(300, 300))
	var panned := camera.global_position
	_press(KEY_1)
	await process_frame
	_expect(camera.global_position == panned and not camera.is_following(), "a single tap must not move the camera")
	_press(KEY_1)
	var centroid: Vector2 = (a.global_position + b.global_position) * 0.5
	_expect(camera.global_position.is_equal_approx(camera.clamp_to_bounds(centroid)), "double tap: camera %s, group centroid %s" % [camera.global_position, centroid])
	main2d._last_group_msec = -10000
	camera.recenter()

	# Build menu open: digits pick cards (menu wins), Ctrl+N still assigns.
	sel.select_only("warrior")
	root.get_node("ResourceManager").add_resource("industry", 100)
	hud.production_button.pressed.emit()
	_expect(hud.building_menu.visible, "production button should open the build menu")
	_press(KEY_1)
	_expect(_selected() == _ids(["warrior"]), "digit with the build menu open must not recall group 1: %s" % [_selected()])
	_expect(hud.building_menu.is_armed(), "digit with the build menu open should arm the first card")
	_press(KEY_3, true)
	_expect(sel.get_group(3) == _ids(["warrior"]), "Ctrl+3 should assign even with the build menu open")
	hud.building_menu.close_menu()
	sel.select_only("warrior")


# ---------------- ORDERS ----------------

func _check_orders(main2d: Node) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var room_manager: RoomManager = main2d.room_manager
	var controller: PlayerActionController = main2d.player_action_controller
	var start := room_manager.get_start_zone_id()
	var progress := true
	while progress:
		progress = false
		for door in room_manager.get_all_doors():
			if not door.is_open and room_manager.is_zone_revealed(door.from_zone_id):
				main2d.door_turn_system.open_room(door.target_room_id)
				door.disable_door()
				progress = true
	for enemy in main2d.get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	var rooms: Array[String] = []
	for zone_id in room_manager.get_zone_ids():
		if zone_id != start and room_manager.get_zone_kind(zone_id) == "room" and room_manager.is_zone_revealed(zone_id):
			rooms.append(zone_id)
	_expect(rooms.size() >= 2, "expected 2+ side rooms, got %d" % rooms.size())
	if rooms.size() < 2:
		return

	# One hero selected: only it moves.
	sel.select_only("warrior")
	await controller._on_zone_clicked(rooms[0])
	_expect(a.current_zone_id == rooms[0] and b.current_zone_id == start, "single order: a '%s', b '%s'" % [a.current_zone_id, b.current_zone_id])

	# Both selected, standing in different rooms: each walks from where it is.
	sel.set_selection(_ids(["warrior", "mage"]))
	controller._on_zone_clicked(rooms[1])
	_expect(controller._action_in_flight, "order did not start")
	var start_pos_b: Vector2 = b.global_position
	var deadline := Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(a.global_position != room_manager.get_center(rooms[0]) and b.global_position != start_pos_b, "both heroes should be walking at the same time")
	deadline = Time.get_ticks_msec() + int(MOVE_TIMEOUT * 1000)
	while controller._action_in_flight and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not controller._action_in_flight, "order never finished")
	_expect(a.current_zone_id == rooms[1] and b.current_zone_id == rooms[1], "group order: a '%s', b '%s'" % [a.current_zone_id, b.current_zone_id])
	_expect(a.animated_sprite.global_position.distance_to(b.animated_sprite.global_position) > 1.0, "heroes in one room should not be stacked (formation offset)")

	# Heroes already at the destination stay; the rest arrive.
	sel.select_only("mage")
	await controller._on_zone_clicked(start)
	sel.set_selection(_ids(["warrior", "mage"]))
	await controller._on_zone_clicked(start)
	_expect(a.current_zone_id == start and b.current_zone_id == start, "mixed order: a '%s', b '%s'" % [a.current_zone_id, b.current_zone_id])
	sel.select_only("warrior")


func _check_door_order() -> void:
	var world: Array = await _boot()
	var main2d: Node = world[0]
	sel.set_selection(_ids(["warrior", "mage"]))
	var room_manager: RoomManager = main2d.room_manager
	var start := room_manager.get_start_zone_id()
	var door: Door = null
	for candidate in room_manager.get_all_doors():
		if not candidate.is_open and candidate.from_zone_id == start:
			door = candidate
			break
	_expect(door != null, "no closed door next to the start room")
	if door:
		var turn_before: int = main2d.door_turn_system.current_turn
		await main2d.player_action_controller._on_door_clicked(door)
		_expect(main2d.door_turn_system.current_turn == turn_before + 1, "two selected heroes should open the door once (turn %d -> %d)" % [turn_before, main2d.door_turn_system.current_turn])
		var zones := room_manager.get_group_zone_ids(door.target_room_id)
		var final_zone: String = zones[-1]
		for hero: Player in main2d.heroes:
			_expect(hero.current_zone_id == final_zone, "'%s' should follow into '%s' (is in '%s')" % [hero.stats.hero_id, final_zone, hero.current_zone_id])
	await _free_world(world)


# ---------------- DEATH ----------------

func _check_death(main2d: Node, hud: HUDController) -> void:
	var b: Player = main2d.heroes[1]
	sel.set_selection(_ids(["warrior", "mage"]))
	sel.assign_group(1)
	b.stats.take_damage(b.stats.max_hp)
	_expect(not b.stats.is_alive(), "the mage should be dead")
	_expect(_selected() == _ids(["warrior"]), "a dead hero must leave the selection: %s" % [_selected()])
	_expect(sel.get_group(1) == _ids(["warrior"]) and sel.get_group(3) == _ids(["warrior"]), "a dead hero must leave every group: %s" % [sel.get_group(1)])
	_expect(not sel.select_only("mage") and not sel.toggle("mage"), "a dead hero can't be selected")
	_expect(main2d.player_action_controller.player == main2d.heroes[0], "controller should fall back to the living hero")
	_expect(not _portrait_of(hud, b).is_selected, "the dead hero's portrait should lose the highlight")
	paused = false
	Engine.time_scale = 1.0


# ---------------- FLOORS / NEW RUN ----------------

func _check_floors_and_new_run() -> void:
	sel.reset()
	ps.reset_run_upgrades()
	var world: Array = await _boot()
	sel.set_selection(_ids(["mage", "warrior"]))
	sel.assign_group(2)
	await _free_world(world)

	# Next floor: groups and selection survive, the primary stays the mage.
	world = await _boot()
	_expect(sel.get_group(2) == _ids(["mage", "warrior"]), "group lost across floors: %s" % [sel.get_group(2)])
	_expect(_selected() == _ids(["mage", "warrior"]), "selection lost across floors: %s" % [_selected()])
	_expect(world[0].player_action_controller.player.stats.hero_id == "mage" and world[0].camera.get_target().stats.hero_id == "mage", "controller/camera should follow the kept primary")
	_expect(_portrait_of(world[1], world[0].heroes[0]).is_selected and _portrait_of(world[1], world[0].heroes[1]).is_selected, "portraits should show the kept selection")
	await _free_world(world)

	# New run (Main._begin_new_run): everything is reset.
	var main_node: Node = load(MAIN_SCRIPT_PATH).new()
	main_node._begin_new_run()
	main_node.free()
	_expect(sel.get_group(2).is_empty() and sel.get_selected_ids().is_empty(), "new run left groups/selection")
	world = await _boot()
	_expect(_selected() == _ids(["warrior"]), "new run should select the first hero: %s" % [_selected()])
	await _free_world(world)


# ---------------- ONE HERO ----------------

func _check_single_hero() -> void:
	sel.reset()
	var world: Array = await _boot(1)
	var main2d: Node = world[0]
	_expect(main2d.heroes.size() == 1 and _selected() == _ids(["warrior"]), "single hero party: %s" % [_selected()])
	_press(KEY_F2)
	_expect(_selected() == _ids(["warrior"]), "F2 with one hero should do nothing")
	_press(KEY_F1, true)
	_expect(_selected() == _ids(["warrior"]), "Ctrl+F1 must not empty the selection")
	_press(KEY_1, true)
	_press(KEY_F1)
	_press(KEY_1)
	_expect(sel.get_group(1) == _ids(["warrior"]) and _selected() == _ids(["warrior"]), "group with one hero: %s / %s" % [sel.get_group(1), _selected()])

	# Orders still work.
	var room_manager: RoomManager = main2d.room_manager
	var start := room_manager.get_start_zone_id()
	var target := ""
	for door in room_manager.get_all_doors():
		if door.from_zone_id == start and not door.is_open:
			await main2d.player_action_controller._on_door_clicked(door)
			target = door.target_room_id
			break
	_expect(target != "" and main2d.heroes[0].current_zone_id != start, "the lone hero should open the door and walk in")
	await _free_world(world)

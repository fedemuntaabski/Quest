extends SceneTree

## Session 12: 2-hero party over a live Main2d + HUD (fallback map). Spawn,
## per-hero levels/HP, Tab selection (control + camera + portrait highlight),
## portrait clicks / popup of the clicked hero, a Tab mid-walk, lights/build/
## research still working with 2 heroes, the death rule (the run is lost only when
## every hero is down), floor carry-over and the Retry reset for both heroes.
##   godot --headless --path . --script res://tests/test_party.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/run/Main.gd"
## Longest glide the tests wait for (seconds of real time).
const MOVE_TIMEOUT := 5.0

var failures: Array[String] = []
var ps: Node
var resources: ResourceManager


func _initialize() -> void:
	ps = root.get_node("PlayerStats")
	resources = root.get_node("ResourceManager") as ResourceManager
	resources.reset_resources(15, 15, 10, 20)
	resources.reset_research()
	ps.reset_run_upgrades()

	var world: Array = await _boot()
	var main2d: Node = world[0]
	var hud: HUDController = world[1]
	if _check_spawn(main2d, hud):
		_check_independent_levels(main2d)
		_check_tab(main2d, hud)
		await _check_control(main2d)
		await _check_camera(main2d)
		_check_portraits_and_popup(main2d, hud)
		_check_regression(main2d, hud)
		_check_death(main2d)
		await _check_floors_and_retry(world)
	else:
		await _free_world(world)

	ps.reset_run_upgrades()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_party: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## Main2d + HUD like Main.gd (world first), default PartyConfig (2 heroes).
func _boot() -> Array:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
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
	for node: Node in world:
		node.queue_free()
	await process_frame
	await process_frame


func _hero_ids(main2d: Node) -> Array[String]:
	return [main2d.heroes[0].stats.hero_id, main2d.heroes[1].stats.hero_id]


func _portrait_of(hud: HUDController, hero: Player) -> HeroPortrait:
	for portrait: HeroPortrait in hud.portraits.get_children():
		if portrait.stats == hero.stats:
			return portrait
	return null


# ---------------- SPAWN ----------------

func _check_spawn(main2d: Node, hud: HUDController) -> bool:
	var heroes: Array = main2d.heroes
	_expect(heroes.size() == 2, "expected 2 heroes, got %d" % heroes.size())
	if heroes.size() != 2:
		return false
	var a: Player = heroes[0]
	var b: Player = heroes[1]
	var start: String = main2d.room_manager.get_start_zone_id()
	_expect(a.stats.hero_id != "" and b.stats.hero_id != "" and a.stats.hero_id != b.stats.hero_id, "hero ids '%s'/'%s'" % [a.stats.hero_id, b.stats.hero_id])
	_expect(ps.get_hero_ids() == _hero_ids(main2d), "PlayerStats party %s" % [ps.get_hero_ids()])
	_expect(a.current_zone_id == start and b.current_zone_id == start, "heroes not in the start room")
	_expect(a.global_position == b.global_position and a.animated_sprite.position != b.animated_sprite.position, "sprite offset should split heroes sharing a zone")
	var cameras := main2d.find_children("*", "Camera2D", true, false)
	_expect(cameras.size() == 1 and cameras[0] == main2d.camera and main2d.camera.get_parent() == a, "expected one GameCamera on heroes[0], got %d" % cameras.size())
	_expect(ps.active_hero_id == a.stats.hero_id and ManagerLocator.get_player() == a, "first hero should start selected")
	_expect(main2d.player_action_controller.player == a and main2d.camera.get_target() == a, "control/camera should start on the first hero")
	_expect(hud.portraits.get_child_count() == 2, "expected 2 portraits, got %d" % hud.portraits.get_child_count())
	var pa := _portrait_of(hud, a)
	var pb := _portrait_of(hud, b)
	_expect(pa != null and pb != null and pa.get_index() < pb.get_index(), "portraits missing or out of party order")
	_expect(pa != null and pa.is_selected and pb != null and not pb.is_selected, "only the first portrait should be highlighted")
	return pa != null and pb != null


# ---------------- PER-HERO LEVELS / HP ----------------

func _check_independent_levels(main2d: Node) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var ids := _hero_ids(main2d)
	var cfg: UpgradeConfig = ps.run_upgrade_config
	resources.add_resource("food", 500)
	var a_max := a.stats.max_hp
	var a_dmg := a.stats.attack_damage
	var b_max := b.stats.max_hp
	var b_dmg := b.stats.attack_damage
	var events: Array = []
	var on_level := func(_k: String, level: int, hero_id: String) -> void: events.append([hero_id, level])
	ps.run_upgrades_changed.connect(on_level)

	_expect(ps.level_up_hero(ids[1]), "level up of the second hero by id")
	_expect(ps.get_hero_level(ids[1]) == 2 and ps.get_hero_level(ids[0]) == 1, "levels %d/%d after leveling the second hero" % [ps.get_hero_level(ids[0]), ps.get_hero_level(ids[1])])
	_expect(b.stats.max_hp == b_max + cfg.hp_per_level and b.stats.attack_damage == b_dmg + 1 and b.hitbox.damage == b.stats.attack_damage, "second hero stats did not rise")
	_expect(a.stats.max_hp == a_max and a.stats.attack_damage == a_dmg and a.hitbox.damage == a_dmg, "first hero changed when the second leveled up")
	_expect(events == [[ids[1], 1]], "run_upgrades_changed payload %s" % [events])

	# No id = the active hero (first one).
	_expect(ps.level_up_hero() and ps.get_hero_level(ids[0]) == 2 and ps.get_hero_level(ids[1]) == 2, "id-less level up should hit the active hero")
	_expect(ps.get_hero_level() == 2 and ps.run_level == 1 and ps.stats == a.stats, "compat API should read the active hero")
	_expect(ps.get_level_up_preview(ids[1])["level"] == 2 and ps.get_run_upgrade_preview("hp", ids[1])["current"] == b.stats.max_hp, "preview by id")
	ps.run_upgrades_changed.disconnect(on_level)

	# Damage is per hero.
	b.stats.take_damage(5)
	_expect(b.stats.current_hp == b.stats.max_hp - 5 and a.stats.current_hp == a.stats.max_hp, "damage leaked between heroes")
	b.stats.heal(5)


# ---------------- SELECTION ----------------

func _check_tab(main2d: Node, hud: HUDController) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	_press_key(KEY_TAB)
	_expect(ps.active_hero_id == b.stats.hero_id and ManagerLocator.get_player() == b, "Tab should select the second hero")
	_expect(main2d.player_action_controller.player == b, "Tab should hand control to the second hero")
	_expect(main2d.camera.get_target() == b, "Tab should point the camera at the second hero")
	_expect(_portrait_of(hud, b).is_selected and not _portrait_of(hud, a).is_selected, "portrait highlight did not follow Tab")
	_press_key(KEY_TAB)
	_expect(ps.active_hero_id == a.stats.hero_id and main2d.player_action_controller.player == a and main2d.camera.get_target() == a, "Tab should wrap back to the first hero")
	_expect(_portrait_of(hud, a).is_selected and not _portrait_of(hud, b).is_selected, "portrait highlight did not wrap")


## Orders go to the selected hero only; a Tab mid-walk still lands the walker.
func _check_control(main2d: Node) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var room_manager: RoomManager = main2d.room_manager
	var controller: PlayerActionController = main2d.player_action_controller
	var start := room_manager.get_start_zone_id()
	# Open the whole map (reveal order), then use two side rooms.
	var progress := true
	while progress:
		progress = false
		for door in room_manager.get_all_doors():
			if not door.is_open and room_manager.is_zone_revealed(door.from_zone_id):
				main2d.door_turn_system.open_room(door.target_room_id)
				door.disable_door()
				progress = true
	# Invasion rolls may have spawned enemies: keep the heroes out of combat here.
	for enemy in main2d.get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	var opened: Array[String] = []
	for zone_id in room_manager.get_zone_ids():
		if zone_id != start and room_manager.get_zone_kind(zone_id) == "room" and room_manager.is_zone_revealed(zone_id):
			opened.append(zone_id)
	_expect(opened.size() >= 2, "expected 2+ side rooms, got %d" % opened.size())
	if opened.size() < 2:
		return

	ps.select_hero(b.stats.hero_id)
	await controller._on_zone_clicked(opened[0])
	_expect(b.current_zone_id == opened[0] and a.current_zone_id == start, "click moved the wrong hero (a '%s', b '%s')" % [a.current_zone_id, b.current_zone_id])

	# Tab mid-walk: the walker (b) still arrives, the new selection (a) stays put.
	controller._on_zone_clicked(start)
	_expect(controller._action_in_flight, "second move did not start")
	ps.select_hero(a.stats.hero_id)
	controller._on_zone_clicked(opened[1])  # one order at a time: ignored
	await _wait_idle(controller)
	_expect(b.current_zone_id == start and a.current_zone_id == start, "mid-walk switch misplaced heroes (a '%s', b '%s')" % [a.current_zone_id, b.current_zone_id])
	_expect(controller.player == a, "control should stay on the newly selected hero")
	# Leave b in a side room for the camera check.
	ps.select_hero(b.stats.hero_id)
	await controller._on_zone_clicked(opened[0])
	ps.select_hero(a.stats.hero_id)
	_expect(b.current_zone_id == opened[0], "b should wait in '%s'" % opened[0])


## process_frame fires before nodes process: two frames = camera _process ran.
func _frames() -> void:
	await process_frame
	await process_frame


func _wait_idle(controller: PlayerActionController) -> void:
	var deadline := Time.get_ticks_msec() + int(MOVE_TIMEOUT * 1000)
	while controller._action_in_flight and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not controller._action_in_flight, "move never finished")


## Camera follows the selection; a panned camera stays until C (recenter).
func _check_camera(main2d: Node) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var camera: GameCamera = main2d.camera
	_expect(a.global_position.distance_to(b.global_position) > 1.0, "heroes should be in different zones")
	camera.recenter()
	await _frames()
	_expect(camera.global_position.is_equal_approx(camera.clamp_to_bounds(a.global_position)), "camera %s not on the selected hero %s" % [camera.global_position, a.global_position])
	_press_key(KEY_TAB)
	await _frames()
	_expect(camera.get_target() == b and camera.global_position.is_equal_approx(camera.clamp_to_bounds(b.global_position)), "camera %s did not move to the new selection %s" % [camera.global_position, b.global_position])

	camera.focus_on(camera.global_position + Vector2(40, 40))  # player panned
	await _frames()
	var panned := camera.global_position
	_press_key(KEY_TAB)
	await _frames()
	_expect(camera.get_target() == a and not camera.is_following() and camera.global_position.is_equal_approx(panned), "a panned camera must stay put on Tab")
	_press_key(KEY_C)
	await _frames()
	_expect(camera.is_following() and camera.global_position.is_equal_approx(camera.clamp_to_bounds(a.global_position)), "C should recenter on the selected hero")


# ---------------- PORTRAITS / POPUP ----------------

func _check_portraits_and_popup(main2d: Node, hud: HUDController) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var pa := _portrait_of(hud, a)
	var pb := _portrait_of(hud, b)
	var popup := hud.character_popup
	_expect(ps.active_hero_id == a.stats.hero_id, "precondition: first hero selected")

	pb.portrait_clicked.emit(pb)
	_expect(ps.active_hero_id == b.stats.hero_id and pb.is_selected and not pa.is_selected, "left click on another portrait should select it")
	_expect(not popup.visible, "selecting by portrait must not open the sheet")
	pb.portrait_clicked.emit(pb)
	_expect(popup.visible and popup.stats == b.stats, "left click on the selected portrait should open its sheet")
	popup.close()

	# Right click (real gui_input path): sheet of that hero, selection unchanged.
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	pa._on_gui_input(right)
	_expect(popup.visible and popup.stats == a.stats and popup._title.text == a.character_data.display_name, "right click should open the clicked (unselected) hero's sheet")
	_expect(ps.active_hero_id == b.stats.hero_id, "right click must not change the selection")
	var level_a: int = ps.get_hero_level(a.stats.hero_id)
	var level_b: int = ps.get_hero_level(b.stats.hero_id)
	_expect(popup._info.text.begins_with("Nivel %d" % level_a), "sheet shows level of '%s': %s" % [a.stats.hero_id, popup._info.text.get_slice("\n", 0)])
	popup._level_button.pressed.emit()
	_expect(ps.get_hero_level(a.stats.hero_id) == level_a + 1 and ps.get_hero_level(b.stats.hero_id) == level_b, "sheet button must level its own hero, not the selected one")
	_expect(popup._info.text.begins_with("Nivel %d" % (level_a + 1)), "sheet did not refresh after leveling")
	popup.close()
	ps.select_hero(a.stats.hero_id)


# ---------------- REGRESSION: light / build / research ----------------

func _check_regression(main2d: Node, hud: HUDController) -> void:
	var room_manager: RoomManager = main2d.room_manager
	var room := room_manager.get_zone_node(room_manager.get_start_zone_id())
	var major: BuildingSlot = null
	for slot: BuildingSlot in room.find_children("*", "BuildingSlot", true, false):
		if slot.slot_type == BuildingSlot.SlotType.MAJOR and slot.is_empty():
			major = slot
	_expect(major != null, "start room should be lit with a free MAJOR slot")
	if major:
		resources.add_resource("industry", 100)
		var industry_before := resources.get_resource("industry")
		var yield_before := resources.get_turn_yield("industry")
		hud.production_button.pressed.emit()
		_press_key(KEY_1)
		hud.open_building_menu(major)
		_expect(not major.is_empty() and resources.get_resource("industry") < industry_before, "build with 2 heroes failed")
		_expect(resources.get_turn_yield("industry") > yield_before, "generator yield with 2 heroes")

	resources.add_resource("science", 20)
	_expect(resources.research("science_generator") and resources.is_researched("science_generator"), "research with 2 heroes failed")

	var side_room := ""
	for zone_id in room_manager.get_zone_ids():
		if zone_id != room_manager.get_start_zone_id() and room_manager.get_zone_kind(zone_id) == "room" and room_manager.is_zone_revealed(zone_id):
			side_room = zone_id
	var side := room_manager.get_zone_node(side_room) if side_room != "" else null
	_expect(side != null, "no revealed side room to light")
	if side:
		resources.add_resource("dust", 30)
		var dust_before := resources.get_resource("dust")
		side.toggle_power()
		_expect(side.is_powered and resources.get_resource("dust") < dust_before, "lighting a room with 2 heroes failed")
		side.toggle_power()
		_expect(not side.is_powered and resources.get_resource("dust") == dust_before, "switching off should refund")


# ---------------- DEATH ----------------

## Decision (bucle-7): one hero down does not end the run; every hero down does.
func _check_death(main2d: Node) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	_expect(ps.active_hero_id == a.stats.hero_id, "precondition: first hero selected")
	b.stats.take_damage(b.stats.max_hp)  # the unselected one
	var gsm: GameStateManager = main2d.game_state_manager
	_expect(not b.stats.is_alive() and a.stats.is_alive(), "death should be per hero")
	_expect(not main2d._is_dead and not gsm.is_dead(), "one hero down should not end the run (state %s)" % GameStateManager.State.keys()[gsm.current_state])
	a.stats.take_damage(a.stats.max_hp)
	_expect(main2d._is_dead and gsm.is_dead(), "every hero down should end the run (state %s)" % GameStateManager.State.keys()[gsm.current_state])
	paused = false


# ---------------- FLOORS / RETRY ----------------

func _check_floors_and_retry(world: Array) -> void:
	var main2d: Node = world[0]
	var ids := _hero_ids(main2d)
	ps.run_levels = {ids[0]: 2, ids[1]: 1}
	await _free_world(world)

	# Next floor (Main.advance_floor keeps the run): levels carried, HP full.
	world = await _boot()
	main2d = world[0]
	_expect_levels(main2d, ids, [3, 2], "next floor")
	await _free_world(world)

	# Retry / new run (Main._begin_new_run): both heroes back to level 1.
	var main_node: Node = load(MAIN_SCRIPT_PATH).new()
	main_node._begin_new_run()
	main_node.free()
	_expect(ps.run_levels.is_empty(), "Retry left run levels %s" % [ps.run_levels])
	world = await _boot()
	main2d = world[0]
	_expect_levels(main2d, ids, [1, 1], "after Retry")
	await _free_world(world)


func _expect_levels(main2d: Node, ids: Array[String], levels: Array, when: String) -> void:
	var cfg: UpgradeConfig = ps.run_upgrade_config
	_expect(_hero_ids(main2d) == ids, "%s: party changed %s" % [when, _hero_ids(main2d)])
	for i in 2:
		var hero: Player = main2d.heroes[i]
		var s := hero.stats
		var bought: int = levels[i] - 1
		_expect(ps.get_hero_level(ids[i]) == levels[i], "%s: '%s' level %d, expected %d" % [when, ids[i], ps.get_hero_level(ids[i]), levels[i]])
		_expect(s.max_hp == hero.character_data.base_hp + cfg.hp_per_level * bought, "%s: '%s' max hp %d" % [when, ids[i], s.max_hp])
		_expect(s.attack_damage == cfg.damage_at(hero.character_data.attack_damage, bought), "%s: '%s' damage %d" % [when, ids[i], s.attack_damage])
		_expect(s.current_hp == s.max_hp, "%s: '%s' should start the floor at full HP" % [when, ids[i]])


## Real key press through the viewport (HUD _input runs before Main2d's).
func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release)

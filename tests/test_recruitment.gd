extends SceneTree

## heroes-9: Prisoner room recruitment over a live Main2d + HUD (fallback map).
## A cage holds a hero the party didn't pick; freeing it costs Industria or
## Comida (RoomTypeRule.recruit_costs), adds the hero (portrait, F3/F4) and keeps
## it on the next floors (GameSession.recruited_ids). The party caps at 4.
##   godot --headless --path . --script res://tests/test_recruitment.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"

var failures: Array[String] = []
var resources: ResourceManager
var session: Node


func _initialize() -> void:
	var ps := root.get_node("PlayerStats")
	resources = root.get_node("ResourceManager") as ResourceManager
	session = root.get_node("GameSession")
	session.clear()
	_expect(session.set_selection(["warrior", "mage"] as Array[String]), "pick warrior + mage")
	resources.reset_resources(0, 0, 0, 0)
	ps.reset_run_upgrades()

	var world: Array = await _boot()
	var main2d: Node = world[0]
	var hud: HUDController = world[1]
	await _check_recruit(main2d, hud)
	_check_cap(main2d)
	_check_floor_carry()
	await _free_world(world)

	session.clear()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_recruitment: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _check_recruit(main2d: Node, hud: HUDController) -> void:
	var spawner: PrisonerSpawner = main2d.prisoner_spawner
	var start: String = main2d.room_manager.get_start_zone_id()
	_expect(main2d.heroes.size() == 2, "starts with the 2 picked heroes")

	var cage := spawner.spawn_for(start)
	_expect(cage != null, "a cage with a candidate")
	if cage == null:
		return
	_expect(cage.hero_id in ["rogue", "tank"], "the prisoner is a hero not picked: '%s'" % cage.hero_id)
	var industry_cost: int = cage.costs.get("industry", 0)
	var food_cost: int = cage.costs.get("food", 0)
	_expect(industry_cost > 0 and food_cost > 0, "two prices (Industria, Comida): %s" % [cage.costs])

	# Short of both: nothing happens.
	_expect(not cage.free_with("industry") and main2d.heroes.size() == 2, "can't free without Industria")
	cage.open_dialog()
	var price_buttons := 0
	for button in cage.dialog.find_children("*", "Button", true, false):
		if button.has_meta("resource"):
			price_buttons += 1
			_expect(button.disabled, "price button enabled while unaffordable")
	_expect(price_buttons == 2, "dialog offers both prices (%d)" % price_buttons)
	cage.dialog.hide()

	resources.add_resource("industry", industry_cost + 3)
	_expect(cage.free_with("industry"), "pay Industria to free")
	_expect(resources.get_resource("industry") == 3, "Industria charged (%d left)" % resources.get_resource("industry"))
	_expect(main2d.heroes.size() == 3 and main2d.heroes[2].stats.hero_id == cage.hero_id, "recruit joins as hero 3")
	_expect(session.recruited_ids.has(cage.hero_id), "recruit stored in GameSession")
	_expect(main2d.heroes[2].current_zone_id == start, "recruit stands in the prisoner's room")
	await process_frame
	_expect(hud.portraits.get_child_count() == 3, "recruit gets a HeroPortrait (%d)" % hud.portraits.get_child_count())
	_expect(cage.is_freed and not cage.free_with("food"), "a freed cage can't be paid again")

	var cage2 := spawner.spawn_for(start)
	_expect(cage2 != null and cage2.hero_id != cage.hero_id, "second cage holds the last hero")
	if cage2:
		resources.add_resource("food", food_cost)
		_expect(cage2.free_with("food") and resources.get_resource("food") == 0, "pay Comida to free")
	_expect(main2d.heroes.size() == 4, "party of 4 (%d)" % main2d.heroes.size())

	# F3 / F4 select heroes 3 / 4.
	var selection: Node = root.get_node("SelectionManager")
	_press_key(KEY_F3)
	_expect(selection.get_selected_ids() == ([main2d.heroes[2].stats.hero_id] as Array[String]), "F3 -> hero 3: %s" % [selection.get_selected_ids()])
	_press_key(KEY_F4)
	_expect(selection.get_selected_ids() == ([main2d.heroes[3].stats.hero_id] as Array[String]), "F4 -> hero 4: %s" % [selection.get_selected_ids()])
	# Control group with 4 heroes.
	selection.set_selection([main2d.heroes[1].stats.hero_id, main2d.heroes[3].stats.hero_id] as Array[String])
	selection.assign_group(2)
	selection.select_only(main2d.heroes[0].stats.hero_id)
	_expect(selection.select_group(2) and selection.get_selected_ids().size() == 2, "group 2 recalls 2 of the 4 heroes")


func _check_cap(main2d: Node) -> void:
	var spawner: PrisonerSpawner = main2d.prisoner_spawner
	_expect(spawner.pick_candidate("anything") == "", "no candidate with a full party")
	_expect(spawner.spawn_for(main2d.room_manager.get_start_zone_id()) == null, "no cage with a full party")
	_expect(main2d.recruit_hero("rogue", main2d.room_manager.get_start_zone_id()) == null, "recruit_hero refuses a 5th hero")
	_expect(main2d.heroes.size() == 4, "still 4 heroes")


func _check_floor_carry() -> void:
	var party: Array[String] = session.resolve_party(session.get_party_ids())
	_expect(party.size() == 4, "next floor spawns the 4 (picked + recruits): %s" % [party])
	_expect(session.get_recruit_candidates(party).is_empty(), "no candidates left")


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
	camera.config.edge_scroll_enabled = false
	return [main2d, hud]


func _free_world(world: Array) -> void:
	paused = false
	for node: Node in world:
		node.queue_free()
	await process_frame
	await process_frame


func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release)

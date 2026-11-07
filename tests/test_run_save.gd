extends SceneTree

## Session guardado-19: the offline run saved at the start of floor 2+, over the
## real Main. Floor 1 is played for real (doors, Reliquia, carrier walks out),
## the party gets levels, a perk, equipment, stash, research, a recruit and a
## lost hero; advance_floor() saves; back to the menu, the state is wiped, and
## the menu's slot -> "Continuar partida (piso 2)" brings floor 2 back with the
## same heroes, equipment, resources, research, run stats and map seed.
## Also: defeat / a new run clear the save, the Tutorial and co-op never save,
## the pause menu's exit text, and a v2 slot (pre guardado-19) migrates to v3.
##   godot --headless --path . --script res://tests/test_run_save.gd

const MAIN_PATH := "res://scenes/Main.tscn"
const SLOT := 93
const HUGE_HP := 1000000

var failures: Array[String] = []
var _main: Main
var _save: Node
var _probe: ErrorProbe


func _initialize() -> void:
	_probe = ErrorProbe.install()
	_save = root.get_node("SaveManager")
	_save.delete_save(SLOT)
	_test_migration()
	_main = (load(MAIN_PATH) as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _frames(20)
	await _test_save_and_continue()
	await _test_cleared_by_new_run()
	await _test_tutorial_never_saves()
	Engine.time_scale = 1.0
	await _main.return_to_main_menu()
	await _frames(10)
	_main.queue_free()
	await _frames(10)
	_save.delete_save(SLOT)
	_probe.uninstall()
	for m in _probe.messages:
		failures.append("console: " + m)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_run_save: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _main2d() -> Node:
	return _main.world_container.get_child(0) if _main.world_container.get_child_count() > 0 else null


func _session() -> Node:
	return root.get_node("GameSession")


func _stats() -> Node:
	return root.get_node("PlayerStats")


func _inv() -> Node:
	return root.get_node("PartyInventory")


func _res() -> Node:
	return root.get_node("ResourceManager")


# ---------------- migration ----------------

## A v2 slot (calidad-13 .. audio-18) with records, bestiary and a stray [run]
## section loads as v3: everything kept, no run in progress.
func _test_migration() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save_data", "version", 2)
	cfg.set_value("save_data", "selected_character_id", "rogue")
	cfg.set_value("save_data", "playtime_seconds", 77.0)
	cfg.set_value("records", "normal", {"runs": 2, "victories": 0, "best_floor": 3})
	cfg.set_value("bestiary", "goblin", {"seen": 1, "kills": 2})
	cfg.set_value("run", "state", {"floor": 4, "heroes": ["warrior"]})  # not a v3 run
	_expect(cfg.save(_save.get_save_path(SLOT)) == OK, "v2 fixture written")
	var migrated: ConfigFile = _save.read_slot(SLOT)
	_expect(int(migrated.get_value("save_data", "version", 0)) == 3 and _save.SAVE_VERSION == 3, "v2 slot migrates to v3")
	_save.load_game(SLOT)
	_expect(_save.get_selected_character_id() == "rogue", "v2 hero survives")
	_expect(is_equal_approx(_save.playtime_seconds, 77.0), "v2 playtime survives")
	_expect(int(_save.get_records("normal", SLOT).get("best_floor", 0)) == 3, "v2 records survive")
	_expect(root.get_node("BestiaryService").entries.has("goblin"), "v2 bestiary survives")
	_expect(not _save.has_saved_run(SLOT), "a v2 slot has no run in progress")
	_save.save_game(SLOT)
	_expect(not _save.read_slot(SLOT).has_section("run"), "the stray [run] is gone once saved")
	_save.delete_save(SLOT)


# ---------------- save -> menu -> continue ----------------

func _test_save_and_continue() -> void:
	_save.load_game(SLOT)
	_session().difficulty = "hard"
	_session().set_selection(["warrior", "mage"] as Array[String])
	await _main.start_gameplay()
	await _frames(5)
	_expect(not _save.has_saved_run(SLOT), "floor 1 is never saved")
	# Run progress worth keeping: levels (+ the level-3 perk), equipment, stash,
	# research, a recruit, a lost hero, summary stats.
	var res := _res()
	res.add_resource("food", 500)
	for i in 2:
		_expect(_stats().level_up_hero("warrior"), "warrior level up %d" % i)
	_stats().level_up_hero("mage")
	var choices: Array = _stats().get_pending_perk_choices("warrior")
	_expect(not choices.is_empty(), "warrior has a level-3 perk on offer")
	if not choices.is_empty():
		_expect(_stats().choose_perk("warrior", choices[0].id), "perk chosen")
	var sword := ItemCatalog.find("sword_iron")
	var armor := ItemCatalog.find("armor_leather")
	_inv().add_item(sword)
	_expect(_inv().equip("warrior", sword), "sword equipped")
	_inv().add_item(armor)
	_inv().add_item(ItemCatalog.find("potion_health"))
	_inv().add_item(ItemCatalog.find("potion_health"))
	res.research_state.add("ballesta")
	res.research_state.add("cartography")
	_session().add_recruit("rogue")
	_session().mark_lost("tank")
	_session().add_stat("kills", 7)
	res.add_resource("iron", 33)
	res.add_resource("lore", 11)

	await _play_floor_1()
	var gsm := ManagerLocator.get_game_state_manager()
	_expect(gsm.current_state == GameStateManager.State.VICTORY, "floor 1 won by walking out")
	await _main.advance_floor()
	await _frames(5)
	var saved: Dictionary = _save.get_saved_run(SLOT)
	var expected := _live()
	_expect(int(saved.get("floor", 0)) == 2, "floor 2 start is saved (%s)" % saved.get("floor"))
	# The file holds the floor-2 start (resources differ only by the descend bonus Main2d adds).
	var on_file := {"run_seed": saved.get("run_seed"), "difficulty": saved.get("difficulty"),
		"recruited": saved.get("recruited"), "lost": saved.get("lost"), "levels": saved.get("stats"),
		"inv": saved.get("inv"), "run_stats": (saved.get("run_stats", {}) as Dictionary).merged({"elapsed_sec": 0, "floor_reached": 2}, true)}  # FloorManager raises floor_reached on boot
	for key: String in on_file:
		_expect(var_to_str(on_file[key]) == var_to_str(expected[key]), "saved %s: %s != %s" % [key, on_file[key], expected[key]])
	_expect(var_to_str(saved["res"]["research"]) == var_to_str(expected["res"]["research"]), "saved research")
	_expect(saved["difficulty"] == "hard", "saved difficulty")
	_expect(expected["floor"] == 2 and expected["heroes"] == ["warrior", "mage", "rogue"], "floor 2 party = pick + recruit, no lost hero (%s)" % [expected["heroes"]])
	_expect(_main2d().get_node("PauseMenu").exit_message().contains("piso 2"), "pause exit text names the floor kept")

	# Leave and wipe every autoload the save has to rebuild.
	await _main.return_to_main_menu()
	await _frames(10)
	_main.run_seed = 1
	_main.current_floor = 1
	_main._begin_new_run()
	_session().difficulty = "normal"
	_session().selected_hero_ids.clear()
	_expect(_res().get_resource("iron") != expected["res"]["res"]["iron"] or _inv().stash_size() == 0, "state wiped before continuing")

	# The real menu path: slot -> dialog -> Continuar.
	var menu := _main.ui_container.get_child(0)
	var flow: MainMenuFlow = menu.flow
	_save.slot_loaded = false
	await flow._on_slot_selected(SLOT)
	_expect(flow.continue_dialog != null and flow.continue_dialog.ok_button_text == "Continuar partida (piso 2)", "slot with a run offers 'Continuar partida (piso 2)'")
	if flow.continue_dialog:
		flow.continue_dialog.confirmed.emit()
	await _frames(5)
	while _main._is_transitioning:
		await process_frame
	await _frames(10)
	var got := _live()
	for key: String in expected:
		_expect(var_to_str(got[key]) == var_to_str(expected[key]), "continued %s: %s != %s" % [key, got[key], expected[key]])
	_expect(_stats().get_perks_of("warrior").size() == 1, "warrior keeps the perk")
	var weapon: Array = _inv().get_equipped("warrior", ItemData.Slot.WEAPON)
	_expect(weapon.size() == 1 and weapon[0] == sword, "warrior keeps the sword")
	_expect(_stats().get_hero_stats("warrior").current_hp == _stats().get_hero_stats("warrior").max_hp, "HP full at the floor start")
	_expect(_save.has_saved_run(SLOT), "continuing keeps the save (floor start)")

	# Defeat ends the run: nothing to continue.
	_main2d()._on_player_died()
	await _frames(5)
	_expect(not _save.has_saved_run(SLOT), "defeat clears the saved run")
	_expect(_save.read_slot(SLOT).has_section("records"), "the records stay")


## Everything a continued floor has to match.
func _live() -> Dictionary:
	var main2d := _main2d()
	var heroes: Array = []
	for hero: Player in main2d.heroes:
		heroes.append(hero.stats.hero_id)
	return {
		"floor": main2d.floor_manager.floor_index,
		"map_seed": main2d.floor_manager.map_seed,
		"run_seed": _main.run_seed,
		"rooms": main2d.room_manager.get_zone_ids().size(),
		"heroes": heroes,
		"difficulty": _session().difficulty,
		"recruited": _session().recruited_ids,
		"lost": _session().lost_ids,
		"run_stats": _session().run_stats.duplicate().merged({"elapsed_sec": 0}, true),  # the clock runs on the floor
		"levels": _stats().get_run_state(),
		"max_hp": _stats().get_hero_stats("warrior").max_hp,
		"attack": _stats().get_hero_stats("warrior").attack_damage,
		"inv": _inv().get_state(),
		"res": _res().get_state(),
	}


func _tough() -> void:
	var main2d := _main2d()
	for hero: Player in main2d.heroes:
		hero.stats.max_hp = HUGE_HP
		hero.stats.current_hp = HUGE_HP
	var relic := ManagerLocator.get_relic()
	if relic:
		relic.max_hp = HUGE_HP
		relic.current_hp = HUGE_HP


func _play_floor_1() -> void:
	var main2d := _main2d()
	var rm: RoomManager = main2d.room_manager
	var doors: DoorTurnSystem = main2d.door_turn_system
	_tough()
	var opened := true
	while opened:
		opened = false
		for door in rm.get_all_doors():
			if door.is_open or not rm.is_zone_revealed(door.from_zone_id):
				continue
			doors.open_room(door.target_room_id)
			door.disable_door()
			opened = true
			await process_frame
			_tough()
	var hero: Player = main2d.heroes[0]
	hero.set_zone(rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()), main2d.floor_layer)
	hero.pick_up_relic()
	ManagerLocator.get_extraction_manager().start_extraction()
	Engine.time_scale = 4.0
	for i in 10:
		await process_frame
		_tough()
	await main2d.player_action_controller.move_heroes([hero] as Array[Player], rm.get_exit_zone_id())
	Engine.time_scale = 1.0
	await _frames(20)


# ---------------- clearing ----------------

## A new offline run (heroes picked again) replaces the saved one.
func _test_cleared_by_new_run() -> void:
	await _main.return_to_main_menu()  # from the defeat screen (paused tree)
	await _frames(10)
	_save.save_run(_main.capture_run().merged({"floor": 3}, true), SLOT)
	_expect(_save.has_saved_run(SLOT), "fixture run saved")
	_session().set_selection(["warrior", "mage"] as Array[String])
	await _main.start_gameplay()
	await _frames(5)
	_expect(not _save.has_saved_run(SLOT), "a new run clears the saved one")
	_expect(_main2d().get_node("PauseMenu").exit_message() == _main2d().get_node("PauseMenu").exit_confirm_dialog.message_text, "floor 1: default exit text")


## The Tutorial neither saves nor erases a saved run.
func _test_tutorial_never_saves() -> void:
	_save.save_run(_main.capture_run().merged({"floor": 3}, true), SLOT)
	await _main.start_tutorial()
	await _frames(5)
	_expect(_save.get_saved_run(SLOT).get("floor") == 3, "the Tutorial keeps the slot's run")
	_save.clear_run(SLOT)
	_main.current_floor = 2
	_main._save_run()
	_expect(not _save.has_saved_run(SLOT), "the Tutorial never saves")
	_session().tutorial = false

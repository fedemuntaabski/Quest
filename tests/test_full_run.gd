extends SceneTree

## Session calidad-13: a whole run, accelerated, with a fixed seed, through the
## real Main orchestrator. Per floor: open every door in reveal order, let the
## fight run (Engine.time_scale 4), pick up the Relic, run the extraction a few
## seconds, kill the boss (floors 3 and 5: the exit refuses the carrier while it
## lives), walk the carrier to the exit for real and descend; after floor 5, back
## to the menu.
## Heroes and Relic get a huge HP pool (this checks stability, not balance).
## At the end: no ERROR / WARNING on the console (ErrorProbe) and no orphan nodes.
##   godot --headless --path . --script res://tests/test_full_run.gd

const MAIN_PATH := "res://scenes/Main.tscn"
const SEED := 1313
const SLOT := 91
const FIGHT_SEC := 4.0
const HUGE_HP := 1000000
const BOSS_FLOORS: Array[int] = [3, 5]

var failures: Array[String] = []
var _main: Main
var _probe: ErrorProbe


func _initialize() -> void:
	_probe = ErrorProbe.install()
	await process_frame
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_main = (load(MAIN_PATH) as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _frames(20)
	root.get_node("SaveManager").load_game(SLOT)
	root.get_node("GameSession").set_selection(["warrior", "mage"] as Array[String])
	seed(SEED)
	await _main.start_gameplay()
	_main.run_seed = SEED  # fixed maps from floor 2 on (floor 1 used the rolled one)
	var floors := 0
	for f in range(1, 6):
		var ok := await _play_floor(f)
		if not ok:
			break
		floors += 1
	_expect(floors == 5, "completed %d/5 floors" % floors)
	Engine.time_scale = 1.0
	await _main.return_to_main_menu()
	await _frames(20)
	_main.queue_free()
	await _frames(10)
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - orphans_before
	if orphans > 0:
		Node.print_orphan_nodes()
	_expect(orphans <= 0, "%d orphan nodes left after the run" % orphans)
	_probe.uninstall()
	for m in _probe.messages:
		failures.append("console: " + m)
	root.get_node("SaveManager").delete_save(SLOT)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_full_run: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _main2d() -> Node:
	return _main.world_container.get_child(0) if _main.world_container.get_child_count() > 0 else null


func _tough() -> void:
	var main2d := _main2d()
	for hero: Player in main2d.heroes:
		hero.stats.max_hp = HUGE_HP
		hero.stats.current_hp = HUGE_HP
	var relic := ManagerLocator.get_relic()
	if relic:
		relic.max_hp = HUGE_HP
		relic.current_hp = HUGE_HP


func _fight(sec: float) -> void:
	Engine.time_scale = 4.0
	var end := Time.get_ticks_msec() + int(sec * 1000.0 / 4.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		_tough()
	Engine.time_scale = 1.0


func _play_floor(f: int) -> bool:
	await _frames(5)
	var main2d := _main2d()
	if main2d == null or main2d.floor_manager.floor_index != f:
		_expect(false, "floor %d did not boot" % f)
		return false
	_tough()
	var rm: RoomManager = main2d.room_manager
	var doors: DoorTurnSystem = main2d.door_turn_system
	var opened := true
	while opened:  # reveal order: a door is openable once its near side is revealed
		opened = false
		for door in rm.get_all_doors():
			if door.is_open or not rm.is_zone_revealed(door.from_zone_id):
				continue
			doors.open_room(door.target_room_id)
			door.disable_door()
			opened = true
			await process_frame
			_tough()
	await _fight(FIGHT_SEC)
	var gsm := ManagerLocator.get_game_state_manager()
	if not gsm.is_active():
		_expect(false, "floor %d: run left ACTIVE while exploring (%s)" % [f, gsm.current_state])
		return false
	var hero: Player = main2d.heroes[0]
	hero.set_zone(rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()), main2d.floor_layer)
	hero.pick_up_relic()
	ManagerLocator.get_extraction_manager().start_extraction()
	await _fight(FIGHT_SEC)
	_expect(ManagerLocator.get_enemy_manager().alive_count() <= main2d.floor_manager.max_enemies() + 1, "floor %d: enemy cap exceeded" % f)
	var enemies := ManagerLocator.get_enemy_manager()
	var extraction := ManagerLocator.get_extraction_manager()
	_expect(enemies.is_boss_alive() == BOSS_FLOORS.has(f), "floor %d: boss alive = %s" % [f, enemies.is_boss_alive()])
	if enemies.is_boss_alive():
		_expect(not extraction.can_declare_victory(), "floor %d: the boss must guard the exit" % f)
		enemies.boss.take_damage(enemies.boss.current_hp)
		await _frames(5)
	# The real way out: the carrier walks there and arriving declares the victory.
	Engine.time_scale = 4.0
	await main2d.player_action_controller.move_heroes([hero] as Array[Player], rm.get_exit_zone_id())
	Engine.time_scale = 1.0
	await _frames(20)
	_expect(gsm.current_state == GameStateManager.State.VICTORY, "floor %d: arriving with the Reliquia should win (state %s)" % [f, gsm.current_state])
	_expect(main2d.victory_overlay.visible, "floor %d: victory overlay" % f)
	if f < 5:
		await _main.advance_floor()
	return true

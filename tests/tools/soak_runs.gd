extends SceneTree

## juego-22 soak: test_full_run over many seeds, with the offline save in the loop.
## Per seed, through the real Main: floors 1-5 (open every door, fight a few seconds at
## time_scale 4, Reliquia, extraction, boss on 3/5, the carrier walks out, descend); at every
## floor start from 2 on: back to the menu and "continue" the saved run (same floor, party and
## map seed). Measured: node count at every floor start (a leak grows it seed after seed),
## orphan nodes at the end, ERROR/WARNING on the console (ErrorProbe), frame time on the floor
## with the most enemies alive, wall time per seed. Writes user://soak_runs.json.
## Heroes and Relic get a huge HP pool (stability, not balance).
##   godot --headless --path . --script res://tests/tools/soak_runs.gd -- [seeds=20]

const MAIN_PATH := "res://scenes/Main.tscn"
const SLOT := 92
const FIGHT_SEC := 4.0
const HUGE_HP := 1000000
const BOSS_FLOORS: Array[int] = [3, 5]
## Real seconds sampled at time_scale 1 on each floor's peak for the frame time.
const FRAME_SAMPLE_SEC := 2.0

var failures: Array[String] = []
var _main: Main
var _probe: ErrorProbe
var _report := {"seeds": [], "node_counts": {}, "frame": {}}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if not args.is_empty() else 20
	_probe = ErrorProbe.install()
	await process_frame
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_main = (load(MAIN_PATH) as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _frames(20)
	var save := root.get_node("SaveManager")
	save.load_game(SLOT)
	for s in seeds:
		var t0 := Time.get_ticks_msec()
		var floors := await _play_run(1000 + s * 7919)
		_expect(floors == 5, "seed %d: completed %d/5 floors" % [s, floors])
		_report["seeds"].append({"seed": s, "floors": floors, "sec": (Time.get_ticks_msec() - t0) / 1000.0})
		print("soak seed %d: %d floors, %.1f s, nodes %s" % [s, floors, (Time.get_ticks_msec() - t0) / 1000.0, _report["node_counts"].get(str(1000 + s * 7919), [])])
		Engine.time_scale = 1.0
		await _main.return_to_main_menu()
		await _frames(10)
	_main.queue_free()
	await _frames(10)
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - orphans_before
	if orphans > 0:
		Node.print_orphan_nodes()
	_expect(orphans <= 0, "%d orphan nodes left after %d runs" % [orphans, seeds])
	_check_node_growth(seeds)
	_probe.uninstall()
	for m in _probe.messages:
		failures.append("console: " + m)
	save.delete_save(SLOT)
	_report["failures"] = failures
	var f := FileAccess.open("user://soak_runs.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	for failure in failures.slice(0, 40):
		printerr("FAIL: ", failure)
	print("soak_runs: %s (%d failures) frame %s" % ["OK" if failures.is_empty() else "FAILED", failures.size(), _report["frame"]])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _main2d() -> Node:
	return _main.world_container.get_child(0) if _main.world_container.get_child_count() > 0 else null


func _play_run(run_seed: int) -> int:
	root.get_node("GameSession").set_selection(["warrior", "mage"] as Array[String])
	seed(run_seed)
	await _main.start_gameplay()
	var floors := 0
	for f in range(1, 6):
		if f >= 2:
			_record_nodes(run_seed, f)
			if not await _save_and_continue(f):
				return floors
		if not await _play_floor(f, run_seed):
			return floors
		floors += 1
	return floors


## Back to the menu and "Continuar": the same floor comes back with the same party and seed.
func _save_and_continue(f: int) -> bool:
	var save := root.get_node("SaveManager")
	var saved: Dictionary = save.get_saved_run(SLOT)
	_expect(int(saved.get("floor", 0)) == f, "floor %d start not saved (%s)" % [f, saved.get("floor")])
	var run_seed := _main.run_seed
	var party: Array = _main2d().heroes.map(func(h: Player) -> String: return h.stats.hero_id)
	await _main.return_to_main_menu()
	await _frames(5)
	if not await _main.continue_run():
		_expect(false, "floor %d: continue_run found no save" % f)
		return false
	while _main._is_transitioning:
		await process_frame
	await _frames(5)
	var main2d := _main2d()
	var ok: bool = main2d != null and main2d.floor_manager.floor_index == f and _main.run_seed == run_seed
	_expect(ok, "floor %d: continue gave floor %s seed %s (want %d / %d)" % [f, main2d.floor_manager.floor_index if main2d else -1, _main.run_seed, f, run_seed])
	if ok:
		var now: Array = main2d.heroes.map(func(h: Player) -> String: return h.stats.hero_id)
		_expect(now == party, "floor %d: continued party %s, want %s" % [f, now, party])
	return ok


func _record_nodes(run_seed: int, f: int) -> void:
	var key := str(run_seed)
	if not _report["node_counts"].has(key):
		_report["node_counts"][key] = []
	_report["node_counts"][key].append([f, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])


## Node counts at the floor-2 start must not climb from one seed to the next (a leak would).
func _check_node_growth(seeds: int) -> void:
	var at_two: Array[int] = []
	for key in _report["node_counts"]:
		for pair in _report["node_counts"][key]:
			if pair[0] == 2:
				at_two.append(pair[1])
	if at_two.size() < 3:
		return
	var first_half := 0.0
	var second_half := 0.0
	var half := at_two.size() / 2
	for i in at_two.size():
		if i < half:
			first_half += at_two[i]
		else:
			second_half += at_two[i]
	first_half /= half
	second_half /= at_two.size() - half
	_report["floor2_nodes"] = {"first_half": first_half, "second_half": second_half, "all": at_two}
	_expect(second_half <= first_half * 1.05 + 20, "nodes at floor-2 start grow across seeds: %.0f -> %.0f %s" % [first_half, second_half, at_two])


func _tough() -> void:
	var main2d := _main2d()
	if main2d == null:
		return
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


## Frame time at time_scale 1 with the floor's live enemies; kept if it is the busiest so far.
func _sample_frames(f: int) -> void:
	var enemies := ManagerLocator.get_enemy_manager()
	var alive := enemies.alive_count() if enemies else 0
	var times: Array[float] = []
	var cpu: Array[float] = []
	var last := Time.get_ticks_usec()
	var end := Time.get_ticks_msec() + int(FRAME_SAMPLE_SEC * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		_tough()
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		cpu.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		last = now
	times.sort()
	cpu.sort()
	if times.is_empty():
		return
	var cpu_mean := 0.0
	for t in cpu:
		cpu_mean += t
	cpu_mean /= cpu.size()
	var mean := 0.0
	for t in times:
		mean += t
	mean /= times.size()
	if alive >= int(_report["frame"].get("enemies", -1)):
		_report["frame"] = {"floor": f, "enemies": alive, "mean_ms": snappedf(mean, 0.01), "p95_ms": snappedf(times[int(times.size() * 0.95)], 0.01), "max_ms": snappedf(times[-1], 0.01), "frames": times.size(),
			"cpu_mean_ms": snappedf(cpu_mean, 0.01), "cpu_p95_ms": snappedf(cpu[int(cpu.size() * 0.95)], 0.01), "cpu_max_ms": snappedf(cpu[-1], 0.01)}


func _play_floor(f: int, run_seed: int) -> bool:
	await _frames(5)
	var main2d := _main2d()
	if main2d == null or main2d.floor_manager.floor_index != f:
		_expect(false, "seed %d floor %d did not boot" % [run_seed, f])
		return false
	_tough()
	var rm: RoomManager = main2d.room_manager
	var doors: DoorTurnSystem = main2d.door_turn_system
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
	await _fight(FIGHT_SEC)
	var gsm := ManagerLocator.get_game_state_manager()
	if not gsm.is_active():
		_expect(false, "seed %d floor %d: left ACTIVE while exploring (%s)" % [run_seed, f, gsm.current_state])
		return false
	var hero: Player = main2d.heroes[0]
	hero.set_zone(rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()), main2d.floor_layer)
	hero.pick_up_relic()
	ManagerLocator.get_extraction_manager().start_extraction()
	await _fight(FIGHT_SEC)
	await _sample_frames(f)
	var enemies := ManagerLocator.get_enemy_manager()
	_expect(enemies.alive_count() <= main2d.floor_manager.max_enemies() + 1, "seed %d floor %d: enemy cap exceeded (%d)" % [run_seed, f, enemies.alive_count()])
	_expect(enemies.is_boss_alive() == BOSS_FLOORS.has(f), "seed %d floor %d: boss alive = %s" % [run_seed, f, enemies.is_boss_alive()])
	if enemies.is_boss_alive():
		enemies.boss.take_damage(enemies.boss.current_hp)
		await _frames(5)
	Engine.time_scale = 4.0
	await main2d.player_action_controller.move_heroes([hero] as Array[Player], rm.get_exit_zone_id())
	Engine.time_scale = 1.0
	await _frames(20)
	if gsm.current_state != GameStateManager.State.VICTORY:
		_expect(false, "seed %d floor %d: the carrier did not win (state %s)" % [run_seed, f, gsm.current_state])
		return false
	if f < 5:
		await _main.advance_floor()
	return true

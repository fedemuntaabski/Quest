extends SceneTree

## Session calidad-13: performance bench. Worst case of the run: floor 5, Difícil,
## 4 heroes (co-op of 4, PlayerScaling row 4), every room revealed, the live enemy
## cap kept full (refilled every second), heroes and Relic kept alive.
## Measures SAMPLE_SEC at 1x and at 2x: frame time p50/p95/p99/max, mean FPS,
## Performance monitors (process/physics time, nodes, draw calls), plus timed
## micro-benchmarks of the hot helpers (group lookups, zone pathfinding, snapshot).
##   Real window (render included; VSync off, no FPS cap to see the headroom):
##   godot --path . --script res://tests/tools/bench_floor5.gd -- <tag>
##   Logic only:  godot --headless --path . --script res://tests/tools/bench_floor5.gd -- <tag>
## Writes docs/perf/<tag>.csv and prints a markdown table.

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const SAMPLE_SEC := 30.0
const WARMUP_SEC := 3.0
const HEROES := ["warrior", "mage", "rogue", "tank"]
const PLAYERS := 4
const OUT_DIR := "res://docs/perf"

var _main2d: Node
var _frames: Array[float] = []
var _monitors := {}
var _last_usec := 0
var _rows: Array[Dictionary] = []
var _spike_log: Array[String] = []
var _refilled_last := false
const SPIKE_MS := 50.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := args[0] if not args.is_empty() else "bench"
	var headless := DisplayServer.get_name() == "headless"
	await process_frame  # after SettingsManager applied the saved video settings
	if not headless:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _boot()
	for speed in ([2.0, 1.0] if "reverse" in args else [1.0, 2.0]):
		await _sample(speed, headless)
	_micro()
	Engine.time_scale = 1.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var file := FileAccess.open("%s/%s.csv" % [OUT_DIR, tag], FileAccess.WRITE)
	file.store_string(BalanceSim.to_csv(_rows))
	file.close()
	print(BalanceSim.to_markdown(_rows))
	_main2d.queue_free()
	await process_frame
	quit(0)


func _boot() -> void:
	var session := root.get_node("GameSession")
	session.difficulty = "hard"
	seed(5)
	_main2d = (load(MAIN2D_PATH) as PackedScene).instantiate()
	_main2d.standalone_floor = 5
	root.add_child(_main2d)
	await process_frame
	var fm: FloorManager = _main2d.floor_manager
	fm.players = PLAYERS
	var rm: RoomManager = _main2d.room_manager
	var start := rm.get_start_zone_id()
	for id in HEROES:
		if _main2d.heroes.size() < PLAYERS and not _main2d.heroes.any(func(h: Player) -> bool: return h.character_data.character_id == id):
			_main2d.recruit_hero(id, start)
	var doors: DoorTurnSystem = _main2d.door_turn_system
	for group_id in doors.rooms.keys():
		doors.rooms[group_id]["visited"] = true
	rm.refresh_visibility()
	# spread the heroes over the map so enemies path everywhere
	_keep_alive()
	var rooms := rm.get_dark_rooms()
	for i in _main2d.heroes.size():
		if i < rooms.size():
			var hero: Player = _main2d.heroes[i]
			hero.set_zone(rooms[i].zone_id, rm.get_center(rooms[i].zone_id), _main2d.floor_layer)
	print("bench: floor %d, %s, %d heroes, cap %d enemies, %d zones" % [fm.floor_index, fm.difficulty.id, _main2d.heroes.size(), fm.max_enemies(), rm.zones.size()])


## Heroes and Relic get a huge HP pool (a defeat would pause the tree and the
## rest of the sample would measure an idle game).
const BENCH_HP := 1000000


func _keep_alive() -> void:
	for hero: Player in _main2d.heroes:
		if is_instance_valid(hero) and hero.stats:
			hero.stats.max_hp = BENCH_HP
			hero.stats.current_hp = BENCH_HP
	var relic := ManagerLocator.get_relic()
	if relic:
		relic.max_hp = BENCH_HP
		relic.current_hp = BENCH_HP
	var em: EnemyManager = _main2d.enemy_manager
	var missing: int = _main2d.floor_manager.max_enemies() - em.alive_count()
	if missing > 0:
		em.spawn_wave(missing)


func _sample(speed: float, headless: bool) -> void:
	Engine.time_scale = speed
	var t := 0.0
	var refill := 0.0
	_frames.clear()
	_monitors = {"process_ms": 0.0, "physics_ms": 0.0, "nodes": 0.0, "draw_calls": 0.0, "enemies": 0.0}
	_last_usec = Time.get_ticks_usec()
	var counted := 0
	var spikes := 0
	_spike_log.clear()
	while t < WARMUP_SEC + SAMPLE_SEC:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - _last_usec) / 1000.0
		_last_usec = now
		t += dt / 1000.0
		refill += dt / 1000.0
		var refilled := false
		if refill >= 1.0:
			refill = 0.0
			var before: int = _main2d.enemy_manager.alive_count()
			_keep_alive()
			refilled = _main2d.enemy_manager.alive_count() > before
		if t < WARMUP_SEC:
			continue
		if dt > SPIKE_MS:
			spikes += 1
			if _spike_log.size() < 12:
				_spike_log.append("t=%.1fs %.0fms%s" % [t, dt, " (after refill)" if _refilled_last else ""])
		_refilled_last = refilled
		_frames.append(dt)
		counted += 1
		_monitors["process_ms"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_monitors["physics_ms"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_monitors["nodes"] += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		_monitors["draw_calls"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_monitors["enemies"] += _main2d.enemy_manager.alive_count()
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in _frames:
		total += f
	var n := maxi(counted, 1)
	_rows.append({
		"case": "%s %.0fx" % ["headless" if headless else "window", speed],
		"frames": counted,
		"fps_mean": snappedf(1000.0 * counted / maxf(total, 0.001), 0.1),
		"frame_p50_ms": snappedf(_pct(sorted, 0.50), 0.01),
		"frame_p95_ms": snappedf(_pct(sorted, 0.95), 0.01),
		"frame_p99_ms": snappedf(_pct(sorted, 0.99), 0.01),
		"frame_max_ms": snappedf(sorted[-1] if not sorted.is_empty() else 0.0, 0.01),
		"process_ms": snappedf(_monitors["process_ms"] / n, 0.01),
		"physics_ms": snappedf(_monitors["physics_ms"] / n, 0.01),
		"nodes": roundi(_monitors["nodes"] / n),
		"draw_calls": roundi(_monitors["draw_calls"] / n),
		"enemies": snappedf(_monitors["enemies"] / n, 0.1),
		"spikes_over_50ms": spikes,
	})
	var gsm := ManagerLocator.get_game_state_manager()
	if gsm and not gsm.is_active():
		push_error("bench: the run is no longer ACTIVE (state %s): the sample is invalid" % gsm.current_state)
	print("spikes %.0fx: %s" % [speed, ", ".join(_spike_log)])


static func _pct(sorted: Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(q * (sorted.size() - 1)), 0, sorted.size() - 1)]


## Hot helpers timed in isolation (usec per call, mean of N).
func _micro() -> void:
	var rm: RoomManager = _main2d.room_manager
	var ids: Array = rm.zones.keys()
	var micro := {}
	micro["ManagerLocator.get_room_manager"] = _time(10000, func() -> void: ManagerLocator.get_room_manager())
	micro["ManagerLocator.get_heroes"] = _time(10000, func() -> void: ManagerLocator.get_heroes())
	micro["ManagerLocator.get_relic"] = _time(10000, func() -> void: ManagerLocator.get_relic())
	micro["RoomManager.find_zone_path"] = _time(2000, func() -> void: rm.find_zone_path(ids[randi() % ids.size()], ids[randi() % ids.size()]))
	micro["EnemyManager.get_enemies"] = _time(10000, func() -> void: _main2d.enemy_manager.get_enemies())
	var sync := NetSync.new()
	sync.main2d = _main2d
	micro["NetSync.capture_snapshot"] = _time(500, func() -> void: sync.capture_snapshot())
	sync.free()
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	micro["FloatingTextManager.spawn_text"] = _time(300, func() -> void: text_mgr.spawn_text(Vector2.ZERO, "-1", Color.WHITE))
	micro["Projectile.new+add+free"] = _time(300, func() -> void:
		var p := Projectile.new()
		_main2d.add_child(p)
		p.free())
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		micro["VfxManager.hit"] = _time(200, func() -> void: vfx.hit(Vector2.ZERO, Vector2(10, 0), Color.WHITE, 1, 100))
	if vfx:
		micro["VfxManager.play death_dust"] = _time(50, func() -> void: vfx.play(&"death_dust", Vector2.ZERO, Color.WHITE))
	var bestiary := ManagerLocator.get_bestiary()
	var goblin := load("res://resources/enemies/goblin.tres") as EnemyType
	micro["BestiaryService.register_kill"] = _time(50, func() -> void: bestiary.register_kill(goblin, 5))
	micro["QuestLogger.info"] = _time(200, func() -> void: QuestLogger.info(QuestLogger.Category.ENEMY, "bench line"))
	var hero: Player = _main2d.heroes[0]
	micro["CharacterStats.take_damage (hero)"] = _time(200, func() -> void: hero.stats.take_damage(1))
	var em: EnemyManager = _main2d.enemy_manager
	var victims := em.get_enemies().duplicate()
	micro["Enemy.take_damage (no kill)"] = _time(200, func() -> void:
		for e in victims:
			if is_instance_valid(e):
				e.current_hp = 1000000
				e.take_damage(1)
				return)
	var kills := 0
	var t0 := Time.get_ticks_usec()
	for e in victims:
		if is_instance_valid(e):
			e.current_hp = 1
			e.take_damage(5)
			kills += 1
	micro["Enemy.take_damage (kill)"] = float(Time.get_ticks_usec() - t0) / maxi(kills, 1)
	for key in micro:
		_rows.append({"case": "micro " + key, "frames": 0, "fps_mean": 0.0, "frame_p50_ms": 0.0, "frame_p95_ms": 0.0, "frame_p99_ms": 0.0,
			"frame_max_ms": 0.0, "process_ms": snappedf(micro[key], 0.01), "physics_ms": 0.0, "nodes": 0, "draw_calls": 0, "enemies": 0.0, "spikes_over_50ms": 0})


## Mean microseconds per call.
static func _time(n: int, fn: Callable) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		fn.call()
	return float(Time.get_ticks_usec() - t0) / n

extends SceneTree

## mazmorra-32: cost of the room lights (flames + wall shadows). Real window, GL Compatibility, vsync off.
##   godot --path . --script res://tests/tools/bench_luz.gd -- <off|A|B|C|shipped> [720|1080]
## (the frame time can sit on the 60 Hz cap if the driver forces vsync: read "render cpu/gpu" then)
## Floor 3 seed 22, every room open and lit, 4 heroes, a wave of 12 enemies in the start room; the camera
## sees the whole map (every light on screen = worst case). Prints the mean / p95 frame time over 600 frames.
## "off" = no flames and no shadows (the cost before mazmorra-32); "shipped" = map_visual_config.tres as is.
const VARIANTS := {
	"off": {"room_light_shadows": false, "flame_shadows": false},
	"A": {"lit_fill_alpha": 0.10, "flame_energy": 0.6, "room_light_shadows": true, "flame_shadows": false},
	"B": {"lit_fill_alpha": 0.0, "flame_energy": 0.9, "room_light_shadows": true, "flame_shadows": true},
	"C": {"lit_fill_alpha": 0.15, "flame_energy": 0.5, "room_light_shadows": false, "flame_shadows": false},
	"shipped": {},
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "shipped"
	var size := Vector2i(1280, 720) if args.size() > 1 and args[1] == "720" else Vector2i(1920, 1080)
	var cfg := load("res://resources/maps/map_visual_config.tres") as MapVisualConfig
	for key in VARIANTS[mode]:
		cfg.set(key, VARIANTS[mode][key])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	for i in 20:
		await process_frame
	root.size = size
	seed(22)
	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.standalone_floor = 3
	root.add_child(main2d)
	await process_frame
	var rm: RoomManager = main2d.room_manager
	var start := rm.get_start_zone_id()
	for id in ["warrior", "mage", "rogue", "tank"]:
		if main2d.heroes.size() < 4 and not main2d.heroes.any(func(h: Player) -> bool: return h.stats.hero_id == id):
			main2d.recruit_hero(id, start)
	var doors: DoorTurnSystem = main2d.door_turn_system
	var opened := true
	while opened:
		opened = false
		for g in rm.get_group_ids():
			if not doors.is_room_visited(g) and doors.open_room(g):
				opened = true
	var bounds := Rect2()
	var flames := 0
	for zone_id in rm.get_zone_ids():
		var rect: Rect2i = rm.get_zone(zone_id)["rect"]
		bounds = bounds.merge(Rect2(Vector2(rect.position) * 64.0, Vector2(rect.size) * 64.0))
		var node := rm.get_zone_node(zone_id)
		if node and node.kind == "room":
			node.apply_light(true, 0)
			if mode == "off":
				for flame in node.get_light().get_flames():
					flame.queue_free()
				node.get_light().get_flames().clear()
			flames += node.get_light().get_flames().size()
	for i in 12:  # a wave past the floor cap
		main2d.enemy_manager._spawn_enemy(start, rm.get_center(start) + Vector2.from_angle(i * TAU / 12.0) * 90.0, null, true)
	var camera := Camera2D.new()
	main2d.add_child(camera)
	camera.make_current()
	camera.position = bounds.get_center()
	camera.zoom = Vector2.ONE * minf(size.x / bounds.size.x, size.y / bounds.size.y)
	await create_timer(2.0).timeout
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var gpu := 0.0
	var cpu := 0.0
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 600:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	times.sort()
	var mean := 0.0
	for t in times:
		mean += t
	mean /= times.size()
	print("bench_luz %s %dx%d: %d flames, %d enemies, frame mean %.2f ms p95 %.2f ms, render cpu %.3f ms gpu %.3f ms, vsync %d (%s)" % [mode, size.x, size.y, flames, main2d.enemy_manager.alive_count(), mean, times[int(times.size() * 0.95)], cpu / times.size(), gpu / times.size(), DisplayServer.window_get_vsync_mode(), RenderingServer.get_video_adapter_name()])
	quit()

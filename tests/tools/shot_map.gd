extends SceneTree

## Visual check (needs a real window, NOT --headless): boots Main2d, opens every
## door, frames the whole map and saves a PNG. Run:
##   godot --path . --script res://tests/tools/shot_map.gd -- <out.png> [full|close] [fallback]
## "close" frames the start room and its neighbours at a readable zoom;
## "sprites" lines up every enemy type of every floor pool above the start room.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shot_map.png"
	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = args.size() > 2
	var sprites: bool = args.size() > 1 and args[1] == "sprites"
	var close: bool = sprites or (args.size() > 1 and args[1] == "close")
	root.add_child(main2d)
	await process_frame
	var doors: DoorTurnSystem = main2d.door_turn_system
	var opened := true
	while opened:
		opened = false
		for group_id in main2d.room_manager.get_group_ids():
			if not doors.is_room_visited(group_id) and doors.open_room(group_id):
				opened = true
	for door in main2d.room_manager.get_all_doors():
		door.disable_door()
	main2d.room_manager.refresh_door_visibility()
	if sprites:
		_lineup(main2d)
	var bounds := Rect2()
	for zone_id in main2d.room_manager.get_zone_ids():
		var rect: Rect2i = main2d.room_manager.get_zone(zone_id)["rect"]
		bounds = bounds.merge(Rect2(Vector2(rect.position) * 64.0, Vector2(rect.size) * 64.0))
	bounds = bounds.grow(96.0)
	var camera := Camera2D.new()
	main2d.add_child(camera)
	camera.position = bounds.get_center()
	camera.zoom = Vector2.ONE * minf(1600.0 / bounds.size.x, 900.0 / bounds.size.y)
	if close:
		camera.position = main2d.room_manager.get_center(main2d.room_manager.get_start_zone_id()) + Vector2(0, -160)
		camera.zoom = Vector2.ONE * 2.2
	camera.make_current()
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out, " bounds ", bounds)
	quit()


## One row per floor pool, evenly spaced across the start room; AI stopped so they stand still.
func _lineup(main2d: Node) -> void:
	var config := main2d.floor_manager.config as FloorConfig
	var origin: Vector2 = main2d.room_manager.get_center(main2d.room_manager.get_start_zone_id()) + Vector2(-120, -100)
	for row in config.enemy_pools.size():
		var pool := config.enemy_pools[row]
		for i in pool.types.size():
			var enemy := (load("res://scenes/entities/Enemy.tscn") as PackedScene).instantiate() as Enemy
			main2d.add_child(enemy)
			enemy.setup(origin + Vector2(i * 48, -row * 56))
			enemy.configure(Enemy.Variant.SWARM, "start", 1.0, 1.0, pool.types[i])
			enemy.ai_timer.stop()

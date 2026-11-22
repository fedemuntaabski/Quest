extends SceneTree

## mazmorra-31: before/after shots of the drawn dungeon (needs a real window, NOT --headless).
##   godot --path . --script res://tests/tools/shot_mazmorra.gd -- <out_dir> <seed> <floor> [720|1080]
## Writes <out_dir>/s<seed>_f<floor>_{full,lit,close}.png: whole map with every door
## open (rooms dark, as played), the same with every room lit, and the start room up close.
## Enemies are removed so only the map shows. seed() fixes Main2d's standalone run seed.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var run_seed := int(args[1]) if args.size() > 1 else 1
	var floor_index := int(args[2]) if args.size() > 2 else 1
	var size := Vector2i(1280, 720) if args.size() > 3 and args[3] == "720" else Vector2i(1920, 1080)
	root.mode = Window.MODE_WINDOWED
	for i in 20:  # the mode change resizes the window late (as in shot_barrido)
		await process_frame
	root.size = size
	seed(run_seed)
	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.standalone_floor = floor_index
	root.add_child(main2d)
	await process_frame
	var rm: RoomManager = main2d.room_manager
	var doors: DoorTurnSystem = main2d.door_turn_system
	var opened := true
	while opened:
		opened = false
		for group_id in rm.get_group_ids():
			if not doors.is_room_visited(group_id) and doors.open_room(group_id):
				opened = true
	for door in rm.get_all_doors():
		door.disable_door()
	rm.refresh_door_visibility()
	var bounds := Rect2()
	for zone_id in rm.get_zone_ids():
		var rect: Rect2i = rm.get_zone(zone_id)["rect"]
		bounds = bounds.merge(Rect2(Vector2(rect.position) * 64.0, Vector2(rect.size) * 64.0))
	bounds = bounds.grow(96.0)
	var camera := Camera2D.new()
	main2d.add_child(camera)
	camera.make_current()
	var prefix := out_dir.path_join("s%d_f%d_" % [run_seed, floor_index])
	_clear_enemies(main2d)
	camera.position = bounds.get_center()
	camera.zoom = Vector2.ONE * minf(size.x / bounds.size.x, size.y / bounds.size.y)
	await _save(prefix + "full.png", main2d)
	camera.position = rm.get_center(rm.get_start_zone_id())
	camera.zoom = Vector2.ONE * 1.6 * size.y / 720.0
	await _save(prefix + "close.png", main2d)
	for zone_id in rm.get_zone_ids():
		var node := rm.get_zone_node(zone_id)
		if node and node.kind == "room":
			node.apply_light(true, 0)
	await create_timer(1.0).timeout
	camera.position = bounds.get_center()
	camera.zoom = Vector2.ONE * minf(size.x / bounds.size.x, size.y / bounds.size.y)
	await _save(prefix + "lit.png", main2d)
	if args.size() > 4 and args[4] == "types":
		await _type_shots(main2d, camera, prefix, size)
	print("saved ", prefix)
	quit()


## "types": one close shot per room type present (lit), named <prefix>type_<TYPE>.png.
func _type_shots(main2d: Node, camera: Camera2D, prefix: String, size: Vector2i) -> void:
	var done := {}
	for room: RoomData in main2d.map_layout.rooms:
		var type_name: String = RoomData.RoomType.keys()[room.get_room_type()]
		if done.has(type_name):
			continue
		done[type_name] = true
		camera.position = main2d.room_manager.get_center(room.id)
		camera.zoom = Vector2.ONE * 2.4 * size.y / 720.0
		await _save(prefix + "type_%s.png" % type_name, main2d)


func _save(path: String, main2d: Node) -> void:
	for i in 8:
		_clear_enemies(main2d)
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)


func _clear_enemies(node: Node) -> void:
	for child in node.get_children():
		if child is Enemy:
			child.queue_free()
		else:
			_clear_enemies(child)

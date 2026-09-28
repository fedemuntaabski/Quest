extends SceneTree

## Headless click-coverage check (session 5, bug 2: a 4-tile corridor only
## took clicks on 3 tiles). Boots Main2d on several seeds/floors + fallback,
## then physics-queries the center of every cell:
##   - closed door cell      -> its Door (and no RoomZone)
##   - opened corridor cells -> that corridor's RoomZone only, incl. door cell
##   - room edge cells       -> that room's RoomZone only
##   godot --headless --path . --script res://tests/test_corridor_picking.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const SEEDS := [1, 7, 42, 1234, 99991]

var failures: Array[String] = []


func _initialize() -> void:
	for floor_index in range(1, 6):
		for s in SEEDS:
			await _run("seed %d floor %d" % [s, floor_index], s, floor_index, false)
	await _run("fallback", 0, 1, true)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_corridor_picking: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _run(label: String, s: int, floor_index: int, use_fallback: bool) -> void:
	seed(s)  # Main2d rolls randi() for the map seed when run without Main.
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = use_fallback
	main2d.standalone_floor = floor_index
	root.add_child(main2d)
	await _physics_settle()

	var room_manager: RoomManager = main2d.room_manager
	var layout: MapLayout = main2d.map_layout
	var tile := Vector2(main2d.floor_layer.tile_set.tile_size)

	# Closed doors reachable from the start: the door cell belongs to the Door.
	for door in room_manager.get_all_doors():
		if room_manager.is_zone_revealed(door.from_zone_id):
			_expect_cell(main2d, room_manager, tile, door.cell, door, "%s closed door '%s'" % [label, door.door_id])

	_open_everything(main2d, room_manager)
	await _physics_settle()

	for corridor in layout.corridors:
		var zone := room_manager.get_zone_node(corridor.id)
		var rect := corridor.get_zone_rect()
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var where := "door cell" if Vector2i(x, y) == corridor.door_cell else "cell"
				_expect_cell(main2d, room_manager, tile, Vector2i(x, y), zone, "%s corridor '%s' %s" % [label, corridor.id, where])
	for room in layout.rooms:
		var zone := room_manager.get_zone_node(room.id)
		var rect := room.get_rect()
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var edge := x == rect.position.x or y == rect.position.y or x == rect.end.x - 1 or y == rect.end.y - 1
				if edge:
					_expect_cell(main2d, room_manager, tile, Vector2i(x, y), zone, "%s room '%s' edge" % [label, room.id])

	main2d.queue_free()
	await process_frame


func _open_everything(main2d: Node, room_manager: RoomManager) -> void:
	var progress := true
	while progress:
		progress = false
		for door in room_manager.get_all_doors():
			if door.is_open or not room_manager.is_zone_revealed(door.from_zone_id):
				continue
			main2d.door_turn_system.open_room(door.target_room_id)
			door.disable_door()
			progress = true


## `expected` (RoomZone or Door) must cover the cell center, be pickable, and
## be the only RoomZone/Door there.
func _expect_cell(main2d: Node2D, room_manager: RoomManager, tile: Vector2, cell: Vector2i, expected: Area2D, what: String) -> void:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = room_manager.to_global((Vector2(cell) + Vector2(0.5, 0.5)) * tile)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := main2d.get_world_2d().direct_space_state.intersect_point(params, 32)
	var found := false
	var others: Array[String] = []
	for hit in hits:
		var node: Object = hit["collider"]
		if node == expected:
			found = true
		elif node is RoomZone or node is Door:
			others.append((node as Node).name)
	if not found:
		var covering: Array[String] = []
		for hit in hits:
			covering.append((hit["collider"] as Node).name)
		failures.append("%s %s: not covered by '%s'; covered by %s" % [what, cell, expected.name, covering])
	elif not expected.input_pickable:
		failures.append("%s %s: '%s' covers it but input_pickable=false" % [what, cell, expected.name])
	if not others.is_empty():
		failures.append("%s %s: also covered by %s (click ambiguity)" % [what, cell, others])


func _physics_settle() -> void:
	for i in 3:
		await physics_frame

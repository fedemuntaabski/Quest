extends SceneTree

## Door centering (session fix-3). The door leaf used to be a 2x2 atlas tile that
## Godot draws centered on its origin cell, so it hung ~half a cell up-left of
## the corridor lane. Now the leaf is a Sprite2D child of Door. Checks, over
## generated maps (25 seed x floor) + the fallback, on the live Main2d:
##   - door center == corridor lane (cross axis) within 1 px
##   - door cell hugs room_a's wall (outside its rect, 1 cell away)
##   - Leaf sprite center == door center, corridor click shape covers the door cell
##   - all 4 orientations were seen; closed and open leaf share the same center
## Plus a pure pass over 1000 generated layouts (no scene): every corridor's
## cross-axis lane crosses the middle of both rooms it joins.
##   godot --headless --path . --script res://tests/test_door_alignment.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const SEEDS := [1, 7, 42, 1234, 99991]
const TOLERANCE := 1.0

var failures: Array[String] = []
var orientations: Dictionary = {}  # "E"/"W"/"N"/"S" -> count


func _initialize() -> void:
	_check_generated_lanes()
	for floor_index in range(1, 6):
		for s in SEEDS:
			await _run("seed %d floor %d" % [s, floor_index], s, floor_index, false)
	await _run("fallback", 0, 1, true)
	for dir in ["E", "W", "N", "S"]:
		if not orientations.has(dir):
			failures.append("no door heading %s in any map: orientation untested" % dir)
	print("test_door_alignment: orientations %s" % [orientations])
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_door_alignment: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


## Pure: the lane of every corridor passes through the middle cell of both rooms.
func _check_generated_lanes() -> void:
	for s in 1000:
		var layout := MapGenerator.generate(s, 8, 0.3)
		for corridor in layout.corridors:
			var room_a := layout.get_room(corridor.room_a)
			var room_b := layout.get_room(corridor.room_b)
			var cross := 1 if corridor.is_east_west(room_a) else 0
			if corridor.door_cell[cross] != corridor.pos[cross]:
				failures.append("seed %d %s: door lane %d != corridor lane %d" % [s, corridor.id, corridor.door_cell[cross], corridor.pos[cross]])
			for room in [room_a, room_b]:
				if room.pos[cross] + room.size[cross] / 2 != corridor.pos[cross]:
					failures.append("seed %d %s: lane %d misses the middle of '%s'" % [s, corridor.id, corridor.pos[cross], room.id])


func _run(label: String, s: int, floor_index: int, use_fallback: bool) -> void:
	seed(s)
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = use_fallback
	main2d.standalone_floor = floor_index
	root.add_child(main2d)
	await physics_frame

	var room_manager: RoomManager = main2d.room_manager
	var layout: MapLayout = main2d.map_layout
	var tile := Vector2(main2d.floor_layer.tile_set.tile_size)
	for corridor in layout.corridors:
		var where := "%s '%s'" % [label, corridor.id]
		var door: Door = null
		for candidate in room_manager.get_all_doors():
			if candidate.door_id == corridor.id:
				door = candidate
		if door == null:
			failures.append("%s: no Door node" % where)
			continue
		var room_a := layout.get_room(corridor.room_a)
		var east_west := corridor.is_east_west(room_a)
		var zone_rect := corridor.get_zone_rect()
		var lane_center := (Vector2(zone_rect.position) + Vector2(zone_rect.size) / 2.0) * tile
		var zone_pos := room_manager.get_zone_node(corridor.id).global_position
		var door_pos := door.global_position
		var cross := 1 if east_west else 0
		if absf(door_pos[cross] - lane_center[cross]) > TOLERANCE or absf(door_pos[cross] - zone_pos[cross]) > TOLERANCE:
			failures.append("%s: door %s off the corridor lane %s (zone %s)" % [where, door_pos, lane_center, zone_pos])
		# Longitudinal: the cell right outside room_a's wall.
		var axis := 1 - cross
		var rect := room_a.get_rect()
		var gap: int = (rect.position[axis] - corridor.door_cell[axis]) if corridor.door_cell[axis] < rect.position[axis] else (corridor.door_cell[axis] - (rect.end[axis] - 1))
		if gap != 1 or door.cell != corridor.door_cell:
			failures.append("%s: door cell %s not hugging room_a '%s' wall (gap %d)" % [where, corridor.door_cell, room_a.id, gap])
		var expected_pos := (Vector2(corridor.door_cell) + Vector2(0.5, 0.5)) * tile
		if door_pos.distance_to(expected_pos) > TOLERANCE:
			failures.append("%s: door %s != center of its cell %s" % [where, door_pos, expected_pos])
		# Leaf follows the door, closed and open.
		for open in [false, true]:
			door.set_leaf(open)
			if door.leaf.global_position.distance_to(door_pos) > TOLERANCE:
				failures.append("%s: leaf %s != door %s (open=%s)" % [where, door.leaf.global_position, door_pos, open])
		door.set_leaf(false)
		var atlas := door.leaf.texture as AtlasTexture
		if atlas == null or door.leaf.texture.get_size() != Door.LEAF_PX:
			failures.append("%s: leaf texture is not a %s region" % [where, Door.LEAF_PX])
		# Click shape sits inside the corridor's zone rect and on the door center.
		var shape_node := door.get_node("CollisionShape2D") as CollisionShape2D
		if shape_node.global_position.distance_to(door_pos) > TOLERANCE:
			failures.append("%s: click shape %s != door %s" % [where, shape_node.global_position, door_pos])
		if not Rect2(Vector2(zone_rect.position) * tile, Vector2(zone_rect.size) * tile).has_point(door_pos):
			failures.append("%s: door %s outside the corridor zone" % [where, door_pos])
		var heading := "E" if east_west and room_a.pos.x < corridor.door_cell.x else "W" if east_west else "S" if room_a.pos.y < corridor.door_cell.y else "N"
		orientations[heading] = int(orientations.get(heading, 0)) + 1
		if door.east_west != east_west:
			failures.append("%s: Door.east_west %s != %s" % [where, door.east_west, east_west])
		var flipped := door.leaf.transform.x.is_equal_approx(Vector2(0, ArtConfig.ART_SCALE))
		if flipped != east_west:
			failures.append("%s: leaf transposed=%s but corridor east_west=%s" % [where, flipped, east_west])

	main2d.queue_free()
	await process_frame

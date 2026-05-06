extends RefCounted
class_name DungeonLayoutGenerator

var dungeon: DungeonGenerator

func setup(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon


func generate() -> bool:
	const LAYOUT_RETRIES := 32

	for _retry in range(LAYOUT_RETRIES):
		dungeon._clear_generated_content()
		dungeon.floor_cells.clear()
		dungeon.wall_cells.clear()
		dungeon.wall_nodes.clear()
		dungeon.room_infos.clear()

		var attempts := dungeon.room_count * 90

		while dungeon.room_infos.size() < dungeon.room_count and attempts > 0:
			attempts -= 1

			var room_size := _roll_room_size()

			var max_x := dungeon.grid_width - room_size.x - dungeon.room_padding - 1
			var max_y := dungeon.grid_height - room_size.y - dungeon.room_padding - 1

			if max_x <= dungeon.room_padding or max_y <= dungeon.room_padding:
				continue

			var room_pos := Vector2i(
				randi_range(dungeon.room_padding, max_x),
				randi_range(dungeon.room_padding, max_y)
			)

			var room_rect := Rect2i(room_pos, room_size)

			if _room_overlaps_existing(room_rect):
				continue

			_register_room(room_rect)

		if dungeon.room_infos.size() == dungeon.room_count:
			_connect_rooms_with_corridors()
			return true

	return false


func _roll_room_size() -> Vector2i:
	var width := randi_range(dungeon.room_min_size.x, dungeon.room_max_size.x)
	var height := randi_range(dungeon.room_min_size.y, dungeon.room_max_size.y)

	var short_width_max := mini(dungeon.room_max_size.x, dungeon.room_min_size.x + 2)
	var short_height_max := mini(dungeon.room_max_size.y, dungeon.room_min_size.y + 2)
	var long_width_min := maxi(dungeon.room_min_size.x, dungeon.room_max_size.x - 4)
	var long_height_min := maxi(dungeon.room_min_size.y, dungeon.room_max_size.y - 4)

	var shape_roll := randf()

	if shape_roll < 0.34:
		width = randi_range(long_width_min, dungeon.room_max_size.x)
		height = randi_range(dungeon.room_min_size.y, short_height_max)
	elif shape_roll < 0.68:
		width = randi_range(dungeon.room_min_size.x, short_width_max)
		height = randi_range(long_height_min, dungeon.room_max_size.y)

	return Vector2i(width, height)


func _room_overlaps_existing(candidate: Rect2i) -> bool:
	var expanded := candidate.grow(dungeon.room_padding)

	for room_info in dungeon.room_infos:
		var other: Rect2i = room_info["rect"]
		if expanded.intersects(other):
			return true

	return false


func _register_room(room_rect: Rect2i) -> void:
	var room_id := dungeon.room_infos.size()

	var room_root := Node2D.new()
	room_root.name = "RoomVisual_%d" % room_id
	room_root.visible = false
	dungeon.rooms_root.add_child(room_root)

	var room_cells: Array[Vector2i] = []

	for x in range(room_rect.position.x, room_rect.end.x):
		for y in range(room_rect.position.y, room_rect.end.y):
			var cell := Vector2i(x, y)
			dungeon.floor_cells[cell] = true
			room_cells.append(cell)

	var center_cell := Vector2i(
		room_rect.position.x + int(room_rect.size.x * 0.5),
		room_rect.position.y + int(room_rect.size.y * 0.5)
	)

	var room_light := dungeon._create_room_light(room_rect, center_cell)
	dungeon.room_lights_root.add_child(room_light)

	var room_area := dungeon._create_room_area(room_id, room_rect)
	dungeon.room_detectors_root.add_child(room_area)

	dungeon.room_infos.append({
		"id": room_id,
		"rect": room_rect,
		"center_cell": center_cell,
		"floor_cells": room_cells,
		"visited": false,
		"visual_root": room_root,
		"light": room_light,
		"area": room_area
	})


func _connect_rooms_with_corridors() -> void:
	if dungeon.room_infos.size() <= 1:
		return

	var sorted_rooms := dungeon.room_infos.duplicate()

	sorted_rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var center_a: Vector2i = a["center_cell"]
		var center_b: Vector2i = b["center_cell"]

		if center_a.x == center_b.x:
			return center_a.y < center_b.y

		return center_a.x < center_b.x
	)

	for index in range(sorted_rooms.size() - 1):
		var from_cell: Vector2i = sorted_rooms[index]["center_cell"]
		var to_cell: Vector2i = sorted_rooms[index + 1]["center_cell"]
		_carve_corridor(from_cell, to_cell)


func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var current := from_cell
	_add_corridor_cell(current)

	if randf() < 0.5:
		while current.x != to_cell.x:
			current.x += signi(to_cell.x - current.x)
			_add_corridor_cell(current)

		while current.y != to_cell.y:
			current.y += signi(to_cell.y - current.y)
			_add_corridor_cell(current)
	else:
		while current.y != to_cell.y:
			current.y += signi(to_cell.y - current.y)
			_add_corridor_cell(current)

		while current.x != to_cell.x:
			current.x += signi(to_cell.x - current.x)
			_add_corridor_cell(current)


func _add_corridor_cell(cell: Vector2i) -> void:
	if not dungeon.is_within_bounds(cell):
		return

	if dungeon.floor_cells.has(cell):
		return

	dungeon.floor_cells[cell] = true
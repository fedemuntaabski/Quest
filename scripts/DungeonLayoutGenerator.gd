extends RefCounted
class_name DungeonLayoutGenerator

var dungeon: DungeonGenerator
var room_connections: Dictionary = {}
var room_adjacency: Dictionary = {}

func setup(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon
	room_connections.clear()
	room_adjacency.clear()


func generate() -> bool:
	const LAYOUT_RETRIES := 32

	for _retry in range(LAYOUT_RETRIES):
		dungeon._clear_generated_content()
		dungeon.floor_cells.clear()
		dungeon.wall_cells.clear()
		dungeon.wall_nodes.clear()
		dungeon.room_infos.clear()
		room_connections.clear()
		room_adjacency.clear()

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
	room_adjacency[room_id] = {}

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

	var unvisited_rooms := dungeon.room_infos.duplicate()
	var main_path: Array[Dictionary] = []

	var current_room: Dictionary = unvisited_rooms[0]
	main_path.append(current_room)
	unvisited_rooms.erase(current_room)

	while unvisited_rooms.size() > 0:
		var current_center: Vector2i = current_room["center_cell"]
		var nearest_room: Dictionary = _find_nearest_room(current_center, unvisited_rooms)

		if nearest_room.is_empty():
			break

		var from_room_id: int = current_room["id"]
		var to_room_id: int = nearest_room["id"]
		var from_cell: Vector2i = current_room["center_cell"]
		var to_cell: Vector2i = nearest_room["center_cell"]

		if not _has_connection(from_room_id, to_room_id):
			_carve_corridor(from_cell, to_cell)
			_register_connection(from_room_id, to_room_id)

		main_path.append(nearest_room)
		unvisited_rooms.erase(nearest_room)
		current_room = nearest_room

	for room_info in main_path:
		room_info["is_main_path"] = true

	if dungeon.main_path_branching and unvisited_rooms.size() > 0:
		for room_info in unvisited_rooms:
			_connect_to_nearest_main_path_room(room_info, main_path)


func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var min_length := dungeon.corridor_min_length
	var max_length := dungeon.corridor_max_length

	var current := from_cell
	var corridor_length := 0
	_add_corridor_cell(current)

	var horizontal_first := randf() < 0.5

	if horizontal_first:
		while current.x != to_cell.x:
			current.x += signi(to_cell.x - current.x)
			_add_corridor_cell(current)
			corridor_length += 1

		while current.y != to_cell.y:
			current.y += signi(to_cell.y - current.y)
			_add_corridor_cell(current)
			corridor_length += 1
	else:
		while current.y != to_cell.y:
			current.y += signi(to_cell.y - current.y)
			_add_corridor_cell(current)
			corridor_length += 1

		while current.x != to_cell.x:
			current.x += signi(to_cell.x - current.x)
			_add_corridor_cell(current)
			corridor_length += 1

	if corridor_length < min_length or corridor_length > max_length:
		push_warning("Corridor length %d outside bounds [%d, %d]. Consider adjusting room placement." % [corridor_length, min_length, max_length])


func _add_corridor_cell(cell: Vector2i) -> void:
	if not dungeon.is_within_bounds(cell):
		return

	if dungeon.floor_cells.has(cell):
		return

	dungeon.floor_cells[cell] = true


func _has_connection(room_a: int, room_b: int) -> bool:
	var key_a := "%d_%d" % [room_a, room_b]
	var key_b := "%d_%d" % [room_b, room_a]
	return room_connections.has(key_a) or room_connections.has(key_b)


func _register_connection(room_a: int, room_b: int) -> void:
	var key := "%d_%d" % [room_a, room_b]
	room_connections[key] = true
	_add_adjacency_link(room_a, room_b)
	_add_adjacency_link(room_b, room_a)


func _add_adjacency_link(room_a: int, room_b: int) -> void:
	if room_a < 0 or room_b < 0:
		return

	if not room_adjacency.has(room_a):
		room_adjacency[room_a] = {}

	room_adjacency[room_a][room_b] = true


func get_connected_room_ids(room_id: int) -> Array[int]:
	var connected: Array[int] = []
	var adjacency: Dictionary = room_adjacency.get(room_id, {})

	for raw_room_id in adjacency.keys():
		connected.append(int(raw_room_id))

	connected.sort()
	return connected


func are_rooms_connected(room_a: int, room_b: int) -> bool:
	var adjacency: Dictionary = room_adjacency.get(room_a, {})
	return adjacency.has(room_b)


func _find_nearest_room(from_center: Vector2i, candidates: Array[Dictionary]) -> Dictionary:
	if candidates.is_empty():
		return {}

	var nearest: Dictionary = {}
	var nearest_dist: float = INF

	for room_info in candidates:
		var room_center: Vector2i = room_info["center_cell"]
		var dist := from_center.distance_squared_to(room_center)

		if dist < nearest_dist:
			nearest_dist = dist
			nearest = room_info

	return nearest


func _connect_to_nearest_main_path_room(room_info: Dictionary, main_path: Array[Dictionary]) -> void:
	var room_center: Vector2i = room_info["center_cell"]
	var nearest_main: Dictionary = _find_nearest_room(room_center, main_path)

	if nearest_main.is_empty():
		return

	var from_room_id: int = room_info["id"]
	var to_room_id: int = nearest_main["id"]
	var from_cell: Vector2i = room_info["center_cell"]
	var to_cell: Vector2i = nearest_main["center_cell"]

	if not _has_connection(from_room_id, to_room_id):
		_carve_corridor(from_cell, to_cell)
		_register_connection(from_room_id, to_room_id)
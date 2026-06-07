extends RefCounted
class_name DungeonLayoutGenerator

var dungeon: DungeonGenerator
var dungeon_graph: DungeonGraph = null

# Working buffers used while generating a candidate layout.
var _working_floor_cells: Dictionary = {}
var _working_corridor_cells: Dictionary = {}
var _working_room_infos: Array[Dictionary] = []
var _working_graph: DungeonGraph = null
var _working_room_cells: Dictionary = {}



func setup(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon
	if dungeon_graph == null:
		dungeon_graph = DungeonGraph.new()
	else:
		dungeon_graph.clear()


func get_dungeon_graph() -> DungeonGraph:
	if dungeon_graph == null:
		dungeon_graph = DungeonGraph.new()
	return dungeon_graph


# Generates pure layout data and does not mutate DungeonGenerator runtime arrays.
# DungeonGenerator is responsible for applying the returned data.
func generate() -> DungeonLayoutData:
	const LAYOUT_RETRIES := 32
	dungeon.room_count = 8 # Force strict linear progression of exactly 8 rooms

	for _retry in range(LAYOUT_RETRIES):
		_begin_working_layout()
		var attempts := dungeon.room_count * 90
		var placed_rects: Array[Rect2i] = []

		while placed_rects.size() < dungeon.room_count and attempts > 0:
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

			var overlaps := false
			var expanded := room_rect.grow(dungeon.room_padding)
			for other in placed_rects:
				if expanded.intersects(other):
					overlaps = true
					break

			if overlaps:
				continue

			placed_rects.append(room_rect)

		if placed_rects.size() == dungeon.room_count:
			# Deterministic left-to-right ordering so room IDs match progression (0 -> 7).
			placed_rects.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
				var center_a := a.position + a.size / 2
				var center_b := b.position + b.size / 2
				if center_a.x != center_b.x:
					return center_a.x < center_b.x
				return center_a.y < center_b.y
			)

			for room_rect in placed_rects:
				_register_room(room_rect)

			_connect_rooms_with_corridors()
			if not _validate_graph():
				continue
			return _build_layout_data()

	return null


func _begin_working_layout() -> void:
	_working_floor_cells.clear()
	_working_corridor_cells.clear()
	_working_room_infos.clear()
	_working_graph = DungeonGraph.new()


func _build_layout_data() -> DungeonLayoutData:
	var layout := DungeonLayoutData.new()
	layout.floor_cells = _working_floor_cells.duplicate(true)
	layout.corridor_cells = _working_corridor_cells.duplicate(true)
	layout.room_infos = _working_room_infos.duplicate(true)
	layout.graph = _working_graph
	layout.metadata = {
		"room_count": _working_room_infos.size(),
		"main_path_branching": false
	}
	# Keep graph accessor compatibility for existing systems.
	dungeon_graph = _working_graph
	return layout


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

	for room_info in _working_room_infos:
		var other: Rect2i = room_info["rect"]
		if expanded.intersects(other):
			return true

	return false


func _register_room(room_rect: Rect2i) -> void:
	var room_id := _working_room_infos.size()
	var room_template := _get_room_template(room_id)

	var room_cells: Array[Vector2i] = []

	for x in range(room_rect.position.x, room_rect.end.x):
		for y in range(room_rect.position.y, room_rect.end.y):
			var cell := Vector2i(x, y)
			_working_floor_cells[cell] = true
			room_cells.append(cell)
			_working_room_cells[cell] = true

	var center_cell := Vector2i(
		room_rect.position.x + int(room_rect.size.x * 0.5),
		room_rect.position.y + int(room_rect.size.y * 0.5)
	)

	# Keep room_infos procedural only: no runtime/presentation references.
	_working_room_infos.append({
		"id": room_id,
		"rect": room_rect,
		"center_cell": center_cell,
		"floor_cells": room_cells,
		"template": room_template
	})

	_working_graph.add_room(room_id, {
		"rect": room_rect,
		"center_cell": center_cell,
		"template": room_template
	})


func _connect_rooms_with_corridors() -> void:
	if _working_room_infos.size() <= 1:
		return

	# Connect rooms in a strict linear chain: Room 0 -> Room 1 -> Room 2 -> ... -> Room 7
	for i in range(_working_room_infos.size() - 1):
		var current_room := _working_room_infos[i]
		var next_room := _working_room_infos[i + 1]

		var from_room_id: int = current_room["id"]
		var to_room_id: int = next_room["id"]
		var from_cell := _get_connection_point(current_room, next_room["center_cell"])
		var to_cell := _get_connection_point(next_room, current_room["center_cell"])

		var corridor_cells := _carve_corridor(from_cell, to_cell)
		_register_connection(from_room_id, to_room_id, corridor_cells)

		current_room["is_main_path"] = true

	# Set main path flag on the final room as well
	_working_room_infos[_working_room_infos.size() - 1]["is_main_path"] = true


func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var min_length := dungeon.corridor_min_length
	var max_length := dungeon.corridor_max_length
	var corridor_cells: Array[Vector2i] = []

	var current := from_cell

	# Evitar que el punto inicial sea considerado corredor
	# si está dentro de la sala
	_working_corridor_cells[current] = false
	var corridor_length := 0
	if _add_corridor_cell(current):
		corridor_cells.append(current)

	var horizontal_first := randf() < 0.5

	if horizontal_first:
		while current.x != to_cell.x:
			current.x += signi(to_cell.x - current.x)
			if _add_corridor_cell(current):
				corridor_cells.append(current)
			corridor_length += 1

		_add_corridor_cell(current)
		_add_corridor_cell(current)

		while current.y != to_cell.y:
			current.y += signi(to_cell.y - current.y)
			if _add_corridor_cell(current):
				corridor_cells.append(current)
			corridor_length += 1
	else:
		while current.y != to_cell.y:
			current.y += signi(to_cell.y - current.y)
			if _add_corridor_cell(current):
				corridor_cells.append(current)
			corridor_length += 1

		_add_corridor_cell(current)
		_add_corridor_cell(current)

		while current.x != to_cell.x:
			current.x += signi(to_cell.x - current.x)
			if _add_corridor_cell(current):
				corridor_cells.append(current)
			corridor_length += 1

	if corridor_length < min_length or corridor_length > max_length:
		push_warning("Corridor length %d outside bounds [%d, %d]. Consider adjusting room placement." % [corridor_length, min_length, max_length])

	var final_cells: Array[Vector2i] = []

	for c in corridor_cells:
		_add_corridor_cell_double(c, final_cells)

	return final_cells


func _add_corridor_cell_double(cell: Vector2i, out: Array) -> void:
	var offsets = [
		Vector2i(0, 0),
		Vector2i(1, 0)
	]

	for o in offsets:
		var c = cell + o

		if dungeon.is_within_bounds(c) and not _working_room_cells.has(c):
			out.append(c)
			_working_floor_cells[c] = true
			_working_corridor_cells[c] = true


func _add_corridor_cell(cell: Vector2i) -> bool:
	if not dungeon.is_within_bounds(cell):
		return false

	if _working_room_cells.has(cell):
		# evita invadir salas
		return false

	_working_floor_cells[cell] = true
	_working_corridor_cells[cell] = true
	return true


func _register_connection(room_a: int, room_b: int, corridor_cells: Array[Vector2i]) -> void:
	if not _working_graph.add_edge(room_a, room_b, corridor_cells):
		push_error("DungeonLayoutGenerator: rejected non-linear edge %d -> %d" % [room_a, room_b])


func get_connected_room_ids(room_id: int) -> Array[int]:
	return get_dungeon_graph().get_connected_room_ids(room_id)


func are_rooms_connected(room_a: int, room_b: int) -> bool:
	return get_dungeon_graph().are_rooms_connected(room_a, room_b)


func _get_room_template(room_id: int) -> String:
	if room_id == 0:
		return DungeonGraph.TEMPLATE_TUTORIAL

	if room_id == dungeon.room_count - 1:
		return DungeonGraph.TEMPLATE_BOSS

	return DungeonGraph.TEMPLATE_NORMAL


func _validate_graph() -> bool:
	var result: Dictionary = _working_graph.validate(dungeon.room_count, true)
	if bool(result.get("valid", false)):
		return true

	for error_text in result.get("errors", []):
		push_error("DungeonLayoutGenerator: %s" % str(error_text))

	return false

func _fill_corner(cell: Vector2i) -> void:

	var corner_cells := [
		cell,
		cell + Vector2i.RIGHT,
		cell + Vector2i.DOWN,
		cell + Vector2i(1, 1)
	]

	for c in corner_cells:

		if not dungeon.is_within_bounds(c):
			continue

		_working_floor_cells[c] = true
		_working_corridor_cells[c] = true

func _get_connection_point(room: Dictionary, target: Vector2i) -> Vector2i:
	var rect: Rect2i = room["rect"]
	var center: Vector2i = room["center_cell"]

	var dx := target.x - center.x
	var dy := target.y - center.y

	# elegimos UN SOLO borde (no múltiples entradas/salidas)
	if abs(dx) > abs(dy):
		if dx > 0:
			return Vector2i(rect.end.x - 1, center.y)
		else:
			return Vector2i(rect.position.x, center.y)
	else:
		if dy > 0:
			return Vector2i(center.x, rect.end.y - 1)
		else:
			return Vector2i(center.x, rect.position.y)
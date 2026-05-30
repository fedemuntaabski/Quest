extends RefCounted
class_name DungeonLayoutGenerator

const DungeonGraph = preload("res://scripts/world/dungeon/DungeonGraph.gd")
const DungeonLayoutData = preload("res://scripts/world/dungeon/DungeonLayoutData.gd")

var dungeon
var dungeon_graph: DungeonGraph = null

# Working buffers used while generating a candidate layout.
var _working_floor_cells: Dictionary = {}
var _working_corridor_cells: Dictionary = {}
var _working_room_infos: Array[Dictionary] = []
var _working_graph: DungeonGraph = null


func setup(p_dungeon) -> void:
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

	for _retry in range(LAYOUT_RETRIES):
		_begin_working_layout()
		var attempts: int = dungeon.room_count * 90

		while _working_room_infos.size() < dungeon.room_count and attempts > 0:
			attempts -= 1
			var room_id = _working_room_infos.size()
			var room_plan = dungeon.get_room_generation_plan(room_id) if dungeon and dungeon.has_method("get_room_generation_plan") else {}
			var room_size = _roll_room_size_for_plan(room_plan)

			var max_x = dungeon.grid_width - room_size.x - dungeon.room_padding - 1
			var max_y = dungeon.grid_height - room_size.y - dungeon.room_padding - 1

			if max_x <= dungeon.room_padding or max_y <= dungeon.room_padding:
				continue

			var room_pos = Vector2i(
				randi_range(dungeon.room_padding, max_x),
				randi_range(dungeon.room_padding, max_y)
			)

			var room_rect = Rect2i(room_pos, room_size)

			if _room_overlaps_existing(room_rect):
				continue

			_register_room(room_rect, room_plan)

		if _working_room_infos.size() == dungeon.room_count:
			if not _connect_rooms_with_corridors():
				continue
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
		"main_path_branching": dungeon.main_path_branching
	}
	# Keep graph accessor compatibility for existing systems.
	dungeon_graph = _working_graph
	return layout


func _roll_room_size_for_plan(room_plan: Dictionary) -> Vector2i:
	if bool(room_plan.get("uses_catalog", false)):
		var min_size: Vector2i = room_plan.get("min_size", dungeon.room_min_size)
		var max_size: Vector2i = room_plan.get("max_size", dungeon.room_max_size)
		return _roll_room_size_in_range(min_size, max_size)

	return _roll_room_size()


func _roll_room_size() -> Vector2i:
	return _roll_room_size_in_range(dungeon.room_min_size, dungeon.room_max_size)


func _roll_room_size_in_range(min_size: Vector2i, max_size: Vector2i) -> Vector2i:
	var width := randi_range(mini(min_size.x, max_size.x), maxi(min_size.x, max_size.x))
	var height := randi_range(mini(min_size.y, max_size.y), maxi(min_size.y, max_size.y))

	var short_width_max := mini(max_size.x, min_size.x + 2)
	var short_height_max := mini(max_size.y, min_size.y + 2)
	var long_width_min := maxi(min_size.x, max_size.x - 4)
	var long_height_min := maxi(min_size.y, max_size.y - 4)

	var shape_roll := randf()

	if shape_roll < 0.34:
		width = randi_range(long_width_min, max_size.x)
		height = randi_range(min_size.y, short_height_max)
	elif shape_roll < 0.68:
		width = randi_range(min_size.x, short_width_max)
		height = randi_range(long_height_min, max_size.y)

	return Vector2i(width, height)


func _room_overlaps_existing(candidate: Rect2i) -> bool:
	var expanded = candidate.grow(dungeon.room_padding)

	for room_info in _working_room_infos:
		var other: Rect2i = room_info["rect"]
		if expanded.intersects(other):
			return true

	return false


func _register_room(room_rect: Rect2i, room_plan: Dictionary = {}) -> void:
	var room_id := _working_room_infos.size()
	var room_template := String(room_plan.get("template", _get_room_template(room_id)))
	var room_role := String(room_plan.get("room_role", _get_room_role(room_template)))
	var room_size_category := String(room_plan.get("size_category", ""))
	if room_size_category.is_empty():
		room_size_category = _get_room_size_category(room_rect)

	var room_cells: Array[Vector2i] = []

	for x in range(room_rect.position.x, room_rect.end.x):
		for y in range(room_rect.position.y, room_rect.end.y):
			var cell := Vector2i(x, y)
			_working_floor_cells[cell] = true
			room_cells.append(cell)

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
		"template": room_template,
		"size_category": room_size_category,
		"room_role": room_role
	})

	_working_graph.add_room(room_id, {
		"rect": room_rect,
		"center_cell": center_cell,
		"template": room_template,
		"size_category": room_size_category,
		"room_role": room_role
	})


func _connect_rooms_with_corridors() -> bool:
	if _working_room_infos.size() <= 1:
		return true

	var unvisited_rooms := _working_room_infos.duplicate()
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

		if not _working_graph.has_edge(from_room_id, to_room_id):
			var corridor_cells := _carve_corridor(from_cell, to_cell)
			if corridor_cells.is_empty():
				return false
			_register_connection(from_room_id, to_room_id, corridor_cells)

		main_path.append(nearest_room)
		unvisited_rooms.erase(nearest_room)
		current_room = nearest_room

	for room_info in main_path:
		room_info["is_main_path"] = true

	if dungeon.main_path_branching and unvisited_rooms.size() > 0:
		for room_info in unvisited_rooms:
			if not _connect_to_nearest_main_path_room(room_info, main_path):
				return false

	return true


func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var min_length = dungeon.corridor_min_length
	var max_length = dungeon.corridor_max_length
	var enforce_max = dungeon.enforce_corridor_max_length
	var corridor_cells: Array[Vector2i] = []
	var added_cells: Array[Vector2i] = []

	var current = from_cell
	var corridor_length = 0

	var horizontal_first = randf() < 0.5
	_stamp_corridor_width(current, horizontal_first, corridor_cells, added_cells)

	if horizontal_first:
		while current.x != to_cell.x:
			current.x += signi(to_cell.x - current.x)
			_stamp_corridor_width(current, true, corridor_cells, added_cells)
			corridor_length += 1
			if enforce_max and corridor_length > max_length:
				_rollback_corridor_cells(added_cells)
				return []

		while current.y != to_cell.y:
			current.y += signi(to_cell.y - current.y)
			_stamp_corridor_width(current, false, corridor_cells, added_cells)
			corridor_length += 1
			if enforce_max and corridor_length > max_length:
				_rollback_corridor_cells(added_cells)
				return []
	else:
		while current.y != to_cell.y:
			current.y += signi(to_cell.y - current.y)
			_stamp_corridor_width(current, false, corridor_cells, added_cells)
			corridor_length += 1
			if enforce_max and corridor_length > max_length:
				_rollback_corridor_cells(added_cells)
				return []

		while current.x != to_cell.x:
			current.x += signi(to_cell.x - current.x)
			_stamp_corridor_width(current, true, corridor_cells, added_cells)
			corridor_length += 1
			if enforce_max and corridor_length > max_length:
				_rollback_corridor_cells(added_cells)
				return []

	if corridor_length < min_length or corridor_length > max_length:
		push_warning("Corridor length %d outside bounds [%d, %d]. Consider adjusting room placement." % [corridor_length, min_length, max_length])

	return corridor_cells


func _add_corridor_cell(cell: Vector2i) -> bool:
	if not dungeon.is_within_bounds(cell):
		return false

	if _working_floor_cells.has(cell):
		return false

	_working_floor_cells[cell] = true
	_working_corridor_cells[cell] = true
	return true


func _stamp_corridor_width(
	center_cell: Vector2i,
	horizontal_segment: bool,
	corridor_cells: Array[Vector2i],
	added_cells: Array[Vector2i]
) -> void:
	var width := maxi(1, dungeon.corridor_width)
	var radius := int(width / 2.0)

	for offset in range(-radius, radius + 1):
		if width % 2 == 0 and offset == radius:
			continue

		var stamped_cell := center_cell
		if horizontal_segment:
			stamped_cell += Vector2i(0, offset)
		else:
			stamped_cell += Vector2i(offset, 0)

		if _add_corridor_cell(stamped_cell):
			corridor_cells.append(stamped_cell)
			added_cells.append(stamped_cell)


func _rollback_corridor_cells(added_cells: Array[Vector2i]) -> void:
	for cell in added_cells:
		_working_floor_cells.erase(cell)
		_working_corridor_cells.erase(cell)


func _register_connection(room_a: int, room_b: int, corridor_cells: Array[Vector2i]) -> void:
	_working_graph.add_edge(room_a, room_b, corridor_cells)


func get_connected_room_ids(room_id: int) -> Array[int]:
	return get_dungeon_graph().get_connected_room_ids(room_id)


func are_rooms_connected(room_a: int, room_b: int) -> bool:
	return get_dungeon_graph().are_rooms_connected(room_a, room_b)


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


func _connect_to_nearest_main_path_room(room_info: Dictionary, main_path: Array[Dictionary]) -> bool:
	var room_center: Vector2i = room_info["center_cell"]
	var nearest_main: Dictionary = _find_nearest_room(room_center, main_path)

	if nearest_main.is_empty():
		return false

	var from_room_id: int = room_info["id"]
	var to_room_id: int = nearest_main["id"]
	var from_cell: Vector2i = room_info["center_cell"]
	var to_cell: Vector2i = nearest_main["center_cell"]

	if not _working_graph.has_edge(from_room_id, to_room_id):
		var corridor_cells := _carve_corridor(from_cell, to_cell)
		if corridor_cells.is_empty():
			return false
		_register_connection(from_room_id, to_room_id, corridor_cells)

	return true


func _get_room_template(room_id: int) -> String:
	if dungeon and dungeon.has_method("_get_legacy_room_template"):
		return String(dungeon.call("_get_legacy_room_template", room_id))

	if dungeon.enable_tutorial_room and room_id == 0:
		return DungeonGraph.TEMPLATE_TUTORIAL

	if dungeon.enable_boss_room and dungeon.room_count > 1 and room_id == dungeon.room_count - 1:
		return DungeonGraph.TEMPLATE_BOSS

	return DungeonGraph.TEMPLATE_NORMAL


func _get_room_size_category(room_rect: Rect2i) -> String:
	var min_area := float(dungeon.room_min_size.x * dungeon.room_min_size.y)
	var max_area := float(dungeon.room_max_size.x * dungeon.room_max_size.y)
	var area := float(room_rect.size.x * room_rect.size.y)

	if max_area <= min_area:
		return "medium"

	var normalized := clampf((area - min_area) / (max_area - min_area), 0.0, 1.0)
	if normalized <= dungeon.room_small_threshold:
		return "small"
	if normalized <= dungeon.room_medium_threshold:
		return "medium"
	return "large"


func _get_room_role(template: String) -> String:
	if template == DungeonGraph.TEMPLATE_TUTORIAL:
		return DungeonGraph.ROOM_ROLE_TUTORIAL
	if template == DungeonGraph.TEMPLATE_BOSS:
		return DungeonGraph.ROOM_ROLE_BOSS
	return DungeonGraph.ROOM_ROLE_NORMAL


func _validate_graph() -> bool:
	var result: Dictionary = _working_graph.validate(dungeon.room_count, true)
	if bool(result.get("valid", false)):
		return true

	for error_text in result.get("errors", []):
		push_error("DungeonLayoutGenerator: %s" % str(error_text))

	return false

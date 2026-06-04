extends RefCounted
class_name DungeonGraph

const TEMPLATE_TUTORIAL := "tutorial"
const TEMPLATE_NORMAL := "normal"
const TEMPLATE_BOSS := "boss"
const TEMPLATE_CORRIDOR := "corridor"
const TEMPLATE_CUSTOM := "custom_layout"

const LINEAR_ROOM_COUNT := 8
const MAX_CONNECTIONS_PER_ROOM := 2

var rooms: Dictionary = {}
var edges: Dictionary = {}
var adjacency: Dictionary = {}


func clear() -> void:
	rooms.clear()
	edges.clear()
	adjacency.clear()


func add_room(room_id: int, room_info: Dictionary) -> void:
	if room_id < 0:
		return

	rooms[room_id] = _build_room_record(room_id, room_info)
	if not adjacency.has(room_id):
		adjacency[room_id] = {}


func add_edge(room_a: int, room_b: int, corridor_cells: Array = []) -> bool:
	if room_a < 0 or room_b < 0 or room_a == room_b:
		return false

	if not _is_valid_linear_edge(room_a, room_b):
		return false

	if get_connected_room_ids(room_a).size() >= MAX_CONNECTIONS_PER_ROOM:
		return false
	if get_connected_room_ids(room_b).size() >= MAX_CONNECTIONS_PER_ROOM:
		return false

	var key := get_edge_key(room_a, room_b)
	if edges.has(key):
		return false

	edges[key] = {
		"room_a": room_a,
		"room_b": room_b,
		"corridor_cells": corridor_cells.duplicate(),
		"template": TEMPLATE_CORRIDOR
	}
	_add_adjacency(room_a, room_b)
	_add_adjacency(room_b, room_a)
	return true


func has_edge(room_a: int, room_b: int) -> bool:
	return edges.has(get_edge_key(room_a, room_b))


func get_edge(room_a: int, room_b: int) -> Dictionary:
	return edges.get(get_edge_key(room_a, room_b), {})


func set_edge_runtime_node(room_a: int, room_b: int, runtime_node: Node) -> void:
	var key := get_edge_key(room_a, room_b)
	if not edges.has(key):
		return

	var edge: Dictionary = edges[key]
	edge["runtime_node"] = runtime_node
	edges[key] = edge


func get_edge_records_sorted() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for edge_key_variant in edges.keys():
		var edge_key := String(edge_key_variant)
		var edge: Dictionary = edges[edge_key]
		records.append({
			"key": edge_key,
			"room_a": int(edge.get("room_a", -1)),
			"room_b": int(edge.get("room_b", -1)),
			"corridor_cells": edge.get("corridor_cells", []),
			"template": edge.get("template", TEMPLATE_CORRIDOR)
		})

	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.get("room_a", -1)) == int(right.get("room_a", -1)):
			return int(left.get("room_b", -1)) < int(right.get("room_b", -1))
		return int(left.get("room_a", -1)) < int(right.get("room_a", -1))
	)
	return records


func get_edge_key(room_a: int, room_b: int) -> String:
	var low := mini(room_a, room_b)
	var high := maxi(room_a, room_b)
	return "%d_%d" % [low, high]


func get_connected_room_ids(room_id: int) -> Array[int]:
	var connected: Array[int] = []
	var room_adjacency: Dictionary = adjacency.get(room_id, {})

	for raw_room_id in room_adjacency.keys():
		connected.append(int(raw_room_id))

	connected.sort()
	return connected


func are_rooms_connected(room_a: int, room_b: int) -> bool:
	var room_adjacency: Dictionary = adjacency.get(room_a, {})
	return room_adjacency.has(room_b)


func validate(expected_room_count: int = -1, require_connected: bool = true) -> Dictionary:
	var errors: Array[String] = []

	for room_id_variant in rooms.keys():
		var room_id := int(room_id_variant)
		if not adjacency.has(room_id):
			errors.append("Room %d is missing adjacency storage." % room_id)

	for edge_key_variant in edges.keys():
		var edge_key := String(edge_key_variant)
		var edge: Dictionary = edges[edge_key]
		var room_a := int(edge.get("room_a", -1))
		var room_b := int(edge.get("room_b", -1))

		if room_a < 0 or room_b < 0:
			errors.append("Edge %s has invalid endpoints." % edge_key)
			continue

		if room_a == room_b:
			errors.append("Edge %s connects room %d to itself." % [edge_key, room_a])
			continue

		if not rooms.has(room_a) or not rooms.has(room_b):
			errors.append("Edge %s references missing room(s): %d -> %d." % [edge_key, room_a, room_b])
			continue

		var adjacency_a: Dictionary = adjacency.get(room_a, {})
		var adjacency_b: Dictionary = adjacency.get(room_b, {})
		if not adjacency_a.has(room_b) or not adjacency_b.has(room_a):
			errors.append("Edge %s is not mirrored in adjacency." % edge_key)

		if not edge.has("corridor_cells"):
			errors.append("Edge %s has no corridor cells." % edge_key)

	if expected_room_count >= 0 and rooms.size() != expected_room_count:
		errors.append("Expected %d rooms, found %d." % [expected_room_count, rooms.size()])

	if expected_room_count >= 0 and rooms.size() == expected_room_count:
		for edge_key_variant in edges.keys():
			var edge: Dictionary = edges[String(edge_key_variant)]
			var room_a := int(edge.get("room_a", -1))
			var room_b := int(edge.get("room_b", -1))
			if not _is_valid_linear_edge(room_a, room_b):
				errors.append("Non-linear edge %d -> %d (must be adjacent room indices)." % [room_a, room_b])

		for room_id_variant in rooms.keys():
			var room_id := int(room_id_variant)
			var connected := get_connected_room_ids(room_id)

			if connected.size() > MAX_CONNECTIONS_PER_ROOM:
				errors.append("Room %d has %d connections (max %d)." % [room_id, connected.size(), MAX_CONNECTIONS_PER_ROOM])

			var expected_connected: Array[int] = []
			if room_id > 0:
				expected_connected.append(room_id - 1)
			if room_id < expected_room_count - 1:
				expected_connected.append(room_id + 1)
			expected_connected.sort()

			if connected != expected_connected:
				errors.append("Room %d is connected to %s, expected %s for strict linear progression." % [room_id, str(connected), str(expected_connected)])

			if room_id == 0 and connected != [1]:
				errors.append("Room 0 must connect only to Room 1, found %s." % str(connected))
			elif room_id == expected_room_count - 1 and connected != [expected_room_count - 2]:
				errors.append("Room %d must connect only to Room %d, found %s." % [room_id, expected_room_count - 2, str(connected)])

	if require_connected and rooms.size() > 0:
		var reachable := _collect_reachable_rooms()
		if reachable.size() != rooms.size():
			var missing: Array[int] = []
			for room_id_variant in rooms.keys():
				var room_id := int(room_id_variant)
				if not reachable.has(room_id):
					missing.append(room_id)
			missing.sort()
			errors.append("Unreachable rooms detected: %s" % str(missing))

	return {
		"valid": errors.is_empty(),
		"errors": errors
	}


func _build_room_record(room_id: int, room_info: Dictionary) -> Dictionary:
	return {
		"id": room_id,
		"rect": room_info.get("rect", Rect2i()),
		"center_cell": room_info.get("center_cell", Vector2i.ZERO),
		"template": room_info.get("template", TEMPLATE_NORMAL)
	}


func _is_valid_linear_edge(room_a: int, room_b: int) -> bool:
	return absi(room_a - room_b) == 1


func _add_adjacency(room_a: int, room_b: int) -> void:
	if room_a < 0 or room_b < 0:
		return

	if not adjacency.has(room_a):
		adjacency[room_a] = {}

	adjacency[room_a][room_b] = true


func _collect_reachable_rooms() -> Dictionary:
	var reachable: Dictionary = {}
	if rooms.is_empty():
		return reachable

	var room_ids: Array[int] = []
	for room_id_variant in rooms.keys():
		room_ids.append(int(room_id_variant))
	room_ids.sort()

	var pending: Array[int] = [room_ids[0]]
	while not pending.is_empty():
		var current : int = pending.pop_back()
		if reachable.has(current):
			continue
		reachable[current] = true

		for neighbor in get_connected_room_ids(current):
			if not reachable.has(neighbor):
				pending.append(neighbor)

	return reachable
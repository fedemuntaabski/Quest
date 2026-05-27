extends RefCounted
class_name DungeonRoomLayoutState

# Pure compile-time room data produced by layout generation.
# This object is immutable by convention after construction and is consumed by
# runtime systems only as read-only layout metadata.
var room_id: int = -1
var bounds: Rect2i = Rect2i()
var floor_cells: Array[Vector2i] = []
var local_floor_cells: Array[Vector2i] = []
var connectors: Array[RoomConnectorData] = []
var corridor_connections: Array[Dictionary] = []
var connected_room_ids: Array[int] = []
var template: String = ""
var topology_metadata: Dictionary = {}


func _init(
		p_room_id: int = -1,
		p_bounds: Rect2i = Rect2i(),
		p_floor_cells: Array = [],
		p_local_floor_cells: Array = [],
		p_connectors: Array = [],
		p_corridor_connections: Array = [],
		p_connected_room_ids: Array = [],
		p_template: String = "",
		p_topology_metadata: Dictionary = {}
) -> void:
	room_id = p_room_id
	bounds = p_bounds
	# duplicate(true) returns an untyped Array, so rebuild each typed field here
	# to keep the room layout contract stable without changing the payload shape.
	floor_cells = _copy_vector2i_array(p_floor_cells)
	local_floor_cells = _copy_vector2i_array(p_local_floor_cells)
	connectors = _copy_connector_array(p_connectors)
	corridor_connections = _copy_dictionary_array(p_corridor_connections)
	connected_room_ids = _copy_int_array(p_connected_room_ids)
	template = p_template
	topology_metadata = p_topology_metadata.duplicate(true)

	# Local floor cells are the room-local geometry contract. If callers only
	# provide world-grid floor cells, derive local coordinates from the room
	# bounds so legacy callers still get a consistent future-facing payload.
	if local_floor_cells.is_empty() and not floor_cells.is_empty() and bounds.size != Vector2i.ZERO:
		local_floor_cells = []
		for cell in floor_cells:
			local_floor_cells.append(Vector2i(cell) - bounds.position)


func add_connection(room_id: int, corridor_cells: Array) -> void:
	if room_id < 0:
		return

	if not connected_room_ids.has(room_id):
		connected_room_ids.append(room_id)
		connected_room_ids.sort()

	corridor_connections.append({
		"room_id": room_id,
		"corridor_cells": corridor_cells.duplicate(true)
	})


func get_local_bounds() -> Rect2i:
	# Local bounds are the prefab-facing room footprint in room-local space.
	# They deliberately remain derived from the compiled rectangle so the live
	# generator can stay rectangle-based while the adapter layer learns to work
	# in room-local coordinates.
	return Rect2i(Vector2i.ZERO, bounds.size)


func get_world_origin_cell() -> Vector2i:
	return bounds.position


func get_center_cell() -> Vector2i:
	return Vector2i(
		bounds.position.x + int(bounds.size.x * 0.5),
		bounds.position.y + int(bounds.size.y * 0.5)
	)


func get_world_cell_from_local_cell(local_cell: Vector2i) -> Vector2i:
	return bounds.position + local_cell


func get_local_cell_from_world_cell(world_cell: Vector2i) -> Vector2i:
	return world_cell - bounds.position


func get_world_position_from_local_position(local_position: Vector2, tile_size: float = 16.0) -> Vector2:
	return Vector2(bounds.position) * tile_size + local_position


func get_local_position_from_world_position(world_position: Vector2, tile_size: float = 16.0) -> Vector2:
	return world_position - Vector2(bounds.position) * tile_size


func rotate_local_cell(local_cell: Vector2i, rotation_degrees: int) -> Vector2i:
	# Rotation support is intentionally conservative: the adapter only needs
	# the four cardinal quarter turns for the eventual prefab pipeline.
	var normalized_rotation := int(rotation_degrees) % 360
	if normalized_rotation < 0:
		normalized_rotation += 360

	var size := bounds.size
	match normalized_rotation:
		90:
			return Vector2i(size.y - 1 - local_cell.y, local_cell.x)
		180:
			return Vector2i(size.x - 1 - local_cell.x, size.y - 1 - local_cell.y)
		270:
			return Vector2i(local_cell.y, size.x - 1 - local_cell.x)
		_:
			return local_cell


func get_rotated_world_cell(local_cell: Vector2i, rotation_degrees: int) -> Vector2i:
	return bounds.position + rotate_local_cell(local_cell, rotation_degrees)


func get_rotated_world_position_from_local_cell(local_cell: Vector2i, tile_size: float = 16.0, rotation_degrees: int = 0) -> Vector2:
	var rotated_cell := rotate_local_cell(local_cell, rotation_degrees)
	return get_world_position_from_local_position(Vector2(rotated_cell) * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5), tile_size)


func to_dictionary() -> Dictionary:
	return {
		"id": room_id,
		"rect": bounds,
		"local_floor_cells": local_floor_cells.duplicate(true),
		"local_bounds": get_local_bounds(),
		"center_cell": get_center_cell(),
		"floor_cells": floor_cells.duplicate(true),
		"connectors": _connectors_to_dictionaries(),
		"corridor_connections": corridor_connections.duplicate(true),
		"connected_room_ids": connected_room_ids.duplicate(true),
		"template": template,
		"topology_metadata": topology_metadata.duplicate(true),
		"is_main_path": bool(topology_metadata.get("is_main_path", false))
	}


func _connectors_to_dictionaries() -> Array:
	var result: Array[Dictionary] = []
	for connector in connectors:
		if connector == null:
			continue
		result.append(connector.to_dictionary())
	return result


func _copy_vector2i_array(source: Array) -> Array[Vector2i]:
	var copy: Array[Vector2i] = []
	for cell in source:
		copy.append(Vector2i(cell))
	return copy


func _copy_connector_array(source: Array) -> Array[RoomConnectorData]:
	var copy: Array[RoomConnectorData] = []
	for connector in source:
		if connector == null:
			continue
		copy.append(connector)
	return copy


func _copy_dictionary_array(source: Array) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry in source:
		copy.append(entry.duplicate(true) if entry is Dictionary else {})
	return copy


func _copy_int_array(source: Array) -> Array[int]:
	var copy: Array[int] = []
	for value in source:
		copy.append(int(value))
	return copy

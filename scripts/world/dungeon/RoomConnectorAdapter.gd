extends RefCounted
class_name RoomConnectorAdapter

## Adapter utilities bridge authored scenes and the new connector metadata
## contract. They are deliberately read-only helpers: they infer connector
## semantics from existing markers, but they do not mutate scenes or activate
## any prefab pipeline behavior.
##
## Local coordinates matter here. A connector is stored in room-local space so
## future modular rooms can be rotated or mirrored before being placed in the
## dungeon grid. World coordinates are only a runtime projection of that local
## metadata.
const MARKER_ROOT_NAME := &"Puertas"
const DEFAULT_DOOR_TAG := &"door"


static func build_rect_connectors(room_id: int, room_rect: Rect2i, tile_size: float) -> Array[RoomConnectorData]:
	var connectors: Array[RoomConnectorData] = []
	if room_rect.size == Vector2i.ZERO:
		return connectors

	var local_center_x := int(room_rect.size.x * 0.5)
	var local_center_y := int(room_rect.size.y * 0.5)
	var local_center := Vector2(local_center_x * tile_size + tile_size * 0.5, local_center_y * tile_size + tile_size * 0.5)
	var mid_left := Vector2(tile_size * 0.5, local_center.y)
	var mid_right := Vector2(float(room_rect.size.x - 1) * tile_size + tile_size * 0.5, local_center.y)
	var mid_top := Vector2(local_center.x, tile_size * 0.5)
	var mid_bottom := Vector2(local_center.x, float(room_rect.size.y - 1) * tile_size + tile_size * 0.5)

	connectors.append(_build_connector("room_%d_north" % room_id, RoomConnectorData.ConnectorType.OPENING, RoomConnectorData.ConnectorDirection.NORTH, mid_top, Vector2i(local_center_x, 0), room_id, "rect"))
	connectors.append(_build_connector("room_%d_east" % room_id, RoomConnectorData.ConnectorType.OPENING, RoomConnectorData.ConnectorDirection.EAST, mid_right, Vector2i(room_rect.size.x - 1, local_center_y), room_id, "rect"))
	connectors.append(_build_connector("room_%d_south" % room_id, RoomConnectorData.ConnectorType.OPENING, RoomConnectorData.ConnectorDirection.SOUTH, mid_bottom, Vector2i(local_center_x, room_rect.size.y - 1), room_id, "rect"))
	connectors.append(_build_connector("room_%d_west" % room_id, RoomConnectorData.ConnectorType.OPENING, RoomConnectorData.ConnectorDirection.WEST, mid_left, Vector2i(0, local_center_y), room_id, "rect"))

	return connectors


static func extract_connectors_from_scene(room_root: Node, tile_size: float = 16.0) -> Array[RoomConnectorData]:
	var connectors: Array[RoomConnectorData] = []
	if room_root == null:
		return connectors

	# Prefer a future `Puertas` hierarchy when it exists, but keep the current
	# root-level markers as a compatibility fallback so authored scenes do not
	# need to be rewritten yet.
	var marker_root := _get_marker_root(room_root)
	var marker_nodes: Array[Marker2D] = []
	_collect_markers(marker_root, marker_nodes)
	for index in range(marker_nodes.size()):
		var connector := connector_from_marker(marker_nodes[index], room_root, tile_size, index)
		if connector != null:
			connectors.append(connector)

	return connectors


static func connector_from_marker(marker: Marker2D, room_root: Node, tile_size: float = 16.0, connector_index: int = 0) -> RoomConnectorData:
	if marker == null:
		return null

	var connector := RoomConnectorData.new()
	var local_position := marker.position
	if room_root is Node2D and marker != room_root:
		local_position = (room_root as Node2D).to_local(marker.global_position)

	connector.connector_id = "%s_%d" % [marker.name.to_lower(), connector_index]
	connector.connector_type = infer_connector_type(marker.name)
	connector.facing_direction = infer_connector_direction(marker)
	connector.local_position = local_position
	connector.local_cell = Vector2i(floori(local_position.x / tile_size), floori(local_position.y / tile_size))
	connector.marker_name = marker.name
	connector.supports_rotation = true
	connector.tags = _tags_from_name(marker.name)
	connector.metadata = {
		"source": "scene_marker",
		"marker_name": marker.name,
		"rotation_degrees": rad_to_deg(marker.rotation)
	}
	return connector


static func infer_connector_direction(marker: Marker2D) -> int:
	if marker == null:
		return RoomConnectorData.ConnectorDirection.UNKNOWN

	var facing := Vector2.RIGHT.rotated(marker.rotation)
	return RoomConnectorData.direction_from_vector(facing)


static func infer_connector_type(marker_name: String) -> int:
	var normalized := marker_name.to_lower()
	if normalized.contains("entrada"):
		return RoomConnectorData.ConnectorType.ENTRY
	if normalized.contains("salida"):
		return RoomConnectorData.ConnectorType.EXIT
	if normalized.contains("spawn"):
		return RoomConnectorData.ConnectorType.SPAWN
	if normalized.contains("puerta") or normalized.contains("door"):
		return RoomConnectorData.ConnectorType.DOOR
	if normalized.contains("connector") or normalized.contains("conexion"):
		return RoomConnectorData.ConnectorType.OPENING
	return RoomConnectorData.ConnectorType.SPECIAL


static func local_floor_cells_from_world_cells(floor_cells: Array, room_origin_cell: Vector2i) -> Array[Vector2i]:
	var local_cells: Array[Vector2i] = []
	for raw_cell in floor_cells:
		var cell: Vector2i = raw_cell
		local_cells.append(cell - room_origin_cell)
	return local_cells


static func scene_markers_to_dictionary(room_root: Node, tile_size: float = 16.0) -> Array[Dictionary]:
	var connectors: Array[Dictionary] = []
	for connector in extract_connectors_from_scene(room_root, tile_size):
		if connector == null:
			continue
		connectors.append(connector.to_dictionary())
	return connectors


static func _collect_markers(node: Node, result: Array[Marker2D]) -> void:
	if node is Marker2D:
		var marker := node as Marker2D
		if _looks_like_connector_marker(marker):
			result.append(marker)

	for child in node.get_children():
		if child is Node:
			_collect_markers(child, result)


static func _get_marker_root(room_root: Node) -> Node:
	if room_root == null:
		return null

	var door_root := room_root.get_node_or_null(String(MARKER_ROOT_NAME))
	if door_root != null:
		return door_root
	return room_root


static func _looks_like_connector_marker(marker: Marker2D) -> bool:
	if marker == null:
		return false

	var normalized := marker.name.to_lower()
	return (
		normalized.contains("entrada")
		or normalized.contains("salida")
		or normalized.contains("puerta")
		or normalized.contains("door")
		or normalized.contains("connector")
		or normalized.contains("conexion")
		or normalized.contains("spawn")
	)


static func _tags_from_name(marker_name: String) -> Array[StringName]:
	var tags: Array[StringName] = []
	var normalized := marker_name.to_lower()
	if normalized.contains("entrada"):
		tags.append(&"entry")
	if normalized.contains("salida"):
		tags.append(&"exit")
	if normalized.contains("spawn"):
		tags.append(&"spawn")
	if normalized.contains("puerta") or normalized.contains("door"):
		tags.append(DEFAULT_DOOR_TAG)
	return tags


static func _build_connector(connector_id: String, connector_type: int, direction: int, local_position: Vector2, local_cell: Vector2i, room_id: int, source: String) -> RoomConnectorData:
	var connector := RoomConnectorData.new()
	connector.connector_id = connector_id
	connector.connector_type = connector_type
	connector.facing_direction = direction
	connector.local_position = local_position
	connector.local_cell = local_cell
	connector.marker_name = connector_id
	connector.metadata = {
		"source": source,
		"room_id": room_id
	}
	connector.tags = [DEFAULT_DOOR_TAG]
	return connector

extends Resource
class_name RoomConnectorData

## Connector semantics are intentionally explicit: a room connector is a
## reusable piece of room-local metadata that describes where a room can
## connect, what direction it faces, and whether it is already occupied or
## linked to another room.
##
## The live generator does not use this yet for prefab placement. It only
## enriches the room contract so future modular rooms can be introduced
## without reworking layout consumers.
enum ConnectorDirection {
	UNKNOWN = -1,
	NORTH = 0,
	EAST = 1,
	SOUTH = 2,
	WEST = 3
}

enum ConnectorType {
	UNKNOWN = -1,
	OPENING = 0,
	DOOR = 1,
	ENTRY = 2,
	EXIT = 3,
	SPAWN = 4,
	SPECIAL = 5
}

@export var connector_id: StringName = &""
@export var connector_type: int = ConnectorType.UNKNOWN
@export var facing_direction: int = ConnectorDirection.UNKNOWN
@export var local_position: Vector2 = Vector2.ZERO
@export var local_cell: Vector2i = Vector2i.ZERO
@export var occupied: bool = false
@export var connected: bool = false
@export var connected_room_id: int = -1
@export var supports_rotation: bool = true
@export var marker_name: StringName = &""
@export var tags: Array[StringName] = []
@export var metadata: Dictionary = {}


func duplicate_connector() -> RoomConnectorData:
	var copy := RoomConnectorData.new()
	copy.connector_id = connector_id
	copy.connector_type = connector_type
	copy.facing_direction = facing_direction
	copy.local_position = local_position
	copy.local_cell = local_cell
	copy.occupied = occupied
	copy.connected = connected
	copy.connected_room_id = connected_room_id
	copy.supports_rotation = supports_rotation
	copy.marker_name = marker_name
	copy.tags = tags.duplicate(true)
	copy.metadata = metadata.duplicate(true)
	return copy


func to_dictionary() -> Dictionary:
	return {
		"connector_id": String(connector_id),
		"connector_type": connector_type,
		"facing_direction": facing_direction,
		"local_position": local_position,
		"local_cell": local_cell,
		"occupied": occupied,
		"connected": connected,
		"connected_room_id": connected_room_id,
		"supports_rotation": supports_rotation,
		"marker_name": String(marker_name),
		"tags": tags.duplicate(true),
		"metadata": metadata.duplicate(true)
	}


static func direction_to_vector(direction: int) -> Vector2i:
	match direction:
		ConnectorDirection.NORTH:
			return Vector2i.UP
		ConnectorDirection.EAST:
			return Vector2i.RIGHT
		ConnectorDirection.SOUTH:
			return Vector2i.DOWN
		ConnectorDirection.WEST:
			return Vector2i.LEFT
		_:
			return Vector2i.ZERO


static func opposite_direction(direction: int) -> int:
	match direction:
		ConnectorDirection.NORTH:
			return ConnectorDirection.SOUTH
		ConnectorDirection.EAST:
			return ConnectorDirection.WEST
		ConnectorDirection.SOUTH:
			return ConnectorDirection.NORTH
		ConnectorDirection.WEST:
			return ConnectorDirection.EAST
		_:
			return ConnectorDirection.UNKNOWN


static func direction_from_vector(direction_vector: Vector2) -> int:
	if direction_vector == Vector2.ZERO:
		return ConnectorDirection.UNKNOWN

	if absf(direction_vector.x) >= absf(direction_vector.y):
		return ConnectorDirection.EAST if direction_vector.x >= 0.0 else ConnectorDirection.WEST
	return ConnectorDirection.SOUTH if direction_vector.y >= 0.0 else ConnectorDirection.NORTH

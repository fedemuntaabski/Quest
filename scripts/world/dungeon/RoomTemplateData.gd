extends Resource
class_name RoomTemplateData

## RoomTemplateData is the future prefab-facing contract for authored rooms.
## It is intentionally scene-agnostic at runtime: the template points at a
## PackedScene plus declarative metadata that a modular room pipeline can read
## without inspecting the scene tree every time.
##
## For this preparatory phase we keep the existing procedural generator alive;
## this resource only establishes the shape of the metadata to come.
@export var room_scene: PackedScene
@export var room_type: StringName = &"room"
@export var tags: Array[StringName] = []
@export var connectors: Array[RoomConnectorData] = []
@export var supports_rotation: bool = true
@export var allowed_rotations: Array[int] = [0, 90, 180, 270]
@export var spawn_profile: StringName = &""
@export var weight: float = 1.0
@export var min_depth: int = 0
@export var max_depth: int = -1
@export var is_boss_room: bool = false
@export var room_local_cells: Array[Vector2i] = []
@export var metadata: Dictionary = {}


func duplicate_template() -> RoomTemplateData:
	var copy := RoomTemplateData.new()
	copy.room_scene = room_scene
	copy.room_type = room_type
	copy.tags = tags.duplicate(true)
	copy.connectors = []
	for connector in connectors:
		if connector == null:
			continue
		copy.connectors.append(connector.duplicate_connector())
	copy.supports_rotation = supports_rotation
	copy.allowed_rotations = allowed_rotations.duplicate(true)
	copy.spawn_profile = spawn_profile
	copy.weight = weight
	copy.min_depth = min_depth
	copy.max_depth = max_depth
	copy.is_boss_room = is_boss_room
	copy.room_local_cells = room_local_cells.duplicate(true)
	copy.metadata = metadata.duplicate(true)
	return copy


func to_dictionary() -> Dictionary:
	var connector_data: Array = []
	for connector in connectors:
		if connector == null:
			continue
		connector_data.append(connector.to_dictionary())

	return {
		"room_scene": room_scene,
		"room_type": String(room_type),
		"tags": tags.duplicate(true),
		"connectors": connector_data,
		"supports_rotation": supports_rotation,
		"allowed_rotations": allowed_rotations.duplicate(true),
		"spawn_profile": String(spawn_profile),
		"weight": weight,
		"min_depth": min_depth,
		"max_depth": max_depth,
		"is_boss_room": is_boss_room,
		"room_local_cells": room_local_cells.duplicate(true),
		"metadata": metadata.duplicate(true)
	}

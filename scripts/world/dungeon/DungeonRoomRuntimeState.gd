extends RefCounted
class_name DungeonRoomRuntimeState

# Mutable room state owned by the dungeon runtime.
# This is where gameplay-visible per-room flags live; layout data must not be
# written back here.
var room_id: int = -1
var visited: bool = false


func _init(p_room_id: int = -1) -> void:
	room_id = p_room_id


func to_dictionary() -> Dictionary:
	return {
		"id": room_id,
		"visited": visited
	}
extends RefCounted
class_name DungeonRoomPresentationState

# Presentation/view state owned by the presentation layer.
# Node references live here so visual systems can manage lights, detector areas,
# and room visual roots without pushing those references back into layout data.
var room_id: int = -1
var visual_root: Node2D = null
var light: PointLight2D = null
var area: Area2D = null


func _init(p_room_id: int = -1) -> void:
	room_id = p_room_id


func to_dictionary() -> Dictionary:
	return {
		"id": room_id,
		"visual_root": visual_root,
		"light": light,
		"area": area
	}
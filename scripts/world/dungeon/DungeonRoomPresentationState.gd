extends RefCounted
class_name DungeonRoomPresentationState

# Presentation/view state owned by the presentation layer.
# Node references live here so visual systems can manage lights, detector areas,
# and room visual roots without pushing those references back into layout data.
var room_id: int = -1
var visual_root: Node2D = null
var light: PointLight2D = null
var area: Area2D = null
var marker_refs: Dictionary = {}


func _init(p_room_id: int = -1) -> void:
	room_id = p_room_id


func to_dictionary() -> Dictionary:
	return {
		"id": room_id,
		"visual_root": visual_root,
		"light": light,
		"area": area,
		"marker_refs": marker_refs.duplicate(true)
	}


func set_marker_refs(refs: Dictionary) -> void:
	marker_refs = refs.duplicate(true)


func get_marker_ref(marker_name: String) -> Node2D:
	return marker_refs.get(marker_name, null)


func get_entrada_marker() -> Node2D:
	return get_marker_ref("Entrada")


func get_salida_marker() -> Node2D:
	return get_marker_ref("Salida")


func get_spawn_jugador_marker() -> Node2D:
	return get_marker_ref("Spawn_Jugador")


func get_spawn_tutorial_marker() -> Node2D:
	return get_marker_ref("Spawn_Tutorial")
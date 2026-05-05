extends Node
class_name DungeonFogController

var fog_manager: FogOfWarManager
var generator: DungeonGenerator

func setup(_generator: DungeonGenerator, _fog_manager: FogOfWarManager) -> void:
	generator = _generator
	fog_manager = _fog_manager

	# conectar evento
	generator.room_changed.connect(_on_room_changed)


func _on_room_changed(room_id: int) -> void:
	if fog_manager == null:
		return

	fog_manager.update_room_state(
		generator.room_infos,
		room_id
	)
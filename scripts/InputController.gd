extends Node

@onready var map_manager: MapManager = get_node("../MapManager")

func _process(_delta):
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	print("Input OK")

	var world_pos = cam.get_global_mouse_position()
	map_manager.update_hover(world_pos)
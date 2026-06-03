extends RefCounted
class_name DungeonRoomManager

var dungeon: DungeonGenerator


func setup(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon


func set_active_room(room_id: int, animate: bool) -> void:
	if dungeon == null:
		return
	if room_id < 0 or room_id >= dungeon.room_infos.size():
		return
	# Delegate authoritative active-room assignment to RoomSystem if present
	if dungeon.room_system:
		# ask RoomSystem to set the active room (it will update dungeon.active_room_id and emit)
		dungeon.room_system.set_active_room(room_id)

	# Update visuals and visited state based on the canonical dungeon.active_room_id
	for index in range(dungeon.room_infos.size()):
		var info_room_id: int = int(dungeon.room_infos[index].get("id", index))
		var is_active: bool = info_room_id == dungeon.active_room_id
		var is_visited: bool = dungeon.is_room_visited(info_room_id)
		var presentation: Dictionary = dungeon.get_room_presentation(info_room_id)
		var visual_root: Node2D = presentation.get("visual_root", null) as Node2D

		# Visible if active or previously visited
		if visual_root:
			visual_root.visible = is_active or is_visited

		# Apply modulate tint for discovered (visited but not active)
		if is_active:
			if visual_root:
				visual_root.modulate = Color(1, 1, 1, 1)
			dungeon.set_room_visited(info_room_id, true)
		elif is_visited:
			if visual_root:
				visual_root.modulate = Color(0.6, 0.6, 0.7, 1)
		else:
			if visual_root:
				visual_root.modulate = Color(1, 1, 1, 1)


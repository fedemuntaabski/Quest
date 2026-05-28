extends RefCounted
class_name DungeonRoomManager

var dungeon: DungeonGenerator


func setup(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon


func set_active_room(room_id: int, animate: bool) -> void:
	if dungeon == null:
		return
	if room_id < 0 or room_id >= dungeon.get_room_layout_infos().size():
		return
	# Delegate authoritative active-room assignment to RoomSystem if present
	if dungeon.room_system:
		# ask RoomSystem to set the active room (it will update dungeon.active_room_id and emit)
		dungeon.room_system.set_active_room(room_id)

	# Update visuals and visited state based on the canonical dungeon.active_room_id
	for room_info in dungeon.get_room_layout_infos():
		var info_room_id: int = int(room_info.get("id", -1))
		var is_active: bool = info_room_id == dungeon.active_room_id
		var is_visited: bool = dungeon.is_room_visited(info_room_id)
		var presentation: DungeonRoomPresentationState = dungeon.get_room_presentation_state(info_room_id)
		var visual_root: Node2D = presentation.visual_root if presentation else null

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

		if OS.is_debug_build():
			print("DungeonRoomManager: room=%d active=%s visited=%s has_visual=%s visible=%s" % [info_room_id, str(is_active), str(is_visited), str(visual_root != null), str(visual_root.visible if visual_root else false)])

	tween_room_lights(animate)


func tween_room_lights(animate: bool) -> void:
	if dungeon == null:
		return

	var tween_duration := dungeon.room_light_transition_seconds if animate else 0.0
	var tween := dungeon.create_tween()
	tween.set_parallel(true)

	for room_info in dungeon.get_room_layout_infos():
		var info_room_id: int = int(room_info.get("id", -1))
		var presentation: DungeonRoomPresentationState = dungeon.get_room_presentation_state(info_room_id)
		var room_light: PointLight2D = presentation.light if presentation else null
		var is_active: bool = info_room_id == dungeon.active_room_id
		var is_visited: bool = dungeon.is_room_visited(info_room_id)

		var target_energy := 0.0
		if is_active:
			target_energy = dungeon.room_light_energy
		elif is_visited:
			target_energy = dungeon.room_light_energy * 0.45
		else:
			target_energy = 0.0

		if room_light == null:
			continue

		if tween_duration <= 0.0:
			room_light.energy = target_energy
		else:
			tween.tween_property(room_light, "energy", target_energy, tween_duration)
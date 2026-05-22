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
		var room_info: Dictionary = dungeon.room_infos[index]
		var info_room_id: int = int(room_info["id"])
		var is_active: bool = info_room_id == dungeon.active_room_id
		var is_visited: bool = bool(room_info.get("visited", false))
		var visual_root: Node2D = room_info.get("visual_root", null) as Node2D

		# Visible if active or previously visited
		if visual_root:
			visual_root.visible = is_active or is_visited

		# Apply modulate tint for discovered (visited but not active)
		if is_active:
			if visual_root:
				visual_root.modulate = Color(1, 1, 1, 1)
			room_info["visited"] = true
		elif is_visited:
			if visual_root:
				visual_root.modulate = Color(0.6, 0.6, 0.7, 1)
		else:
			if visual_root:
				visual_root.modulate = Color(1, 1, 1, 1)

		dungeon.room_infos[index] = room_info

	tween_room_lights(animate)


func tween_room_lights(animate: bool) -> void:
	if dungeon == null:
		return

	var tween_duration := dungeon.room_light_transition_seconds if animate else 0.0
	var tween := dungeon.create_tween()
	tween.set_parallel(true)

	for rinfo in dungeon.room_infos:
		var room_info: Dictionary = rinfo
		var room_light: PointLight2D = room_info.get("light", null) as PointLight2D
		var is_active: bool = int(room_info["id"]) == dungeon.active_room_id
		var is_visited: bool = bool(room_info.get("visited", false))

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
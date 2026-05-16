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

	dungeon.active_room_id = room_id

	for index in range(dungeon.room_infos.size()):
		var room_info := dungeon.room_infos[index]
		var info_room_id: int = room_info["id"]
		var is_active := info_room_id == dungeon.active_room_id
		var visual_root: Node2D = room_info["visual_root"]
		visual_root.visible = is_active

		if is_active:
			room_info["visited"] = true
			dungeon.room_infos[index] = room_info

	tween_room_lights(animate)
	dungeon.emit_signal("room_changed", dungeon.active_room_id)


func tween_room_lights(animate: bool) -> void:
	if dungeon == null:
		return

	var tween_duration := dungeon.room_light_transition_seconds if animate else 0.0
	var tween := dungeon.create_tween()
	tween.set_parallel(true)

	for room_info in dungeon.room_infos:
		var room_light: PointLight2D = room_info["light"]
		var target_energy := 0.0

		if tween_duration <= 0.0:
			room_light.energy = target_energy
		else:
			tween.tween_property(room_light, "energy", target_energy, tween_duration)
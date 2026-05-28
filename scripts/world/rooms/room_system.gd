extends Node
class_name RoomSystem

signal room_changed(room_id: int)

var dungeon: DungeonGenerator = null
var active_room_id: int = -1
var room_areas: Dictionary = {}

func setup(dg: DungeonGenerator) -> void:
	dungeon = dg

func register_room_area(area: Area2D, room_id: int) -> void:
	if area == null or room_id < 0:
		return

	room_areas[room_id] = area

	# Connect Area2D enter events so runtime-created room detectors notify the RoomSystem.
	# Bind the room_id so the handler knows which room fired the event.
	if area:
		var cb := Callable(self, "_on_body_entered").bind(room_id)
		if not area.is_connected("body_entered", cb):
			area.connect("body_entered", cb)


func get_room_area(room_id: int) -> Area2D:
	return room_areas.get(room_id, null)

func _on_body_entered(body: Node2D, room_id: int) -> void:
	if body == null:
		return
	if body.name != "Player" and not body.is_in_group("player"):
		return

	_set_active_room(room_id, false)

func update_player_cell(grid_pos: Vector2i) -> void:
	if dungeon == null:
		return

	var room_id = dungeon.get_room_id_for_cell(grid_pos)
	if room_id != -1:
		_set_active_room(room_id, false)

func set_active_room(room_id: int, enforce_connectivity: bool = true) -> void:
	_set_active_room(room_id, enforce_connectivity)

func _set_active_room(room_id: int, enforce_connectivity: bool = true) -> void:
	if room_id == active_room_id:
		return
	if room_id < 0:
		if OS.is_debug_build():
			print("RoomSystem: ignoring invalid room activation request room_id=%d" % room_id)
		return

	if enforce_connectivity and dungeon != null and dungeon.active_room_id >= 0 and not dungeon.are_rooms_connected(dungeon.active_room_id, room_id):
		if OS.is_debug_build():
			var player := get_tree().get_first_node_in_group("player") as Node2D
			var player_cell := dungeon.world_to_grid_coords(player.global_position) if player else Vector2i(-1, -1)
			print("RoomSystem: rejected activation target=%d active=%d connected=false enforce=true player_cell=%s" % [room_id, dungeon.active_room_id, str(player_cell)])
		return

	if not enforce_connectivity and dungeon != null and dungeon.active_room_id >= 0 and not dungeon.are_rooms_connected(dungeon.active_room_id, room_id):
		if OS.is_debug_build():
			var player := get_tree().get_first_node_in_group("player") as Node2D
			var player_cell := dungeon.world_to_grid_coords(player.global_position) if player else Vector2i(-1, -1)
			print("RoomSystem: accepting non-adjacent sync active=%d target=%d player_cell=%s" % [dungeon.active_room_id, room_id, str(player_cell)])

	active_room_id = room_id
	if dungeon:
		if OS.is_debug_build():
			print("RoomSystem: activation accepted target=%d previous=%d connected=%s" % [room_id, dungeon.active_room_id, str(dungeon.are_rooms_connected(dungeon.active_room_id, room_id) if dungeon.active_room_id >= 0 else true)])
		dungeon.active_room_id = room_id
		if OS.is_debug_build():
			print("RoomSystem: preload visibility active=%d visible_ids=%s" % [room_id, str(_compute_preload_visible_set(room_id).keys())])
	emit_signal("room_changed", room_id)


func _compute_preload_visible_set(room_id: int) -> Dictionary:
	var result: Dictionary = {}
	if dungeon == null or room_id < 0:
		return result

	result[room_id] = true
	for connected_id in dungeon.get_connected_room_ids(room_id):
		var neighbor_id := int(connected_id)
		result[neighbor_id] = true
		if not _is_corridor_room(neighbor_id):
			continue
		for corridor_neighbor_id in dungeon.get_connected_room_ids(neighbor_id):
			result[int(corridor_neighbor_id)] = true

	return result


func _is_corridor_room(room_id: int) -> bool:
	var room_info := dungeon.get_room_layout_info(room_id)
	if room_info.is_empty():
		return false
	var role := String(room_info.get("room_role", "")).to_lower()
	var room_type := String(room_info.get("room_type", "")).to_lower()
	var template := String(room_info.get("template", "")).to_lower()
	var scene_path := String(room_info.get("prefab_scene_path", "")).to_lower()
	return role == "corridor" or room_type == "corridor" or template.contains("corridor") or template.contains("pasillo") or scene_path.contains("/pasillo_")

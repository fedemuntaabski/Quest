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

	for room_info in dungeon.room_infos:
		var room_rect: Rect2i = room_info.get("rect", Rect2i())
		if not room_rect.has_point(grid_pos):
			continue

		_set_active_room(int(room_info.get("id", -1)), false)
		return

func _set_active_room(room_id: int, enforce_connectivity: bool = true) -> void:
	if room_id == active_room_id:
		return

	if enforce_connectivity and dungeon != null and dungeon.active_room_id >= 0 and not dungeon.are_rooms_connected(dungeon.active_room_id, room_id):
		print("RoomSystem: rejected activation of room %d because it's not connected to active room %d" % [room_id, dungeon.active_room_id])
		return

	if not enforce_connectivity and dungeon != null and dungeon.active_room_id >= 0 and not dungeon.are_rooms_connected(dungeon.active_room_id, room_id):
		print("RoomSystem: accepting non-adjacent room sync from player position room %d -> %d" % [dungeon.active_room_id, room_id])

	active_room_id = room_id
	if dungeon:
		dungeon.active_room_id = room_id
	emit_signal("room_changed", room_id)
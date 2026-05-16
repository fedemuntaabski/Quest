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


func get_room_area(room_id: int) -> Area2D:
	return room_areas.get(room_id, null)

func _on_body_entered(body: Node2D, room_id: int) -> void:
	if body == null:
		return
	if body.name != "Player" and not body.is_in_group("player"):
		return

	_set_active_room(room_id)

func update_player_cell(grid_pos: Vector2i) -> void:
	if dungeon == null:
		return

	for room_info in dungeon.room_infos:
		var room_rect: Rect2i = room_info.get("rect", Rect2i())
		if not room_rect.has_point(grid_pos):
			continue

		_set_active_room(int(room_info.get("id", -1)))
		return

func _set_active_room(room_id: int) -> void:
	if room_id == active_room_id:
		return

	if dungeon != null and active_room_id >= 0 and not dungeon.are_rooms_connected(active_room_id, room_id):
		return

	active_room_id = room_id
	emit_signal("room_changed", room_id)
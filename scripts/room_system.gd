extends Node
class_name RoomSystem

signal room_changed(room_id: int)

var dungeon: DungeonGenerator = null
var active_room_id: int = -1

func setup(dg: DungeonGenerator) -> void:
	dungeon = dg

func register_room_area(area: Area2D, room_id: int) -> void:
	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered.bind(room_id))

func _on_body_entered(body: Node2D, room_id: int) -> void:
	if body == null:
		return
	if body.name != "Player" and not body.is_in_group("player"):
		return

	_set_active_room(room_id)

func _set_active_room(room_id: int) -> void:
	if room_id == active_room_id:
		return

	active_room_id = room_id
	emit_signal("room_changed", room_id)
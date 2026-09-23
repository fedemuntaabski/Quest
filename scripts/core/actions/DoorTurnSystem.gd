extends Node
class_name DoorTurnSystem

## DoorTurnSystem: minimal DotE-style turn/room stub. The global turn advances
## only when a door is opened — reveals the target room (basic fog-of-war),
## and ticks resource production (in advance_turn; includes Generator modules' bonus via ResourceManager).
## Enemy invasions are rolled by EnemyManager off turn_advanced.

signal turn_advanced(turn_number: int)
signal door_opened(target_room_id: String)
signal room_revealed(room_id: String, cells: Array[Vector2i])
signal enemy_wave_requested(room_id: String)

var current_turn: int = 0
var rooms: Dictionary = {}   # room_id:String -> {"cells": Array[Vector2i], "visited": bool}


func register_room(room_id: String, cells: Array[Vector2i], visited: bool = false) -> void:
	rooms[room_id] = {"cells": cells, "visited": visited}


func is_room_visited(room_id: String) -> bool:
	return rooms.get(room_id, {}).get("visited", false)


func get_room_cells(room_id: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(rooms.get(room_id, {}).get("cells", []))
	return cells


## Global clock tick: the only place the turn counter moves.
func advance_turn(target_room_id: String) -> void:
	current_turn += 1
	turn_advanced.emit(current_turn)

	var economy := ManagerLocator.get_resource_manager()
	if economy:
		economy.process_turn_production()
		QuestLogger.info(QuestLogger.Category.DOOR, "Turn %d: production tick executed." % current_turn)

	door_opened.emit(target_room_id)


func open_room(room_id: String) -> bool:
	if not rooms.has(room_id):
		QuestLogger.warn(QuestLogger.Category.DOOR, "DoorTurnSystem: unknown room_id '%s'" % room_id)
		return false

	var room: Dictionary = rooms[room_id]
	if room.get("visited", false):
		return false

	room["visited"] = true
	rooms[room_id] = room

	advance_turn(room_id)

	var cells: Array[Vector2i] = []
	cells.assign(room["cells"])
	room_revealed.emit(room_id, cells)

	enemy_wave_requested.emit(room_id)

	QuestLogger.info(QuestLogger.Category.DOOR, "Turn %d: room '%s' revealed." % [current_turn, room_id])
	return true

extends Node
class_name DoorTurnSystem

## DoorTurnSystem: minimal DotE-style turn/room stub. The global turn advances
## only when a door is opened — reveals the target room (basic fog-of-war),
## ticks resource production (plus any built Generator modules' bonus), and
## spawns 1-2 enemies in a random unpowered revealed room via EnemyManager.

signal turn_advanced(turn_number: int)
signal door_opened(target_room_id: String)
signal room_revealed(room_id: String, cells: Array[Vector2i])
signal enemy_wave_requested(room_id: String)

const RESOURCE_GAIN_PER_DOOR := {
	"industry": 2,
	"food": 2,
	"science": 2,
	"dust": 5,
}

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

	var resource_manager := ManagerLocator.get_resource_manager()
	var room_manager := ManagerLocator.get_room_manager()

	if resource_manager:
		resource_manager.add_all(
			RESOURCE_GAIN_PER_DOOR["industry"],
			RESOURCE_GAIN_PER_DOOR["food"],
			RESOURCE_GAIN_PER_DOOR["science"],
			RESOURCE_GAIN_PER_DOOR["dust"]
		)

		if room_manager:
			var industry_bonus := 0
			var food_bonus := 0
			var science_bonus := 0
			for module in room_manager.get_all_modules():
				if module.is_generator():
					var cfg: Dictionary = Module.CATALOG[Module.ModuleType.GENERATOR]
					industry_bonus += int(cfg["industry"])
					food_bonus += int(cfg["food"])
					science_bonus += int(cfg["science"])
			if industry_bonus > 0 or food_bonus > 0 or science_bonus > 0:
				resource_manager.add_all(industry_bonus, food_bonus, science_bonus, 0)
				QuestLogger.info(QuestLogger.Category.MODULE, "Generator bonus applied: +%d industry, +%d food, +%d science." % [industry_bonus, food_bonus, science_bonus])

	var enemy_manager := ManagerLocator.get_enemy_manager()
	if enemy_manager and room_manager:
		var candidates := room_manager.get_unpowered_revealed_room_group_ids()
		if not candidates.is_empty():
			var target: String = candidates[randi() % candidates.size()]
			enemy_manager.spawn_enemies_in_room(target, randi_range(1, 2))

	enemy_wave_requested.emit(room_id)

	QuestLogger.info(QuestLogger.Category.DOOR, "Turn %d: room '%s' revealed." % [current_turn, room_id])
	return true

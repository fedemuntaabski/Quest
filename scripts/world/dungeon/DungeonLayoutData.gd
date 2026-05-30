extends RefCounted
class_name DungeonLayoutData

const DungeonGraph = preload("res://scripts/world/dungeon/DungeonGraph.gd")

# Immutable-by-convention handoff object produced by layout generation.
# DungeonGenerator consumes this data and becomes the authoritative runtime owner.
var floor_cells: Dictionary = {}
var corridor_cells: Dictionary = {}
var room_infos: Array[Dictionary] = []
var graph: DungeonGraph = null
var metadata: Dictionary = {}


func is_valid(expected_room_count: int) -> bool:
	if graph == null:
		return false
	if room_infos.size() != expected_room_count:
		return false
	if floor_cells.is_empty():
		return false
	return true

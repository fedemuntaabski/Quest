extends RefCounted
class_name DungeonLayoutData

# Immutable-by-convention handoff object produced by layout generation.
# DungeonGenerator consumes this data and becomes the authoritative runtime owner.
#
# Ownership boundary:
# - room_layouts / room_infos: compile-time layout data only
# - runtime state and presentation state live elsewhere and must never be
#   merged back into this contract.
var room_layouts: Array[DungeonRoomLayoutState] = []
var floor_cells: Dictionary = {}
var corridor_cells: Dictionary = {}
var room_infos: Array[Dictionary] = []
var graph: DungeonGraph = null
var metadata: Dictionary = {}


func is_valid(expected_room_count: int) -> bool:
	if graph == null:
		return false
	if room_layouts.size() != expected_room_count and room_infos.size() != expected_room_count:
		return false
	if floor_cells.is_empty():
		return false
	return true

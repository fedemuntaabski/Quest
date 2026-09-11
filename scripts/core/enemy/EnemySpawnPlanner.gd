extends RefCounted
class_name EnemySpawnPlanner

static func get_random_floor_cell_in_room(
	room_info: Dictionary,
	wall_cells: Dictionary,
	avoid_center: bool,
	player_cell: Vector2i,
	occupied_spawn_cells: Dictionary,
	dungeon: DungeonGenerator,
	occupancy_manager: OccupancyManager = null
) -> Vector2i:
	var room_cells: Array = room_info["floor_cells"]
	var center_cell: Vector2i = room_info["center_cell"]
	var forbidden_spawn_cells: Dictionary = {}
	if dungeon and dungeon.has_method("get_room_spawn_forbidden_cells"):
		forbidden_spawn_cells = dungeon.get_room_spawn_forbidden_cells(int(room_info.get("id", -1)))

	var candidates: Array[Vector2i] = []
	var avoid_radius: int = 1 if avoid_center else 0

	for raw_cell in room_cells:
		var cell: Vector2i = raw_cell

		if wall_cells.has(cell):
			continue
		if forbidden_spawn_cells.has(cell):
			continue
		if cell == player_cell:
			continue
		if occupied_spawn_cells.has(cell):
			continue
		if occupancy_manager and occupancy_manager.is_cell_blocked(cell):
			continue

		if avoid_radius > 0:
			var dx: int = absi(cell.x - center_cell.x)
			var dy: int = absi(cell.y - center_cell.y)
			if dx <= avoid_radius and dy <= avoid_radius:
				continue

		var near_wall := false
		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if wall_cells.has(cell + dir):
				near_wall = true
				break

		if near_wall:
			continue

		candidates.append(cell)

	if candidates.is_empty():
		return Vector2i(-1, -1)

	return candidates[randi() % candidates.size()]

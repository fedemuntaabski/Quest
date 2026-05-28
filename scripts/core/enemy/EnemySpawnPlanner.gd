extends RefCounted
class_name EnemySpawnPlanner

static func get_random_floor_cell_in_room(
	room_info: Dictionary,
	wall_cells: Dictionary,
	avoid_center: bool,
	player_cell: Vector2i,
	occupied_spawn_cells: Dictionary,
	dungeon: DungeonGenerator
) -> Vector2i:
	# If the authored prefab exposes an explicit enemy spawn marker, prefer it.
	var marker_refs: Dictionary = room_info.get("marker_refs", {})
	var spawn_marker: Node2D = marker_refs.get("SpawnEnemigos", null)
	if spawn_marker != null and dungeon != null:
		return dungeon.world_to_grid_coords((spawn_marker as Node2D).global_position)

	var room_cells: Array = room_info["floor_cells"]
	var center_cell: Vector2i = room_info["center_cell"]
	var forbidden_spawn_cells: Dictionary = {}
	var room_role := String(room_info.get("room_role", "")).to_lower()
	var room_type := String(room_info.get("room_type", "")).to_lower()
	if room_role == "corridor" or room_type == "corridor":
		return Vector2i(-1, -1)
	if dungeon and dungeon.has_method("get_room_spawn_forbidden_cells"):
		forbidden_spawn_cells = dungeon.get_room_spawn_forbidden_cells(int(room_info.get("id", -1)))
	if dungeon:
		for raw_corridor_cell in dungeon.corridor_cells.keys():
			forbidden_spawn_cells[Vector2i(raw_corridor_cell)] = true

	for marker_name in ["Entrada", "Salida"]:
		var marker := marker_refs.get(marker_name, null) as Node2D
		if marker == null or dungeon == null:
			continue
		forbidden_spawn_cells[dungeon.world_to_grid_coords(marker.global_position)] = true

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

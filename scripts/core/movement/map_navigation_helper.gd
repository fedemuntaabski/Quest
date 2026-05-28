extends Node
class_name MapNavigationHelper

var dungeon_generator: DungeonGenerator
var nav_region: NavigationRegion2D
var occupancy_manager: OccupancyManager = null


func setup(dungeon: DungeonGenerator, navigation_region: NavigationRegion2D) -> void:
	dungeon_generator = dungeon
	nav_region = navigation_region

func set_occupancy_manager(manager: OccupancyManager) -> void:
	occupancy_manager = manager


# ── Navigation baking ─────────────────────────────────────────────────────────
func bake_navigation_region() -> void:
	if dungeon_generator == null:
		return

	if nav_region == null:
		push_warning("MapNavigationHelper: NavigationRegion2D missing — enemies won't pathfind.")
		return

	var tile_size: float = dungeon_generator.tile_size
	var floor_cells: Dictionary = dungeon_generator.floor_cells
	var wall_cells: Dictionary = dungeon_generator.wall_cells

	if floor_cells.is_empty():
		return

	var nav_poly := NavigationPolygon.new()
	var seam_warnings: Array[String] = []
	var corridor_cell_count := dungeon_generator.corridor_cells.size()

	# Ajuste fino para evitar problemas de bordes
	var inset: float = 2.0
	var half: float = tile_size * 0.5

	for raw_cell in floor_cells.keys():
		var cell: Vector2i = raw_cell

		# Seguridad extra (aunque no debería pasar)
		if wall_cells.has(cell):
			continue

		var world_pos: Vector2 = dungeon_generator.grid_to_world_coords(cell)

		var verts := PackedVector2Array([
			world_pos + Vector2(-half + inset, -half + inset),
			world_pos + Vector2(half - inset, -half + inset),
			world_pos + Vector2(half - inset, half - inset),
			world_pos + Vector2(-half + inset, half - inset),
		])

		nav_poly.add_outline(verts)

	for room_info in dungeon_generator.get_room_layout_infos():
		if String(room_info.get("room_role", "")).to_lower() != "corridor":
			continue
		var seam_cells: Dictionary = room_info.get("seam_cells", {})
		for raw_cell in seam_cells.keys():
			var seam_cell := Vector2i(raw_cell)
			if not floor_cells.has(seam_cell):
				seam_warnings.append("room=%d seam=%s missing_from_floor" % [int(room_info.get("id", -1)), str(seam_cell)])

	nav_poly.make_polygons_from_outlines()

	# Limpiar y asignar
	nav_region.navigation_polygon = null
	nav_region.navigation_polygon = nav_poly

	print("MapNavigationHelper: NavigationRegion2D baked with floor_cells=%d corridor_cells=%d nav_polygon_sources=%d" % [floor_cells.size(), corridor_cell_count, floor_cells.size()])
	if OS.is_debug_build():
		if seam_warnings.is_empty():
			print("MapNavigationHelper: seam validation passed for corridor cells")
		else:
			print("MapNavigationHelper: seam warnings -> %s" % str(seam_warnings))


# ── Passability checks ────────────────────────────────────────────────────────
func is_cell_walkable(world_position: Vector2) -> bool:
	if dungeon_generator == null:
		return false

	return dungeon_generator.is_cell_walkable(world_position)


func world_to_grid_coords(world_pos: Vector2) -> Vector2i:
	if dungeon_generator == null:
		return Vector2i.ZERO

	if not dungeon_generator.is_ready:
		return Vector2i.ZERO

	return dungeon_generator.world_to_grid_coords(world_pos)


func grid_to_world_coords(grid_pos: Vector2i) -> Vector2:
	if dungeon_generator == null:
		return Vector2.ZERO

	return dungeon_generator.grid_to_world_coords(grid_pos)


func set_wall(world_position: Vector2) -> void:
	if dungeon_generator:
		dungeon_generator.set_wall_at_world(world_position)


func clear_cell(world_position: Vector2) -> void:
	if dungeon_generator:
		dungeon_generator.clear_cell_at_world(world_position)


func get_adjacent_walkable_cells(world_position: Vector2) -> Array:
	if dungeon_generator == null:
		return []

	return dungeon_generator.get_adjacent_walkable_cells(world_position)


func is_within_bounds(grid_pos: Vector2i) -> bool:
	if dungeon_generator == null:
		return false

	return dungeon_generator.is_within_bounds(grid_pos)


# ── Pathfinding ───────────────────────────────────────────────────────────────
func find_path(
	start: Vector2i,
	goal: Vector2i,
	allow_goal_occupied: bool = false,
	allowed_rect: Rect2i = Rect2i(),
	use_allowed_rect: bool = false
) -> Array[Vector2i]:
	var open_set: Array[Vector2i] = []
	var came_from: Dictionary = {}

	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	open_set.append(start)
	g_score[start] = 0.0
	f_score[start] = float(start.distance_to(goal))

	while open_set.size() > 0:
		var current: Vector2i = open_set[0]

		for node in open_set:
			if float(f_score.get(node, INF)) < float(f_score.get(current, INF)):
				current = node

		if current == goal:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		for neighbor in _get_neighbors(current, goal, allow_goal_occupied, allowed_rect, use_allowed_rect):
			var tentative_g: float = float(g_score.get(current, INF)) + 1.0

			if tentative_g < float(g_score.get(neighbor, INF)):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + float(neighbor.distance_to(goal))

				if not open_set.has(neighbor):
					open_set.append(neighbor)

	return []


func _get_neighbors(
	cell: Vector2i,
	goal: Vector2i,
	allow_goal_occupied: bool,
	allowed_rect: Rect2i,
	use_allowed_rect: bool
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	var dirs: Array[Vector2i] = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT
	]

	for d in dirs:
		var n: Vector2i = cell + d
		if use_allowed_rect and not allowed_rect.has_point(n):
			continue
		if not is_cell_walkable(grid_to_world_coords(n)):
			continue

		if occupancy_manager and occupancy_manager.is_cell_blocked(n):
			if not (allow_goal_occupied and n == goal):
				continue

		result.append(n)

	return result


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]

	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)

	return path


# Centralized pathfinding API
func find_path_preferred(
    start: Vector2i,
    goal: Vector2i,
    allow_goal_occupied: bool = false,
    allowed_rect: Rect2i = Rect2i(),
    use_allowed_rect: bool = false,
    mode: String = "auto"
) -> Array[Vector2i]:
	# For compatibility and safety, default to the existing A* implementation.
	# This wrapper centralizes the public API so we can later switch
	# between pathfinding backends (A* vs NavigationRegion) without
	# changing callers.
	# mode values: "auto" (default), "astar", "nav"
	if mode == "astar" or mode == "auto":
		return find_path(start, goal, allow_goal_occupied, allowed_rect, use_allowed_rect)
	# Future: implement NavigationRegion-based pathfinding when requested.
	# For now, fallback to A* to preserve existing behavior.
	return find_path(start, goal, allow_goal_occupied, allowed_rect, use_allowed_rect)
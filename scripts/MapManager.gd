extends Node2D

class_name MapManager

@onready var dungeon_generator: DungeonGenerator = $DungeonGenerator
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D

var hovered_cell: Vector2i = Vector2i(-999, -999)
signal hover_changed(cell: Vector2i)

func update_hover(world_pos: Vector2) -> void:
	var new_cell := world_to_grid(world_pos)

	print("hover:", new_cell) # DEBUG

	if new_cell == hovered_cell:
		return

	hovered_cell = new_cell
	hover_changed.emit(new_cell)

func _on_hover_changed(cell: Vector2i) -> void:
	print("DRAW CELL:", cell)
	hovered_cell = cell
	queue_redraw()

func is_walkable_cell(grid_pos: Vector2i) -> bool:
	if dungeon_generator == null:
		return false

	if not dungeon_generator.is_within_bounds(grid_pos):
		return false

	if dungeon_generator.wall_cells.has(grid_pos):
		return false

	return dungeon_generator.floor_cells.has(grid_pos)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	print("UPDATE HOVER CALLED")
	var world_pos := cam.get_global_mouse_position()
	update_hover(world_pos)
	

func world_to_grid(world: Vector2) -> Vector2i:
	return dungeon_generator.world_to_grid_coords(world)

func grid_to_world(grid: Vector2i) -> Vector2:
	return dungeon_generator.grid_to_world_coords(grid)

# Enemy tracking for combat detection
var enemies_on_map: Dictionary = {}  # Key: grid cell (Vector2i), Value: CharacterStats



func _ready() -> void:
	add_to_group("map_manager") # 👈 CLAVE (sin esto es null en TileHighlighter)
	if dungeon_generator == null:
		push_error("MapManager: DungeonGenerator node is missing.")
		return

	var player := get_node_or_null("Player") as CharacterBody2D
	
	dungeon_generator.generate_dungeon(player)

	# Asegurar que el dungeon terminó de generarse
	if dungeon_generator.floor_cells.is_empty():
		push_warning("MapManager: Dungeon generation failed or empty.")
		return

	_bake_navigation_region()

# ── Navigation baking ─────────────────────────────────────────────────────────
func _bake_navigation_region() -> void:
	if nav_region == null:
		push_warning("MapManager: NavigationRegion2D missing — enemies won't pathfind.")
		return

	var tile_size: float = dungeon_generator.tile_size
	var floor_cells: Dictionary = dungeon_generator.floor_cells
	var wall_cells: Dictionary = dungeon_generator.wall_cells

	if floor_cells.is_empty():
		return

	var nav_poly := NavigationPolygon.new()

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

	nav_poly.make_polygons_from_outlines()

	# Limpiar y asignar
	nav_region.navigation_polygon = null
	nav_region.navigation_polygon = nav_poly

	print("MapManager: NavigationRegion2D baked with %d floor cells." % floor_cells.size())

# ── Passability checks ────────────────────────────────────────────────────────
func is_cell_walkable(world_position: Vector2) -> bool:
	if dungeon_generator == null:
		return false
	return dungeon_generator.is_cell_walkable(world_position)

func world_to_grid_coords(world_pos: Vector2) -> Vector2i:
	if dungeon_generator == null:
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

# ── Enemy tracking ────────────────────────────────────────────────────────────
func register_enemy(world_position: Vector2, enemy_stats: CharacterStats) -> void:
	var grid_pos := world_to_grid_coords(world_position)
	enemies_on_map[grid_pos] = enemy_stats

func unregister_enemy(world_position: Vector2) -> void:
	var grid_pos := world_to_grid_coords(world_position)
	if enemies_on_map.has(grid_pos):
		enemies_on_map.erase(grid_pos)

func get_enemy_at_cell(grid_pos: Vector2i) -> Node:
	if dungeon_generator == null:
		return null

	for enemy in enemies_on_map.values():
		if enemy == null:
			continue

		if world_to_grid(enemy.global_position) == grid_pos:
			return enemy

	return null

func find_path(start: Vector2i, goal: Vector2i) -> Array:
	var open_set = []
	var came_from = {}

	var g_score = {}
	var f_score = {}

	open_set.append(start)
	g_score[start] = 0
	f_score[start] = start.distance_to(goal)

	while open_set.size() > 0:
		var current = open_set[0]

		for node in open_set:
			if f_score.get(node, INF) < f_score.get(current, INF):
				current = node

		if current == goal:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		for neighbor in _get_neighbors(current):
			var tentative_g = g_score.get(current, INF) + 1

			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + neighbor.distance_to(goal)

				if not open_set.has(neighbor):
					open_set.append(neighbor)

	return []

func _get_neighbors(cell: Vector2i) -> Array:
	var result = []

	var dirs = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT
	]

	for d in dirs:
		var n = cell + d
		if is_walkable_cell(n):
			result.append(n)

	return result

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path = [current]

	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)

	return path

func has_enemy_at_cell(world_position: Vector2) -> bool:
	var grid_pos := world_to_grid_coords(world_position)
	return enemies_on_map.has(grid_pos)

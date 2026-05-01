extends Node2D

class_name MapManager

@onready var dungeon_generator: DungeonGenerator = $DungeonGenerator
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D

# Enemy tracking for combat detection
var enemies_on_map: Dictionary = {}  # Key: grid cell (Vector2i), Value: CharacterStats

func _ready() -> void:
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

func get_enemy_at_cell(world_position: Vector2) -> CharacterStats:
	var grid_pos := world_to_grid_coords(world_position)
	return enemies_on_map.get(grid_pos, null)

func has_enemy_at_cell(world_position: Vector2) -> bool:
	var grid_pos := world_to_grid_coords(world_position)
	return enemies_on_map.has(grid_pos)

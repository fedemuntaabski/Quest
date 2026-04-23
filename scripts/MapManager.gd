extends Node2D

class_name MapManager

@onready var dungeon_generator: DungeonGenerator = $DungeonGenerator

# Enemy tracking for combat detection
var enemies_on_map: Dictionary = {}  # Key: grid cell (Vector2i), Value: CharacterStats

func _ready() -> void:
	if dungeon_generator == null:
		push_error("MapManager: DungeonGenerator node is missing.")
		return

	var player := get_node_or_null("Player") as CharacterBody2D
	dungeon_generator.generate_dungeon(player)

# Check if a world position is walkable
func is_cell_walkable(world_position: Vector2) -> bool:
	if dungeon_generator == null:
		return false
	return dungeon_generator.is_cell_walkable(world_position)

# Convert world position to grid coordinates
func world_to_grid_coords(world_pos: Vector2) -> Vector2i:
	if dungeon_generator == null:
		return Vector2i.ZERO
	return dungeon_generator.world_to_grid_coords(world_pos)

# Convert grid coordinates to world position
func grid_to_world_coords(grid_pos: Vector2i) -> Vector2:
	if dungeon_generator == null:
		return Vector2.ZERO
	return dungeon_generator.grid_to_world_coords(grid_pos)

# Set a cell as a wall (obstacle)
func set_wall(world_position: Vector2) -> void:
	if dungeon_generator:
		dungeon_generator.set_wall_at_world(world_position)

# Clear a cell
func clear_cell(world_position: Vector2) -> void:
	if dungeon_generator:
		dungeon_generator.clear_cell_at_world(world_position)

# Get adjacent walkable cells
func get_adjacent_walkable_cells(world_position: Vector2) -> Array:
	if dungeon_generator == null:
		return []
	return dungeon_generator.get_adjacent_walkable_cells(world_position)

# Check if position is within map bounds
func is_within_bounds(grid_pos: Vector2i) -> bool:
	if dungeon_generator == null:
		return false
	return dungeon_generator.is_within_bounds(grid_pos)

# ENEMY TRACKING FOR COMBAT
# Register an enemy at a world position
func register_enemy(world_position: Vector2, enemy_stats: CharacterStats) -> void:
	var grid_pos := world_to_grid_coords(world_position)
	enemies_on_map[grid_pos] = enemy_stats

# Unregister an enemy from a position
func unregister_enemy(world_position: Vector2) -> void:
	var grid_pos := world_to_grid_coords(world_position)
	if enemies_on_map.has(grid_pos):
		enemies_on_map.erase(grid_pos)

# Check if there's an enemy at a position
func get_enemy_at_cell(world_position: Vector2) -> CharacterStats:
	var grid_pos := world_to_grid_coords(world_position)
	return enemies_on_map.get(grid_pos, null)

# Check if a cell contains an enemy
func has_enemy_at_cell(world_position: Vector2) -> bool:
	var grid_pos := world_to_grid_coords(world_position)
	return enemies_on_map.has(grid_pos)

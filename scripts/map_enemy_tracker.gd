extends Node
class_name MapEnemyTracker

var dungeon_generator: DungeonGenerator
var enemies_on_map: Dictionary = {} # Key: Vector2i, Value: Node2D


func setup(dungeon: DungeonGenerator) -> void:
	dungeon_generator = dungeon


func world_to_grid_coords(world_pos: Vector2) -> Vector2i:
	if dungeon_generator == null:
		return Vector2i.ZERO

	if not dungeon_generator.is_ready:
		return Vector2i.ZERO

	return dungeon_generator.world_to_grid_coords(world_pos)


func register_enemy(world_position: Vector2, enemy_node: Node2D) -> void:
	if dungeon_generator == null or enemy_node == null:
		return

	var grid_pos: Vector2i = world_to_grid_coords(world_position)
	enemies_on_map[grid_pos] = enemy_node


func unregister_enemy(world_position: Vector2) -> void:
	if dungeon_generator == null:
		return

	var grid_pos: Vector2i = world_to_grid_coords(world_position)
	if enemies_on_map.has(grid_pos):
		enemies_on_map.erase(grid_pos)


func get_enemy_at_cell(grid_pos: Vector2i) -> Node2D:
	if dungeon_generator == null:
		return null

	for enemy in enemies_on_map.values():
		if enemy == null:
			continue

		if enemy is Node2D and world_to_grid_coords(enemy.global_position) == grid_pos:
			return enemy

	return null


func has_enemy_at_cell(world_position: Vector2) -> bool:
	var grid_pos: Vector2i = world_to_grid_coords(world_position)
	return enemies_on_map.has(grid_pos)
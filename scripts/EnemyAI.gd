extends Node
class_name EnemyAI

static func get_action(enemy: Enemy, player: CharacterBody2D, map_manager: MapManager) -> Dictionary:
	if enemy == null or player == null or map_manager == null:
		return {"type": "idle"}

	var enemy_cell: Vector2i = map_manager.world_to_grid(enemy.global_position)
	var player_cell: Vector2i = map_manager.world_to_grid(player.global_position)

	var enemy_stats: CharacterStats = enemy.stats
	var player_stats: CharacterStats = player.get_node_or_null("Stats") as CharacterStats
	if player_stats == null:
		return {"type": "idle"}

	var path: Variant = map_manager.find_path(enemy_cell, player_cell)

	# NO PATH → IDLE
	if path.is_empty():
		return {
			"type": "idle",
			"name": "wait"
		}

	# SI ESTÁ CERCA (1 paso) → INTENT DE ATAQUE
	if path.size() == 1:
		return {
			"type": "attack",
			"name": "melee_attack",
			"target_cell": player_cell
		}

	var next_cell: Vector2i = path[1]
	var dir: Vector2i = next_cell - enemy_cell

	# SI EL SIGUIENTE ES EL PLAYER → INTENT DE ATAQUE
	if next_cell == player_cell:
		return {
			"type": "attack",
			"name": "melee_attack",
			"target_cell": player_cell
		}

	# MOVE INTENT
	return {
		"type": "move",
		"move": dir,
		"name": "move_towards_player"
	}
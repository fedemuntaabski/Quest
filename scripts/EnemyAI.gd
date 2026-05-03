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
			"damage": 0,
			"move": Vector2i.ZERO,
			"name": "wait"
		}

	# SI YA ESTÁ AL LADO → ATACA
	if path.size() == 1:
		return _melee_attack(enemy, player)

	var next_cell: Vector2i = path[1]
	var dir: Vector2i = next_cell - enemy_cell

	# SI EL SIGUIENTE ES EL PLAYER → ATACA
	if next_cell == player_cell:
		return _melee_attack(enemy, player)

	# MOVE
	return {
		"type": "move",
		"move": dir,
		"damage": 0,
		"attacker": enemy,
		"target": player,
		"name": "move_towards_player"
	}


static func _melee_attack(enemy: Enemy, player: CharacterBody2D) -> Dictionary:
	var enemy_stats: CharacterStats = enemy.stats
	var player_stats: CharacterStats = player.get_node_or_null("Stats") as CharacterStats

	var damage := randi_range(1, 6)

	if enemy_stats.current_hp < enemy_stats.max_hp * 0.3:
		damage = max(1, damage - 2)

	return {
		"type": "attack",
		"damage": damage,
		"attacker": enemy,
		"target": player,
		"move": Vector2i.ZERO,
		"name": "melee_attack"
	}
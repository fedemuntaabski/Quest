extends Node
class_name EnemyAI

static func get_action(enemy: Enemy, player: CharacterBody2D, map_manager: MapManager) -> Dictionary:
	if enemy == null or player == null or map_manager == null:
		return {"type": "idle"}

	var enemy_cell: Vector2i = map_manager.world_to_grid(enemy.global_position)
	var player_cell: Vector2i = map_manager.world_to_grid(player.global_position)

	var _enemy_stats: CharacterStats = enemy.stats
	var player_stats: CharacterStats = player.get_node_or_null("Stats") as CharacterStats
	if player_stats == null:
		return {"type": "idle"}

	# Strategy dispatcher based on enemy_data.ai_type (data-driven)
	var ai_type: String = "melee_chase"
	if enemy and enemy.enemy_data:
		ai_type = str(enemy.enemy_data.ai_type).to_lower()

	match ai_type:
		"aggressive":
			return _ai_aggressive(enemy, player, map_manager, enemy_cell, player_cell)
		"ranged":
			return _ai_ranged(enemy, player, map_manager, enemy_cell, player_cell)
		"slow_tank":
			return _ai_slow_tank(enemy, player, map_manager, enemy_cell, player_cell)
		"boss":
			return _ai_boss(enemy, player, map_manager, enemy_cell, player_cell)
		_:
			return _ai_melee_chase(enemy, player, map_manager, enemy_cell, player_cell)


static func _ai_melee_chase(enemy: Enemy, _player: CharacterBody2D, map_manager: MapManager, enemy_cell: Vector2i, player_cell: Vector2i) -> Dictionary:
	var path: Variant = map_manager.find_path(enemy_cell, player_cell, enemy)
	if path.is_empty():
		return {"type":"idle","name":"wait"}
	if path.size() == 1:
		return {"type":"attack","name":"melee_attack","target_cell":player_cell}
	var next_cell: Vector2i = path[1]
	var dir: Vector2i = next_cell - enemy_cell
	if next_cell == player_cell:
		return {"type":"attack","name":"melee_attack","target_cell":player_cell}
	return {"type":"move","move":dir,"name":"move_towards_player"}


static func _ai_aggressive(enemy: Enemy, player: CharacterBody2D, map_manager: MapManager, enemy_cell: Vector2i, player_cell: Vector2i) -> Dictionary:
	# Aggressive: behave like melee chase but prefer closing quickly
	return _ai_melee_chase(enemy, player, map_manager, enemy_cell, player_cell)


static func _ai_ranged(enemy: Enemy, player: CharacterBody2D, map_manager: MapManager, enemy_cell: Vector2i, player_cell: Vector2i) -> Dictionary:
	var path: Variant = map_manager.find_path(enemy_cell, player_cell, enemy)
	if path.is_empty():
		return {"type":"idle","name":"wait"}
	var dist: int = int(path.size())
	var comp := enemy.get_combat_component()
	var desired_range := 3
	if comp:
		desired_range = max(2, comp.attack_range + 1)

	# If can attack from current position and in range -> attack
	if comp and comp.can_attack(player):
		return {"type":"attack","name":"ranged_attack","target_cell":player_cell}

	# If too close, try to step away
	if dist <= desired_range and dist > 1:
		# attempt to move away along inverse of next step
		if path.size() > 1:
			var next_cell: Vector2i = path[1]
			var away_dir: Vector2i = enemy_cell - next_cell
			return {"type":"move","move":away_dir,"name":"move_away"}

	# otherwise move toward to keep optimal range
	if path.size() > 1:
		var next_cell2: Vector2i = path[1]
		var dir2: Vector2i = next_cell2 - enemy_cell
		return {"type":"move","move":dir2,"name":"move_towards_player"}

	return {"type":"idle","name":"wait"}


static func _ai_slow_tank(enemy: Enemy, _player: CharacterBody2D, map_manager: MapManager, enemy_cell: Vector2i, player_cell: Vector2i) -> Dictionary:
	# Slow tank: sometimes skip moving, otherwise chase slowly
	var path: Variant = map_manager.find_path(enemy_cell, player_cell, enemy)
	if path.is_empty():
		return {"type":"idle","name":"wait"}
	# If adjacent, attack
	if path.size() == 1:
		return {"type":"attack","name":"melee_attack","target_cell":player_cell}
	# 50% chance to wait (simulating slow reaction)
	if randi() % 100 < 50:
		return {"type":"idle","name":"wait"}
	var next_cell3: Vector2i = path[1]
	var dir3: Vector2i = next_cell3 - enemy_cell
	return {"type":"move","move":dir3,"name":"slow_move"}


static func _ai_boss(enemy: Enemy, player: CharacterBody2D, map_manager: MapManager, enemy_cell: Vector2i, player_cell: Vector2i) -> Dictionary:
	# Boss uses melee chase for now; extend later
	return _ai_melee_chase(enemy, player, map_manager, enemy_cell, player_cell)
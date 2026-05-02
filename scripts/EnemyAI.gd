extends Node
class_name EnemyAI

# ─────────────────────────────────────────────
# MAIN ENTRY
# ─────────────────────────────────────────────
static func get_action(enemy: CharacterStats, player: CharacterStats, map_manager: MapManager) -> Dictionary:
	if enemy == null or player == null or map_manager == null:
		return {"type": "idle"}

	var enemy_cell: Vector2i = map_manager.world_to_grid(enemy.global_position)
	var player_cell: Vector2i = map_manager.world_to_grid(player.global_position)

	var path : Variant = map_manager.find_path(enemy_cell, player_cell)

	# ─────────────────────────────────────────────
	# NO PATH → IDLE
	# ─────────────────────────────────────────────
	if path.is_empty():
		return {
			"type": "idle",
			"damage": 0,
			"move": Vector2i.ZERO,
			"name": "wait"
		}

	# ─────────────────────────────────────────────
	# NEXT STEP IN PATH
	# ─────────────────────────────────────────────
	if path.size() == 1:
		return _melee_attack(enemy, player)

	var next_cell: Vector2i = path[1]
	var dir: Vector2i = next_cell - enemy_cell

	# ─────────────────────────────────────────────
	# BUMP CHECK (enemy reaches player)
	# ─────────────────────────────────────────────
	if next_cell == player_cell:
		return _melee_attack(enemy, player)

	# ─────────────────────────────────────────────
	# MOVE ACTION
	# ─────────────────────────────────────────────
	return {
		"type": "move",
		"move": dir,
		"damage": 0,
		"attacker": enemy,
		"target": player,
		"name": "move_towards_player"
	}

# ─────────────────────────────────────────────
# MELEE ATTACK
# ─────────────────────────────────────────────
static func _melee_attack(enemy: CharacterStats, player: CharacterStats) -> Dictionary:
	var damage := randi_range(1, 6)

	# low hp = weaker behavior (simple AI tuning)
	if enemy.current_hp < enemy.max_hp * 0.3:
		damage = max(1, damage - 2)

	return {
		"type": "attack",
		"damage": damage,
		"attacker": enemy,
		"target": player,
		"move": Vector2i.ZERO,
		"name": "melee_attack"
	}
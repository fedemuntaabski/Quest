extends Node
class_name EnemyAI

static func get_action(enemy: CharacterStats, player: CharacterStats) -> Dictionary:
	var base_damage = randi_range(1, 6)

	if enemy.current_hp < enemy.max_hp * 0.3:
		base_damage = max(1, base_damage - 2)

	return {
		"type": "attack",
		"damage": base_damage,
		"attacker": enemy,
		"target": player,
		"name": "basic_attack" 
	}
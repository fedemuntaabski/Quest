extends Node
class_name CombatRules

static func resolve_player_attack(card: SkillCard, player: CharacterStats, enemy: CharacterStats) -> Dictionary:
	var result = card.calculate_success(player)

	return {
		"attacker": player.character_name,
		"skill": card.card_name,
		"roll": result.get("roll", 0),
		"modifier": result.get("character_modifier", 0),
		"dice_bonus": result.get("dice_bonus", 0),
		"total": result.get("total", 0),
		"intensity": result.get("intensity", 0),
		"damage": result.get("damage", 0),
		"target_hp_before": enemy.current_hp
	}

static func resolve_enemy_action(action: Dictionary, player: CharacterStats) -> Dictionary:
	return {
		"attacker": action["attacker"].character_name,
		"skill": action.get("name", "basic_attack"),
		"damage": action["damage"],
		"target_hp_before": player.current_hp
	}
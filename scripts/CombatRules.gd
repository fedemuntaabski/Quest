extends Node
class_name CombatRules

static func resolve_attack(action: Dictionary, attacker: CharacterStats, target: CharacterStats) -> Dictionary:
	var result = action.get("result", {})

	return {
		"attacker": attacker.character_name,
		"target": target.character_name,
		"skill": action.get("name", "unknown"),
		"roll": result.get("roll", 0),
		"modifier": result.get("character_modifier", 0),
		"dice_bonus": result.get("dice_bonus", 0),
		"total": result.get("total", 0),
		"intensity": result.get("intensity", 0),
		"damage": result.get("damage", 0),
		"target_hp_before": target.current_hp
	}

static func resolve_action(action: Dictionary, attacker: CharacterStats, target: CharacterStats) -> Dictionary:
	return resolve_attack(action, attacker, target)

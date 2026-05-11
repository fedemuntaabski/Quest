extends Node
class_name CombatResolver

const DiceSystem = preload("res://scripts/DiceSystem.gd")

static func resolve_attack(attacker: CharacterStats, target: CharacterStats, stat_key: String = "strength", base_damage: int = 0) -> Dictionary:
	if attacker == null or target == null:
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "missing_stats"
		}

	var attack_stat: int = _get_stat_value(attacker, stat_key)
	var base_total: int = base_damage + attack_stat
	var dice_roll: int = DiceSystem.roll_d6()
	var multiplier: float = DiceSystem.get_damage_multiplier(dice_roll)
	var damage: int = max(1, int(round(float(base_total) * multiplier)))
	var crit: bool = dice_roll == 6

	return {
		"hit": true,
		"crit": crit,
		"damage": damage,
		"dice_roll": dice_roll,
		"damage_multiplier": multiplier,
		"base_total": base_total,
		"stat_key": stat_key,
		"stat_value": attack_stat
	}

static func _get_stat_value(stats: CharacterStats, stat_key: String) -> int:
	match stat_key:
		"strength":
			return stats.get_total_strength()
		"magic":
			return stats.get_total_magic()
		"dexterity":
			return stats.get_total_dexterity()
		_:
			return stats.get_total_strength()

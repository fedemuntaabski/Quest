extends Node
class_name CombatResolver

const DiceSystem = preload("res://scripts/managers/DiceSystem.gd")
const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")

static func resolve_attack(attacker: CharacterStats, target: CharacterStats, stat_key: String = "strength", base_damage: int = 0, damage_scaling: float = 1.0) -> Dictionary:
	if attacker == null or target == null:
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "missing_stats"
		}

	# Calculate dodge chance from target's dexterity and apply dodge check
	var attack_stat: int = _get_stat_value(attacker, stat_key)
	var attack_bonus: int = StatBalance.get_scaled_stat_bonus(stat_key, attack_stat, damage_scaling)
	var base_total: int = base_damage + attack_bonus

	var target_dex: int = 0
	if target != null:
		target_dex = target.get_total_dexterity()

	var dodge_chance: float = StatBalance.get_dexterity_dodge_chance(target_dex)
	if randf() < dodge_chance:
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "dodge",
			"dodge_chance": dodge_chance,
			"target_dex": target_dex
		}

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
		"stat_value": attack_stat,
		"attack_bonus": attack_bonus,
		"dodge_chance": dodge_chance,
		"target_dex": target_dex
	}

static func _get_stat_value(stats: CharacterStats, stat_key: String) -> int:
	if stats == null:
		return 0
	return stats.get_total_stat(stat_key)

extends Node
class_name CombatResolver

const CombatFormula = preload("res://scripts/core/combat/CombatFormula.gd")

static func resolve_attack(
	attacker: CharacterStats,
	target: CharacterStats,
	stat_key: String = "strength",
	base_damage: int = 0,
	damage_scaling: float = 1.0
) -> Dictionary:

	if attacker == null or target == null:
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "missing_stats"
		}

	var attack_stat := attacker.get_total_stat(stat_key)

	var attack_bonus := CombatFormula.get_attack_bonus(
		stat_key,
		attack_stat,
		damage_scaling
	)

	var target_dex := target.get_total_dexterity()

	var dodge_chance := CombatFormula.get_dodge_chance(
		target_dex
	)

	if randf() < dodge_chance:
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "dodge",
			"dodge_chance": dodge_chance,
			"target_dex": target_dex
		}

	var roll_data := CombatFormula.roll_damage_multiplier()

	var damage := CombatFormula.calculate_final_damage(
		base_damage,
		attack_bonus,
		roll_data["multiplier"]
	)

	return {
		"hit": true,
		"crit": roll_data["crit"],
		"damage": damage,
		"dice_roll": roll_data["dice_roll"],
		"damage_multiplier": roll_data["multiplier"],
		"base_total": base_damage + attack_bonus,
		"stat_key": stat_key,
		"stat_value": attack_stat,
		"attack_bonus": attack_bonus,
		"dodge_chance": dodge_chance,
		"target_dex": target_dex
	}
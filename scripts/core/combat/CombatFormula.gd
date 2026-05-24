extends RefCounted
class_name CombatFormula

const DiceSystem = preload("res://scripts/managers/DiceSystem.gd")
const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")

static func get_attack_bonus(
	stat_key: String,
	stat_value: int,
	damage_scaling: float
) -> int:

	return StatBalance.get_scaled_stat_bonus(
		stat_key,
		stat_value,
		damage_scaling
	)

static func get_dodge_chance(target_dexterity: int) -> float:
	return StatBalance.get_dexterity_dodge_chance(
		target_dexterity
	)

static func roll_damage_multiplier() -> Dictionary:
	var dice_roll := DiceSystem.roll_d6()

	return {
		"dice_roll": dice_roll,
		"multiplier": DiceSystem.get_damage_multiplier(dice_roll),
		"crit": dice_roll == 6
	}

static func calculate_final_damage(
	base_damage: int,
	attack_bonus: int,
	damage_multiplier: float
) -> int:

	var total := base_damage + attack_bonus

	return max(
		1,
		int(round(float(total) * damage_multiplier))
	)
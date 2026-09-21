extends RefCounted
class_name CombatFormula

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

## Deterministic replacement for the old d6 roll: spending your last AP on an
## attack (going all-in) lands a guaranteed critical hit.
static func resolve_damage_multiplier(attacker_current_ap: int) -> Dictionary:
	var is_finisher := attacker_current_ap <= 1

	return {
		"multiplier": 1.5 if is_finisher else 1.0,
		"crit": is_finisher
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
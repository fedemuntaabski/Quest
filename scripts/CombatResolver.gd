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

	# Calculate dodge chance from target's dexterity and apply dodge check
	var attack_stat: int = _get_stat_value(attacker, stat_key)
	var base_total: int = base_damage + attack_stat

	var target_dex: int = 0
	if target != null:
		target_dex = target.get_total_dexterity()

	var dodge_chance: float = _dex_to_dodge(target_dex)
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
		"dodge_chance": dodge_chance,
		"target_dex": target_dex
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

static func _dex_to_dodge(dex: int) -> float:
	# Scale dodge chance linearly: dex 1 -> 2.5%, dex 10 -> 25%
	if dex <= 1:
		return 0.025
	if dex >= 10:
		return 0.25
	var t: float = float(dex - 1) / float(9) # normalized 0..1
	return lerp(0.025, 0.25, t)

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

	var attack_stat := _get_stat_value(attacker, stat_key)
	var dodge_stat := target.get_total_dexterity()

	var attack_roll := DiceSystem.roll_d6()
	var dodge_roll := DiceSystem.roll_d6()

	var attack_total := attack_roll + attack_stat
	var dodge_total := dodge_roll + dodge_stat
	var hit := attack_total >= dodge_total

	var crit_roll := DiceSystem.roll_d6()
	var crit := hit and crit_roll == 6

	var damage := 0
	var damage_roll := 0

	if hit:
		damage_roll = DiceSystem.roll_d6()
		damage = max(1, damage_roll + attack_stat + base_damage)
		if crit:
			damage += DiceSystem.roll_d6()

	return {
		"hit": hit,
		"crit": crit,
		"damage": damage,
		"attack_roll": attack_roll,
		"dodge_roll": dodge_roll,
		"attack_total": attack_total,
		"dodge_total": dodge_total,
		"damage_roll": damage_roll,
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

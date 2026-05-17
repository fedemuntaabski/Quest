extends CardEffect
class_name DamageEffect

const CombatResolverScript = preload("res://scripts/core/combat/CombatResolver.gd")

@export var base_damage: int = 0
@export var stat_key: String = "strength"
@export var damage_scaling: float = 1.0
@export var uses_hit_roll: bool = true

func apply(source_stats: CharacterStats, target_stats: CharacterStats, _context: Dictionary) -> Dictionary:
	if source_stats == null or target_stats == null:
		return {
			"effect": "damage",
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "missing_stats"
		}

	var stat_value := _get_stat_value(source_stats, stat_key)
	var scaled_bonus := int(round(float(stat_value) * damage_scaling))
	var resolved_base := base_damage + scaled_bonus
	var result := CombatResolverScript.resolve_attack(source_stats, target_stats, stat_key, resolved_base)
	result["effect"] = "damage"
	return result

func _get_stat_value(stats: CharacterStats, key: String) -> int:
	match key:
		"strength":
			return stats.get_total_strength()
		"magic":
			return stats.get_total_magic()
		"dexterity":
			return stats.get_total_dexterity()
		_:
			return stats.get_total_strength()

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

	var result := CombatResolverScript.resolve_attack(source_stats, target_stats, stat_key, base_damage, damage_scaling)
	result["effect"] = "damage"
	return result

func _get_stat_value(stats: CharacterStats, key: String) -> int:
	if stats == null:
		return 0
	return stats.get_total_stat(key)

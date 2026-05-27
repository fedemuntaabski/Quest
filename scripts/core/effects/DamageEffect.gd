extends CardEffect
class_name DamageEffect

const CombatResolverScript = preload("res://scripts/core/combat/CombatResolver.gd")

@export var base_damage: int = 0
@export var stat_key: String = "strength"
@export var damage_scaling: float = 1.0

func apply(source_stats: CharacterStats, target_stats: CharacterStats, _context: Dictionary) -> Dictionary:
	if source_stats == null or target_stats == null:
		return {
			"effect": "damage",
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "missing_stats"
		}

	var target_actor := _context.get("target_actor", null) as Node
	var result := CombatResolverScript.resolve_attack(source_stats, target_stats, stat_key, base_damage, damage_scaling, target_actor)
	result["effect"] = "damage"
	return result

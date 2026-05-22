extends CardEffect
class_name HealEffect

@export var base_heal: int = 0
@export var stat_key: String = "magic"
@export var heal_scaling: float = 0.0
@export var apply_to_source: bool = true

func apply(source_stats: CharacterStats, target_stats: CharacterStats, _context: Dictionary) -> Dictionary:
	var receiver := source_stats if apply_to_source else target_stats
	if receiver == null:
		return {
			"effect": "heal",
			"applied": false,
			"amount": 0,
			"reason": "missing_target"
		}

	var stat_value := _get_stat_value(source_stats, stat_key)
	var scaled_bonus := int(round(float(stat_value) * heal_scaling))
	var amount: int = max(0, base_heal + scaled_bonus)
	receiver.heal(amount)

	return {
		"effect": "heal",
		"applied": true,
		"amount": amount,
		"target": "source" if apply_to_source else "target"
	}

func _get_stat_value(stats: CharacterStats, key: String) -> int:
	if stats == null:
		return 0
	return stats.get_total_stat(key, "magic")

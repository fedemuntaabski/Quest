extends CardEffect
class_name BuffEffect

@export var stat_key: String = "strength"
@export var value: int = 0
@export var duration_turns: int = 0
@export var apply_to_source: bool = false

func apply(source_stats: CharacterStats, target_stats: CharacterStats, _context: Dictionary) -> Dictionary:
	var receiver := source_stats if apply_to_source else target_stats
	if receiver == null:
		return {
			"effect": "buff",
			"applied": false,
			"reason": "missing_target"
		}

	var modifier_id: String = receiver.apply_runtime_modifier(stat_key, value, duration_turns)
	return {
		"effect": "buff",
		"applied": modifier_id != "",
		"stat_key": stat_key,
		"value": value,
		"duration": duration_turns,
		"modifier_id": modifier_id,
		"target": "source" if apply_to_source else "target"
	}

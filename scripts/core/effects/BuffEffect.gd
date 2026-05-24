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

	var stat_key_l := stat_key.to_lower()
	var modifier_id: String = ""
	match stat_key_l:
		"strength":
			if receiver.has_method("_ensure_stacks") and receiver.strength_stack:
				modifier_id = receiver.strength_stack.add_runtime_modifier(value, duration_turns, "buff")
			else:
				modifier_id = receiver.apply_runtime_modifier(stat_key_l, value, duration_turns)
		"magic":
			if receiver.has_method("_ensure_stacks") and receiver.magic_stack:
				modifier_id = receiver.magic_stack.add_runtime_modifier(value, duration_turns, "buff")
			else:
				modifier_id = receiver.apply_runtime_modifier(stat_key_l, value, duration_turns)
		"dexterity":
			if receiver.has_method("_ensure_stacks") and receiver.dexterity_stack:
				modifier_id = receiver.dexterity_stack.add_runtime_modifier(value, duration_turns, "buff")
			else:
				modifier_id = receiver.apply_runtime_modifier(stat_key_l, value, duration_turns)
		_:
			modifier_id = receiver.apply_runtime_modifier(stat_key_l, value, duration_turns)
	return {
		"effect": "buff",
		"applied": modifier_id != "",
		"stat_key": stat_key,
		"value": value,
		"duration": duration_turns,
		"modifier_id": modifier_id,
		"target": "source" if apply_to_source else "target"
	}

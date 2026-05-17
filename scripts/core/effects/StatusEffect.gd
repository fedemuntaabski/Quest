extends CardEffect
class_name StatusEffect

@export var status_id: String = ""
@export var duration_turns: int = 1
@export var stacks: int = 1
@export var magnitude: int = 0
@export var apply_to_source: bool = false

func apply(_source_stats: CharacterStats, _target_stats: CharacterStats, _context: Dictionary) -> Dictionary:
	return {
		"effect": "status",
		"applied": true,
		"status_id": status_id,
		"duration": duration_turns,
		"stacks": stacks,
		"magnitude": magnitude,
		"target": "source" if apply_to_source else "target"
	}

extends CardEffect
class_name StatusEffect

@export var status_id: String = ""

@export var duration_turns: int = 1
@export var stacks: int = 1
@export var magnitude: int = 0

@export var apply_to_source: bool = false

@export var max_stacks: int = 99
@export var refresh_duration_on_reapply: bool = true
@export var stack_behavior: String = "add" 

@export var status_tags: Array[String] = []

@export var consume_on_trigger: bool = false

func apply(_source_stats: CharacterStats, _target_stats: CharacterStats, _context: Dictionary) -> Dictionary:
	return {
		"effect": "status",
		"applied": true,
		"status_id": status_id,
		"duration": duration_turns,
		"stacks": stacks,
		"magnitude": magnitude,
		"max_stacks": max_stacks,
		"refresh_duration_on_reapply": refresh_duration_on_reapply,
		"stack_behavior": stack_behavior,
		"status_tags": status_tags,
		"consume_on_trigger": consume_on_trigger,
		"target": "source" if apply_to_source else "target"
	}
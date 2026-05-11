extends Resource
class_name CardEffect

@export var effect_id: String = ""
@export var description: String = ""

func apply(_source_stats: CharacterStats, _target_stats: CharacterStats, _context: Dictionary) -> Dictionary:
	return {}

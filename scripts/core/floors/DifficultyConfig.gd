extends Resource
class_name DifficultyConfig

## DifficultyConfig (progresion-10): the selectable difficulties
## (resources/floors/difficulty_config.tres). GameSession.difficulty holds the id.

const DEFAULT_PATH := "res://resources/floors/difficulty_config.tres"

@export var levels: Array[DifficultyLevel] = []


static func get_default() -> DifficultyConfig:
	return load(DEFAULT_PATH) as DifficultyConfig


## The level with `id`, else the first one (Normal); null only if empty.
func get_level(id: String) -> DifficultyLevel:
	for level in levels:
		if level.id == id:
			return level
	return levels[0] if not levels.is_empty() else null

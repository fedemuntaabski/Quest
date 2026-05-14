extends CardEffect
class_name MovementEffect

@export var move_cells: int = 1
@export var movement_mode: String = "dash" # dash, teleport, pull, knockback
@export var apply_to_source: bool = true

func apply(_source_stats: CharacterStats, _target_stats: CharacterStats, _context: Dictionary) -> Dictionary:
	return {
		"effect": "movement",
		"applied": true,
		"move_cells": move_cells,
		"movement_mode": movement_mode,
		"target": "source" if apply_to_source else "target"
	}

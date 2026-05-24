extends Node
class_name DiceSystem

# DiceSystem: small pure-logic helper for random rolls and damage multipliers.
# Keep deterministic-seed considerations external when used in tests.

static func roll_d6() -> int:
	return randi_range(1, 6)

static func get_damage_multiplier(roll: int) -> float:
	match roll:
		6:
			return 1.5
		5:
			return 1.15
		4, 3:
			return 1.0
		2:
			return 0.95
		1:
			return 0.85
		_:
			return 1.0
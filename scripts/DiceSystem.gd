extends Node
class_name DiceSystem

static func roll_d6() -> int:
	return randi_range(1, 6)

static func roll_bonus() -> int:
	match roll_d6():
		1:
			return -2
		2, 3:
			return -1
		4, 5:
			return 0
		6:
			return 2
		_:
			return 0
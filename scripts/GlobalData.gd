extends Node

# Core Character Stats
const HP = "hp"
const STRENGTH = "strength"
const MAGIC = "magic"
const DEXTERITY = "dexterity"

# Dice Bonus Logic (1d6)
# Maps dice roll results to stat bonuses
var dice_bonus = {
	1: -2,      # Nat 1: Terrible
	2: -1,      # 2-3: Poor
	3: -1,
	4: 0,       # 4-5: Average
	5: 0,
	6: 2        # Nat 6: Critical success
}

func _ready():
	print("GameManager initialized - QUEST core systems loaded")

# Roll 1d6 and get bonus
func roll_dice_bonus() -> int:
	var roll = randi_range(1, 6)
	return dice_bonus.get(roll, 0)

# Get stat by name
func get_stat(stat_name: String) -> String:
	match stat_name:
		HP:
			return "Maximum Health Points"
		STRENGTH:
			return "Physical Power"
		MAGIC:
			return "Magical Ability"
		DEXTERITY:
			return "Speed & Precision"
		_:
			return "Unknown"

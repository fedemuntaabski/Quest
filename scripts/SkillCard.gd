extends Control

class_name SkillCard

# Skill card properties
var card_name: String = "Skill"
var card_description: String = "A basic skill"
var linked_stat: String = "strength"  # Default to Strength
var base_damage: int = 1
var success_threshold: int = 4  # Roll 4+ for success

func _ready():
	custom_minimum_size = Vector2(150, 200)
	modulate = Color.WHITE
	# Initialize linked_stat if not set
	if linked_stat == "":
		linked_stat = GameManager.STRENGTH

# Calculate success intensity using 1d6 + Character modifier + Dice bonus
func calculate_success(character_stats: CharacterStats) -> Dictionary:
	"""
	Rolls 1d6 and adds character stat modifier + dice bonus to determine success intensity.
	Returns a dictionary with:
	- roll: The 1d6 result
	- character_modifier: The character's stat modifier
	- dice_bonus: The GameManager dice bonus roll
	- total: roll + character_modifier + dice_bonus
	- intensity: 0=fail, 1=success, 2=critical success
	- damage: Calculated damage based on intensity
	"""
	var roll = randi_range(1, 6)
	var character_modifier = character_stats.get_modifier(linked_stat)
	var dice_bonus = GameManager.roll_dice_bonus()
	var total = roll + character_modifier + dice_bonus
	
	var intensity = 0
	if total >= success_threshold:
		intensity = 1  # Success
	if total >= 6:
		intensity = 2  # Critical success
	
	var damage = base_damage * intensity
	
	return {
		"roll": roll,
		"character_modifier": character_modifier,
		"dice_bonus": dice_bonus,
		"total": total,
		"intensity": intensity,
		"damage": damage,
		"stat_type": linked_stat
	}

# Display card in UI
func get_display_info() -> Dictionary:
	return {
		"name": card_name,
		"description": card_description,
		"stat": linked_stat,
		"base_damage": base_damage
	}

# Set card properties
func setup(skill_name: String, description: String, stat: String, damage: int) -> void:
	card_name = skill_name
	card_description = description
	linked_stat = stat
	base_damage = damage

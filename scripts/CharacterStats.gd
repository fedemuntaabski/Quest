extends Node

class_name CharacterStats

signal hp_changed(new_hp: int)
signal died

# Health
var current_hp: int = 10
var max_hp: int = 10

# Stat Modifiers (applied to dice rolls)
var strength_modifier: int = 0
var magic_modifier: int = 0
var dexterity_modifier: int = 0

# Character metadata
var character_name: String = "Character"
var character_class: String = "Adventurer"

func _ready():
	print("CharacterStats initialized for %s (%s)" % [character_name, character_class])

# Initialize with custom values
func initialize(char_name: String, class_type: String, max_health: int, str_mod: int = 0, mag_mod: int = 0, dex_mod: int = 0) -> void:
	character_name = char_name
	character_class = class_type
	max_hp = max_health
	current_hp = max_health
	strength_modifier = str_mod
	magic_modifier = mag_mod
	dexterity_modifier = dex_mod
	hp_changed.emit(current_hp)

# Get modifier for a specific stat
func get_modifier(stat_type: String) -> int:
	match stat_type:
		GameManager.STRENGTH:
			return strength_modifier
		GameManager.MAGIC:
			return magic_modifier
		GameManager.DEXTERITY:
			return dexterity_modifier
		_:
			return 0

# Apply damage
func take_damage(amount: int) -> int:
	var old_hp = current_hp
	current_hp -= amount
	current_hp = clamp(current_hp, 0, max_hp)
	if old_hp != current_hp:
		hp_changed.emit(current_hp)
		if current_hp <= 0:
			died.emit()
	return current_hp

# Restore health
func heal(amount: int) -> int:
	var old_hp = current_hp
	current_hp += amount
	current_hp = clamp(current_hp, 0, max_hp)
	if old_hp != current_hp:
		hp_changed.emit(current_hp)
	return current_hp

# Check if alive
func is_alive() -> bool:
	return current_hp > 0

# Get health percentage
func get_health_percentage() -> float:
	if max_hp == 0:
		return 0.0
	return float(current_hp) / float(max_hp)

extends CanvasLayer

class_name HUDController

@onready var timer_label: Label = $Control/TimerLabel
@onready var stats_container: VBoxContainer = $Control/MarginContainer/VBoxContainer

# References to stat labels
@onready var label_hp: Label = $Control/MarginContainer/VBoxContainer/HBoxContainer_HP/LabelHP
@onready var label_strength: Label = $Control/MarginContainer/VBoxContainer/HBoxContainer_Strength/LabelStrength
@onready var label_magic: Label = $Control/MarginContainer/VBoxContainer/HBoxContainer_Magic/LabelMagic
@onready var label_dexterity: Label = $Control/MarginContainer/VBoxContainer/HBoxContainer_Dexterity/LabelDexterity

# Card slots UI references
var card_slots: Array = []

# Instance timer
var instance_time: float = 0.0
var instance_duration: float = 300.0  # 5 minutes

func _ready():
	# Initialize timer display
	if timer_label:
		timer_label.text = "Time: 05:00"
	if stats_container:
		stats_container.visible = false
	
	print("HUDController initialized - Minimal 2D HUD ready")

func _process(delta: float):
	if stats_container:
		stats_container.visible = Input.is_action_pressed("ui_focus_next")

	# Update timer
	instance_time += delta
	var remaining_time = max(0.0, instance_duration - instance_time)
	var minutes = int(floor(remaining_time / 60.0))
	var seconds = int(remaining_time) % 60
	timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
	
	# Check if time is up
	if remaining_time <= 0:
		_on_instance_time_expired()

# Update stat display
func update_stats(character_stats: CharacterStats) -> void:
	"""Update HUD stat display from CharacterStats"""
	if not character_stats:
		return
	
	label_hp.text = "HP: %d/%d" % [character_stats.current_hp, character_stats.max_hp]
	label_strength.text = "Strength: +%d" % character_stats.strength_modifier
	label_magic.text = "Magic: +%d" % character_stats.magic_modifier
	label_dexterity.text = "Dexterity: +%d" % character_stats.dexterity_modifier

# Signal handler for card changes (disabled for 2D prototype)
func _on_cards_changed(_cards: Array) -> void:
	"""Update card slot display when cards change"""
	print("HUDController: Cards changed signal received (not implemented in 2D prototype)")

# Helper to get short stat name
func _get_stat_short(stat: String) -> String:
	match stat:
		GameManager.STRENGTH:
			return "STR"
		GameManager.MAGIC:
			return "MAG"
		GameManager.DEXTERITY:
			return "DEX"
		GameManager.HP:
			return "HP"
		_:
			return "???"

# Called when instance time expires
func _on_instance_time_expired() -> void:
	print("HUDController: Instance time expired!")
	# TODO: Implement end-of-instance logic (return to lobby, etc.)

# Reset timer for new instance
func reset_instance_timer() -> void:
	instance_time = 0.0
	timer_label.text = "Time: 00:00"

# Add a card to the container (disabled for 2D prototype)
func add_card_to_container(_card_data: Dictionary) -> bool:
	"""Convenience function to add cards from game logic"""
	print("HUDController: add_card_to_container not implemented in 2D prototype")
	return false

# Get current equipped cards
func get_equipped_cards() -> Array:
	"""Return currently equipped cards (empty for 2D prototype)"""
	return []

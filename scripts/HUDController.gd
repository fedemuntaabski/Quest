extends CanvasLayer

class_name HUDController

@onready var timer_label: Label = $Control/TimerLabel
@onready var stats_container: VBoxContainer = $Control/MarginContainer/HBoxContainer/VBoxContainer

# References to stat labels
@onready var label_hp: Label = $Control/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer_HP/LabelHP
@onready var label_strength: Label = $Control/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer_Strength/LabelStrength
@onready var label_magic: Label = $Control/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer_Magic/LabelMagic
@onready var label_dexterity: Label = $Control/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer_Dexterity/LabelDexterity

# Card slots UI references
var card_slots: Array = []

func _ready():
	_ensure_tab_input_action()

	# Main2d drives the room timer; HUD only renders values.
	if timer_label:
		timer_label.text = "Time: 02:00"
		timer_label.modulate = Color(1, 1, 1, 1)
	if stats_container:
		stats_container.visible = false
	
	print("HUDController initialized - Minimal 2D HUD ready")

func _process(_delta: float) -> void:
	if stats_container:
		stats_container.visible = Input.is_action_pressed("tab")

func _ensure_tab_input_action() -> void:
	if InputMap.has_action("tab"):
		return

	InputMap.add_action("tab")
	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	InputMap.action_add_event("tab", tab_event)

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
	update_room_timer(120.0, 120.0, Color(1, 1, 1, 1))

func update_room_timer(remaining_seconds: float, _total_seconds: float, timer_color: Color) -> void:
	if not timer_label:
		return

	var clamped_remaining := maxf(0.0, remaining_seconds)
	var minutes := int(floor(clamped_remaining / 60.0))
	var seconds := int(clamped_remaining) % 60
	timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
	timer_label.modulate = timer_color

# Add a card to the container (disabled for 2D prototype)
func add_card_to_container(_card_data: Dictionary) -> bool:
	"""Convenience function to add cards from game logic"""
	print("HUDController: add_card_to_container not implemented in 2D prototype")
	return false

# Get current equipped cards
func get_equipped_cards() -> Array:
	"""Return currently equipped cards (empty for 2D prototype)"""
	return []

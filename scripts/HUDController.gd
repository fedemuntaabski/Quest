extends CanvasLayer

class_name HUDController

@onready var timer_label: Label = $Control/TimerLabel
@onready var stats_container: VBoxContainer = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/HBoxContainer/VBoxContainer
@onready var hbox_container: HBoxContainer = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/HBoxContainer
@onready var tab_ui_panel: NinePatchRect = $Control/TabUIPanel

# References to stat labels
@onready var label_hp: Label = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/HBoxContainer/VBoxContainer/HBoxContainer_HP/LabelHP
@onready var label_strength: Label = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/HBoxContainer/VBoxContainer/HBoxContainer_Strength/LabelStrength
@onready var label_magic: Label = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/HBoxContainer/VBoxContainer/HBoxContainer_Magic/LabelMagic
@onready var label_dexterity: Label = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/HBoxContainer/VBoxContainer/HBoxContainer_Dexterity/LabelDexterity

@onready var current_room_label: Label = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/TopInfoRow/CurrentRoomLabel
@onready var enemies_label: Label = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/TopInfoRow/EnemiesLabel

# Card slots UI references
var card_slots: Array = []

var cards_column: VBoxContainer = null
var active_upgrades_vbox: VBoxContainer = null

func _ready():
	_ensure_tab_input_action()

	# Main2d drives the room timer; HUD only renders values.
	if timer_label:
		timer_label.text = "Time: 02:00"
		timer_label.modulate = Color(1, 1, 1, 1)
	if tab_ui_panel:
		tab_ui_panel.visible = false
	
	_build_active_upgrades_ui()
	
	var player_stats_autoload = get_node_or_null("/root/PlayerStats")
	if player_stats_autoload and not player_stats_autoload.stats_changed.is_connected(update_stats):
		player_stats_autoload.stats_changed.connect(update_stats)
		if player_stats_autoload.stats:
			update_stats(player_stats_autoload.stats)
	
	print("HUDController initialized - Minimal 2D HUD ready")

func _build_active_upgrades_ui() -> void:
	if not hbox_container:
		return
	
	var sep = VSeparator.new()
	hbox_container.add_child(sep)
	
	cards_column = VBoxContainer.new()
	cards_column.custom_minimum_size = Vector2(300, 200)
	hbox_container.add_child(cards_column)
	
	var title = Label.new()
	title.text = "Equipped Skill Cards"
	title.add_theme_font_size_override("font_size", 24)
	cards_column.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_column.add_child(scroll)
	
	active_upgrades_vbox = VBoxContainer.new()
	active_upgrades_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(active_upgrades_vbox)

func _process(_delta: float) -> void:
	if tab_ui_panel:
		tab_ui_panel.visible = Input.is_action_pressed("tab")

func _ensure_tab_input_action() -> void:
	if InputMap.has_action("tab"):
		return

	InputMap.add_action("tab")
	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	InputMap.action_add_event("tab", tab_event)

func update_current_room(room_id: int) -> void:
	if current_room_label:
		current_room_label.text = "Room: %d" % room_id

func update_enemies_remaining(count: int) -> void:
	if enemies_label:
		enemies_label.text = "Enemies: %d" % count

# Update stat display
func update_stats(character_stats: CharacterStats) -> void:
	"""Update HUD stat display from CharacterStats"""
	if not character_stats:
		return
		
	var player_stats = get_node_or_null("/root/PlayerStats")
	var b_hp = player_stats.base_hp if player_stats else 10
	var b_str = player_stats.base_str if player_stats else 0
	var b_mag = player_stats.base_mag if player_stats else 0
	var b_dex = player_stats.base_dex if player_stats else 0
	
	var r_hp = character_stats.max_hp - b_hp
	var r_str = character_stats.strength_modifier - b_str
	var r_mag = character_stats.magic_modifier - b_mag
	var r_dex = character_stats.dexterity_modifier - b_dex
	
	label_hp.text = "HP: %d/%d (%d+%d)" % [character_stats.current_hp, character_stats.max_hp, b_hp, r_hp]
	label_strength.text = "STR: %d + %d" % [b_str, r_str]
	label_magic.text = "MAG: %d + %d" % [b_mag, r_mag]
	label_dexterity.text = "DEX: %d + %d" % [b_dex, r_dex]
	
	_refresh_active_upgrades_list()

func _refresh_active_upgrades_list() -> void:
	if not active_upgrades_vbox:
		return
	
	# Clear existing
	for child in active_upgrades_vbox.get_children():
		child.queue_free()
	
	var player_stats = get_node_or_null("/root/PlayerStats")
	if not player_stats:
		return
	
	var upgrades: Array = player_stats.active_upgrades
	if upgrades.is_empty():
		var lbl = Label.new()
		lbl.text = "No cards equipped."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		active_upgrades_vbox.add_child(lbl)
		return
		
	var count = 0
	for upg in upgrades:
		if count >= 3: break # Display max 3 skill cards
		
		var card_panel = PanelContainer.new()
		var card_vbox = VBoxContainer.new()
		card_panel.add_child(card_vbox)
		
		var title = Label.new()
		title.text = str(upg.get("card_name", "???"))
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		card_vbox.add_child(title)
		
		var desc = Label.new()
		desc.text = "Grants +%d to %s" % [
			upg.get("value_change", 0),
			_get_stat_short(upg.get("stat_affected", ""))
		]
		desc.add_theme_font_size_override("font_size", 16)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(desc)
		
		active_upgrades_vbox.add_child(card_panel)
		count += 1

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
			return stat.to_upper()

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

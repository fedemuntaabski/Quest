extends Control
class_name CardPanelUI

@onready var cards_container: VBoxContainer = $ScrollContainer/VBoxContainer

var _card_entries: Array[Dictionary] = []

func _ready() -> void:
	_clear_cards()

func refresh(cards_payload: Array) -> void:
	_card_entries.clear()
	if cards_payload:
		for entry in cards_payload:
			_card_entries.append(entry if entry is Dictionary else {})
	_update_display()

func _clear_cards() -> void:
	if cards_container:
		for child in cards_container.get_children():
			child.queue_free()

func _update_display() -> void:
	_clear_cards()
	
	if _card_entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No cards equipped."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		cards_container.add_child(empty_label)
		return
	
	for i in range(_card_entries.size()):
		var card_data = _card_entries[i]
		if card_data is Dictionary and not card_data.is_empty():
			_create_card_row(i + 1, card_data)
		else:
			_create_empty_slot_row(i + 1)

func _create_card_row(slot_num: int, data: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	
	# Slot number indicator
	var slot_label := Label.new()
	slot_label.text = "[%d]" % slot_num
	slot_label.custom_minimum_size = Vector2(30, 0)
	slot_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.62, 1))
	hbox.add_child(slot_label)
	
	# Card icon (small)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex: Texture2D = data.get("icon", null)
	icon_rect.texture = tex
	hbox.add_child(icon_rect)
	
	# Card info container
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Name with cooldown indicator
	var name_hbox := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = data.get("name", "Unknown Card")
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_hbox.add_child(name_label)
	
	var cd_remaining: int = data.get("cooldown_remaining", 0)
	if cd_remaining > 0:
		var cd_label := Label.new()
		cd_label.text = "(CD: %d)" % cd_remaining
		cd_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
		name_hbox.add_child(cd_label)

	var state_label := Label.new()
	var state := str(data.get("state", "available")).to_upper()
	state_label.text = "[%s]" % state
	state_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0) if state == "AVAILABLE" else Color(1.0, 0.45, 0.45, 1.0))
	name_hbox.add_child(state_label)
	
	info_vbox.add_child(name_hbox)
	
	# Description
	var desc_label := Label.new()
	desc_label.text = data.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))
	info_vbox.add_child(desc_label)
	
	# Stats line
	var stats_label := Label.new()
	var stat_key: String = data.get("scaling_stat", data.get("stat", ""))
	var stat_label := StatTypes.get_label(stat_key)
	var base_dmg: int = data.get("base_damage", 0)
	var range_val: int = data.get("range", 0)
	var cd: int = data.get("cooldown", 0)
	stats_label.text = "Escala: %s | Dano base: %d | Alcance: %d | Enfriamiento: %d" % [stat_label, base_dmg, range_val, cd]
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.95, 1))
	info_vbox.add_child(stats_label)

	var swap_button := Button.new()
	swap_button.text = "Swap (coming soon)"
	swap_button.disabled = true
	swap_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	info_vbox.add_child(swap_button)
	
	hbox.add_child(info_vbox)
	cards_container.add_child(hbox)
	
	# Separator
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.3)
	cards_container.add_child(sep)

func _create_empty_slot_row(slot_num: int) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	
	var slot_label := Label.new()
	slot_label.text = "[%d]" % slot_num
	slot_label.custom_minimum_size = Vector2(30, 0)
	slot_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	hbox.add_child(slot_label)
	
	var empty_label := Label.new()
	empty_label.text = "Empty Slot"
	empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
	hbox.add_child(empty_label)
	
	cards_container.add_child(hbox)

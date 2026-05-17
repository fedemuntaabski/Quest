extends CanvasLayer
class_name CardRewardUI

signal card_selected(card: CardData)
signal reward_skipped
signal card_replace_selected(card: CardData, slot_index: int)

@onready var panel: Panel = $CenterContainer/RewardPanel
@onready var cards_container: HBoxContainer = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/CardsContainer
@onready var title_label: Label = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/TitleLabel

var _reward_cards: Array[CardData] = []
var _card_nodes: Array = []
var _is_active: bool = false
var _requires_replace: bool = false
var _replace_slots: Array = []
var _pending_card: CardData = null

const CARD_REWARD_COUNT: int = 3

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_is_active = false
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

func show_reward(cards: Array, requires_replace: bool = false, equipped_slots: Array = []) -> void:
	if cards.is_empty():
		return
	
	_reward_cards.clear()
	_reward_cards.assign(cards)
	_card_nodes.clear()
	_requires_replace = requires_replace
	_replace_slots = equipped_slots.duplicate()
	_pending_card = null
	
	_clear_cards_container()
	_create_card_buttons()
	_add_skip_button()
	
	visible = true
	_is_active = true
	title_label.text = "Choose a Card Reward" if not _requires_replace else "Choose a Card (then replace a slot)"

func hide_reward() -> void:
	visible = false
	_is_active = false
	_requires_replace = false
	_replace_slots.clear()
	_pending_card = null
	_clear_cards_container()

func _clear_cards_container() -> void:
	for child in cards_container.get_children():
		child.queue_free()

func _create_card_buttons() -> void:
	for card in _reward_cards:
		if card == null:
			continue
		var card_button := _create_card_button(card)
		cards_container.add_child(card_button)

func _add_skip_button() -> void:
	var skip_button := Button.new()
	skip_button.text = "Skip Reward"
	skip_button.custom_minimum_size = Vector2(140, 32)
	skip_button.pressed.connect(_on_skip_pressed)
	cards_container.add_child(skip_button)

func _create_card_button(card: CardData) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(220, 280)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.focus_mode = Control.FOCUS_NONE
	container.add_theme_stylebox_override("panel", _build_card_style())
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	container.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Name (at top)
	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)
	
	# Icon
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(188, 108)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if card.icon:
		icon.texture = card.icon
	vbox.add_child(icon)
	
	# Description
	var desc_label := Label.new()
	desc_label.text = _build_reward_description(card)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.custom_minimum_size = Vector2(188, 80)
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	var effects_label := Label.new()
	effects_label.text = _build_reward_effects_text(card)
	effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effects_label.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1))
	effects_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(effects_label)
	
	# Select button
	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.custom_minimum_size = Vector2(188, 34)
	select_btn.pressed.connect(_on_card_selected.bind(card))
	vbox.add_child(select_btn)
	
	_card_nodes.append(container)
	return container

func _on_card_selected(card: CardData) -> void:
	if not _is_active:
		return
	if _requires_replace:
		_pending_card = card
		_show_replace_selection()
		return
	hide_reward()
	card_selected.emit(card)

func _show_replace_selection() -> void:
	_clear_cards_container()
	title_label.text = "Hotbar full: choose a slot to replace"
	for slot in _replace_slots:
		var slot_button := Button.new()
		var slot_index: int = int(slot.get("slot_index", -1))
		var slot_name: String = str(slot.get("name", "Unknown"))
		slot_button.text = "Replace Slot %d: %s" % [slot_index + 1, slot_name]
		slot_button.custom_minimum_size = Vector2(240, 36)
		slot_button.pressed.connect(_on_replace_slot_selected.bind(slot_index))
		cards_container.add_child(slot_button)
	_add_skip_button()

func _on_replace_slot_selected(slot_index: int) -> void:
	if not _is_active:
		return
	var selected_card := _pending_card
	if selected_card == null:
		return
	hide_reward()
	card_replace_selected.emit(selected_card, slot_index)

func _on_skip_pressed() -> void:
	if not _is_active:
		return
	hide_reward()
	reward_skipped.emit()

func _build_reward_description(card: CardData) -> String:
	return card.description

func _build_reward_effects_text(card: CardData) -> String:
	var effects: Array[String] = []
	effects.append("Bonus: %s | Base %d | Range %d | CD %d" % [StatTypes.get_label(card.stat_key), card.base_damage, card.range, card.cooldown])
	if not card.effects.is_empty():
		var effect_descriptions: Array[String] = []
		for effect in card.effects:
			if effect:
				var effect_desc_value: Variant = effect.get("description")
				var effect_desc := "" if effect_desc_value == null else str(effect_desc_value)
				if effect_desc != "":
					effect_descriptions.append(effect_desc)
		if not effect_descriptions.is_empty():
			effects.append("Effects: " + ", ".join(effect_descriptions))
	return "\n".join(effects)

func _build_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.32, 0.38, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style

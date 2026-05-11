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
	container.custom_minimum_size = Vector2(120, 160)
	
	var vbox := VBoxContainer.new()
	container.add_child(vbox)
	
	# Icon
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(100, 80)
	if card.icon:
		icon.texture = card.icon
	vbox.add_child(icon)
	
	# Name
	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Description
	var desc_label := Label.new()
	desc_label.text = card.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(100, 40)
	vbox.add_child(desc_label)
	
	# Select button
	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.custom_minimum_size = Vector2(100, 30)
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
	if _pending_card == null:
		return
	hide_reward()
	card_replace_selected.emit(_pending_card, slot_index)

func _on_skip_pressed() -> void:
	if not _is_active:
		return
	hide_reward()
	reward_skipped.emit()

func _input(event: InputEvent) -> void:
	if not _is_active:
		return

extends CanvasLayer
class_name CardRewardUI

signal card_selected(card: CardData)
signal declined

@onready var panel: Panel = $CenterContainer/RewardPanel
@onready var cards_container: HBoxContainer = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/CardsContainer
@onready var title_label: Label = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var skip_button: Button = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/SkipButton

var _reward_cards: Array[CardData] = []
var _card_nodes: Array = []
var _is_active: bool = false

const CARD_REWARD_COUNT: int = 3

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_is_active = false
	
	if skip_button and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)

func show_reward(cards: Array) -> void:
	if cards.is_empty():
		return
	
	_reward_cards.clear()
	_reward_cards.assign(cards)
	_card_nodes.clear()
	
	_clear_cards_container()
	_create_card_buttons()
	
	visible = true
	_is_active = true
	title_label.text = "Choose a Card Reward"

func decline() -> void:
	_hide()
	declined.emit()

func _hide() -> void:
	visible = false
	_is_active = false
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
	_hide()
	card_selected.emit(card)

func _on_skip_pressed() -> void:
	decline()

func _input(event: InputEvent) -> void:
	if not _is_active:
		return
	
	if event.is_action_pressed("ui_cancel"):
		decline()
		get_viewport().set_input_as_handled()

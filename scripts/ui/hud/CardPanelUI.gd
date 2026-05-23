extends Control
class_name CardPanelUI

const CardPanelRowScene := preload("res://scenes/CardPanelRow.tscn")

@onready var cards_container: VBoxContainer = $ScrollContainer/VBoxContainer

var _card_entries: Array[CardDisplayData] = []

func _ready() -> void:
	_clear_cards()

func refresh(cards_payload: Array[CardDisplayData]) -> void:
	_card_entries.clear()
	_card_entries.assign(cards_payload)
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
		if card_data != null:
			_create_card_row(i + 1, card_data)
		else:
			_create_empty_slot_row(i + 1)

func _create_card_row(slot_num: int, data: CardDisplayData) -> void:
	var row := CardPanelRowScene.instantiate() as CardPanelRow
	if row == null:
		return
	row.setup_card(slot_num, data)
	cards_container.add_child(row)

func _create_empty_slot_row(slot_num: int) -> void:
	var row := CardPanelRowScene.instantiate() as CardPanelRow
	if row == null:
		return
	row.setup_empty(slot_num)
	cards_container.add_child(row)

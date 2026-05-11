extends Node
class_name CardManager

signal equipped_changed
signal active_index_changed(index: int)
signal cooldowns_changed
signal ui_state_changed(cards_payload: Array, active_index: int)

const CardData = preload("res://scripts/CardData.gd")

@export var max_equipped: int = 3
@export var default_deck: Array[CardData] = []

var deck: Array[CardData] = []
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var equipped: Array[CardData] = []
var active_index: int = 0

var _cooldowns: Dictionary = {}

func _ready() -> void:
	add_to_group("card_manager")
	if deck.is_empty() and not default_deck.is_empty():
		set_deck(default_deck)

func set_deck(cards: Array[CardData]) -> void:
	deck = cards.duplicate()
	draw_pile = cards.duplicate()
	discard_pile.clear()
	if equipped.is_empty():
		_equip_initial_cards()
	_update_cooldown_cache()
	equipped_changed.emit()
	_emit_ui_state()
	_shuffle_draw_pile()

func _equip_initial_cards() -> void:
	equipped.clear()
	for i in range(min(max_equipped, draw_pile.size())):
		equipped.append(draw_pile[i])
	active_index = clamp(active_index, 0, max(0, equipped.size() - 1))

func equip_card(card: CardData, slot_index: int) -> void:
	if card == null:
		return
	if slot_index < 0 or slot_index >= max_equipped:
		return
	while equipped.size() < max_equipped:
		equipped.append(null)
	equipped[slot_index] = card
	active_index = clamp(active_index, 0, max(0, equipped.size() - 1))
	equipped_changed.emit()
	_emit_ui_state()

func get_active_card() -> CardData:
	if active_index < 0 or active_index >= equipped.size():
		return null
	return equipped[active_index]

func set_active_index(index: int) -> void:
	if index < 0 or index >= equipped.size():
		return
	active_index = index
	active_index_changed.emit(index)
	_emit_ui_state()

func can_play_card(card: CardData) -> bool:
	if card == null:
		return false
	return _cooldowns.get(card, 0) <= 0

func start_cooldown(card: CardData) -> void:
	if card == null:
		return
	_cooldowns[card] = max(card.cooldown, 0)
	cooldowns_changed.emit()
	_emit_ui_state()

func tick_cooldowns() -> void:
	var changed := false
	for card in _cooldowns.keys():
		var cd := int(_cooldowns[card])
		if cd > 0:
			_cooldowns[card] = cd - 1
			changed = true
	if changed:
		cooldowns_changed.emit()
		_emit_ui_state()

func get_cooldown_remaining(card: CardData) -> int:
	return int(_cooldowns.get(card, 0))

func get_equipped_payload() -> Array:
	var payload: Array = []
	for card in equipped:
		if card == null:
			payload.append({})
			continue
		payload.append({
			"name": card.display_name,
			"description": card.description,
			"stat": card.stat_key,
			"scaling_stat": card.stat_key,
			"base_damage": card.base_damage,
			"range": card.range,
			"cooldown": card.cooldown,
			"cooldown_remaining": get_cooldown_remaining(card),
			"is_usable": can_play_card(card),
			"state": "available" if can_play_card(card) else "blocked",
			"icon": card.icon,
			"card": card
		})
	return payload

func draw_cards(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for i in range(count):
		if draw_pile.is_empty():
			_refill_draw_pile()
		if draw_pile.is_empty():
			break
		drawn.append(draw_pile.pop_back())
	return drawn

func discard_card(card: CardData) -> void:
	if card == null:
		return
	discard_pile.append(card)

func _refill_draw_pile() -> void:
	if discard_pile.is_empty():
		return
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	_shuffle_draw_pile()

func _shuffle_draw_pile() -> void:
	for i in range(draw_pile.size()):
		var swap_index := randi() % draw_pile.size()
		var temp := draw_pile[i]
		draw_pile[i] = draw_pile[swap_index]
		draw_pile[swap_index] = temp

func _update_cooldown_cache() -> void:
	_cooldowns.clear()
	for card in deck:
		_cooldowns[card] = 0

func _emit_ui_state() -> void:
	ui_state_changed.emit(get_equipped_payload(), active_index)

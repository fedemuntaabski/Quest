extends Node
class_name CardManager

# CardManager: single authoritative owner of a player's deck, draw/discard piles,
# equipped hotbar and cooldown state. Other systems should treat this object
# as the canonical data source for card ownership and query via its public API
# (signals and methods) rather than mutating internal arrays directly.

signal equipped_changed
signal active_index_changed(index: int)
signal cooldowns_changed
signal ui_state_changed(cards_payload: Array, active_index: int)

const CardData = preload("res://scripts/core/cards/CardData.gd")

@export var max_equipped: int = 3
@export var default_deck: Array[CardData] = []

var deck: Array[CardData] = []
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var equipped: Array[CardData] = []
var active_index: int = -1

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
		_initialize_empty_hotbar()
	_update_cooldown_cache()
	equipped_changed.emit()
	_shuffle_draw_pile()

func _initialize_empty_hotbar() -> void:
	equipped.clear()
	for _i in range(max_equipped):
		equipped.append(null)
	active_index = -1

func equip_card(card: CardData, slot_index: int) -> void:
	if card == null:
		return
	if slot_index < 0 or slot_index >= max_equipped:
		return
	while equipped.size() < max_equipped:
		equipped.append(null)
	equipped[slot_index] = card
	if active_index >= equipped.size():
		active_index = -1
	equipped_changed.emit()

func replace_equipped_card(card: CardData, slot_index: int) -> void:
	if card == null:
		return
	if slot_index < 0 or slot_index >= max_equipped:
		return
	while equipped.size() < max_equipped:
		equipped.append(null)

	var replaced_card: CardData = equipped[slot_index]
	if replaced_card != null:
		discard_pile.append(replaced_card)
		_remove_card_from_pool(draw_pile, replaced_card)
		_remove_card_from_pool(deck, replaced_card)
		_cooldowns.erase(replaced_card)

	equipped[slot_index] = card
	register_new_card(card)
	
	# If the replaced slot was active, reset active_index to -1
	# (Force player to consciously reselect)
	if active_index == slot_index:
		active_index = -1
		active_index_changed.emit(-1)
	
	equipped_changed.emit()

func register_new_card(card: CardData) -> void:
	if card == null:
		return
	deck.append(card)
	_cooldowns[card] = 0

func get_active_card() -> CardData:
	if active_index == -1 or active_index < 0 or active_index >= equipped.size():
		return null
	return equipped[active_index]

func set_active_index(index: int) -> void:
	# Support -1 as neutral/no-skill-selected state
	if index == -1:
		active_index = -1
		active_index_changed.emit(-1)
		return
	
	if index < 0 or index >= equipped.size():
		return
	if equipped[index] == null:
		return
	active_index = index
	active_index_changed.emit(index)
	ui_state_changed.emit(get_equipped_payload(), active_index)

func can_play_card(card: CardData) -> bool:
	if card == null:
		return false
	return _cooldowns.get(card, 0) <= 0

func start_cooldown(card: CardData) -> void:
	if card == null:
		return
	_cooldowns[card] = max(card.cooldown, 0)
	cooldowns_changed.emit()

func tick_cooldowns() -> void:
	var changed := false
	for card in _cooldowns.keys():
		var cd := int(_cooldowns[card])
		if cd > 0:
			_cooldowns[card] = cd - 1
			changed = true
	if changed:
		cooldowns_changed.emit()

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
			"damage_scaling": card.damage_scaling,
			"base_damage": card.base_damage,
			"range": card.range,
			"cooldown": card.cooldown,
			"cooldown_remaining": get_cooldown_remaining(card),
			"cooldown_ok": can_play_card(card),
			"full_playable": can_play_card(card),
			"playability_reason": null,
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

func _remove_card_from_pool(pool: Array[CardData], card: CardData) -> void:
	var index := pool.find(card)
	if index >= 0:
		pool.remove_at(index)

# -----------------------------
# Safe accessors (defensive copies)
# -----------------------------
func get_deck_list() -> Array:
	return deck.duplicate()

func get_draw_pile_list() -> Array:
	return draw_pile.duplicate()

func get_discard_pile_list() -> Array:
	return discard_pile.duplicate()

func get_equipped_list() -> Array:
	return equipped.duplicate()

func get_cooldowns_map() -> Dictionary:
	return _cooldowns.duplicate(true)

func is_card_equipped(card: CardData) -> bool:
	return equipped.has(card)

func remove_card_from_all_pools(card: CardData) -> void:
	if card == null:
		return
	_remove_card_from_pool(deck, card)
	_remove_card_from_pool(draw_pile, card)
	_remove_card_from_pool(discard_pile, card)
	# if equipped, replace with null to preserve slot indexing
	for i in range(equipped.size()):
		if equipped[i] == card:
			equipped[i] = null
	_cooldowns.erase(card)
	equipped_changed.emit()

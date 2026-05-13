extends Node
class_name CardRewardManager

signal reward_completed(selected_card: CardData)

@export var card_manager: CardManager

var _available_cards: Array[CardData] = []
var _rewarded_cards: Dictionary = {}
var _on_reward_completed: Callable = Callable()

func _ready() -> void:
	add_to_group("card_reward_manager")
	_load_all_cards()

func _load_all_cards() -> void:
	var card_files := [
		"res://resources/cards/sword_card.tres",
		"res://resources/cards/bow_card.tres",
		"res://resources/cards/fire_card.tres",
		"res://resources/cards/focus_card.tres",
		"res://resources/cards/cripple_card.tres",
	]
	
	_available_cards.clear()
	for path in card_files:
		var card := load(path) as CardData
		if card:
			_available_cards.append(card)

func reset_run_rewards() -> void:
	_rewarded_cards.clear()

func generate_reward_options(count: int = 3, on_complete: Callable = Callable()) -> Array[CardData]:
	_resolve_card_manager()
	_on_reward_completed = on_complete
	return _select_random_cards(count)

func _select_random_cards(count: int) -> Array[CardData]:
	if _available_cards.is_empty():
		return []
	
	var selected: Array[CardData] = []
	var pool: Array[CardData] = []
	for card in _available_cards:
		if card == null:
			continue
		if _rewarded_cards.has(card):
			continue
		pool.append(card)
	
	for i in range(min(count, pool.size())):
		var idx := randi() % pool.size()
		selected.append(pool[idx])
		pool.remove_at(idx)
	
	return selected

func apply_selected_reward(card: CardData, replace_slot_index: int = -1) -> void:
	if card == null:
		return
	_rewarded_cards[card] = true
	if card_manager:
		_add_card_to_player(card, replace_slot_index)
	
	reward_completed.emit(card)
	
	if _on_reward_completed.is_valid():
		_on_reward_completed.call(card)
	_on_reward_completed = Callable()

func skip_reward() -> void:
	reward_completed.emit(null)
	if _on_reward_completed.is_valid():
		_on_reward_completed.call(null)
	_on_reward_completed = Callable()

func is_hotbar_full() -> bool:
	_resolve_card_manager()
	if card_manager == null:
		return false
	for i in range(card_manager.max_equipped):
		if i >= card_manager.equipped.size() or card_manager.equipped[i] == null:
			return false
	return true

func get_equipped_cards_for_replace() -> Array:
	_resolve_card_manager()
	var equipped_cards: Array = []
	if card_manager == null:
		return equipped_cards
	for i in range(card_manager.max_equipped):
		var card: CardData = null
		if i < card_manager.equipped.size():
			card = card_manager.equipped[i]
		equipped_cards.append({
			"slot_index": i,
			"card": card,
			"name": card.display_name if card else "Empty",
			"icon": card.icon if card else null
		})
	return equipped_cards

func _resolve_card_manager() -> void:
	if card_manager != null:
		return
	
	var player := get_tree().get_first_node_in_group("player") as Node
	if player:
		card_manager = player.get_node_or_null("CardManager") as CardManager

func _add_card_to_player(card: CardData, replace_slot_index: int = -1) -> void:
	_resolve_card_manager()
	if card_manager == null:
		return

	if replace_slot_index >= 0 and replace_slot_index < card_manager.max_equipped:
		card_manager.replace_equipped_card(card, replace_slot_index)
		return
	
	# Try to equip in empty slot if available
	for i in range(card_manager.max_equipped):
		if i >= card_manager.equipped.size() or card_manager.equipped[i] == null:
			card_manager.register_new_card(card)
			card_manager.equip_card(card, i)
			break

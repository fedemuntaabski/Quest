extends Node
class_name CardRewardManager

signal reward_completed(selected_card: CardData)

@export var card_manager: CardManager

var _available_cards: Array[CardData] = []
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

func generate_reward_options(count: int = 3, on_complete: Callable = Callable()) -> Array[CardData]:
	_on_reward_completed = on_complete
	return _select_random_cards(count)

func _select_random_cards(count: int) -> Array[CardData]:
	if _available_cards.is_empty():
		return []
	
	var selected: Array[CardData] = []
	var pool := _available_cards.duplicate()
	
	for i in range(min(count, pool.size())):
		var idx := randi() % pool.size()
		selected.append(pool[idx])
		pool.remove_at(idx)
	
	return selected

func apply_selected_reward(card: CardData) -> void:
	if card == null:
		return
	if card_manager:
		_add_card_to_player(card)
	
	reward_completed.emit(card)
	
	if _on_reward_completed.is_valid():
		_on_reward_completed.call(card)
	_on_reward_completed = Callable()

func _resolve_card_manager() -> void:
	if card_manager != null:
		return
	
	var player := get_tree().get_first_node_in_group("player") as Node
	if player:
		card_manager = player.get_node_or_null("CardManager") as CardManager

func _add_card_to_player(card: CardData) -> void:
	_resolve_card_manager()
	if card_manager == null:
		return
	
	# Add to deck
	card_manager.deck.append(card)
	
	# Try to equip in empty slot if available
	for i in range(card_manager.max_equipped):
		if i >= card_manager.equipped.size() or card_manager.equipped[i] == null:
			card_manager.equip_card(card, i)
			break

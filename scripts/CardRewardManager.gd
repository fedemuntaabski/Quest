extends Node
class_name CardRewardManager

signal reward_completed(selected_card: CardData)
signal reward_declined

@export var reward_ui: CardRewardUI
@export var card_manager: CardManager

var _available_cards: Array[CardData] = []
var _on_reward_completed: Callable = Callable()

func _ready() -> void:
	add_to_group("card_reward_manager")
	_load_all_cards()
	_connect_ui()

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

func _connect_ui() -> void:
	if reward_ui == null:
		return
	
	if not reward_ui.card_selected.is_connected(_on_card_selected):
		reward_ui.card_selected.connect(_on_card_selected)
	if not reward_ui.declined.is_connected(_on_reward_declined):
		reward_ui.declined.connect(_on_reward_declined)

func offer_reward(on_complete: Callable = Callable()) -> void:
	_on_reward_completed = on_complete
	
	var reward_cards := _select_random_cards(3)
	if reward_cards.is_empty():
		reward_declined.emit()
		return
	
	if reward_ui:
		reward_ui.show_reward(reward_cards)

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

func _on_card_selected(card: CardData) -> void:
	if card_manager:
		_add_card_to_player(card)
	
	reward_completed.emit(card)
	
	if _on_reward_completed.is_valid():
		_on_reward_completed.call(card)
	_on_reward_completed = Callable()

func _on_reward_declined() -> void:
	reward_declined.emit()
	
	if _on_reward_completed.is_valid():
		_on_reward_completed.call(null)
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

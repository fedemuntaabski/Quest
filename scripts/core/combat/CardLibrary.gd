extends Resource
class_name CardLibrary

@export var all_cards: Array[CardData] = []
@export var starter_deck: Array[CardData] = []
@export var reward_pool: Array[CardData] = []

func get_reward_cards() -> Array[CardData]:
	if not reward_pool.is_empty():
		return reward_pool
	return all_cards

func get_starter_deck() -> Array[CardData]:
	if not starter_deck.is_empty():
		return starter_deck
	return all_cards

func get_cards_by_category(category: String) -> Array[CardData]:
	var filtered: Array[CardData] = []
	for card in all_cards:
		if card == null:
			continue
		if card.category == category:
			filtered.append(card)
	return filtered

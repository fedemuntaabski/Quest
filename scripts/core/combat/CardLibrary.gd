extends Resource
class_name CardLibrary

@export var all_cards: Array[CardData] = []
@export var starter_deck: Array[CardData] = []

func get_all_cards() -> Array[CardData]:
	return all_cards

func get_starter_deck() -> Array[CardData]:
	return starter_deck

func get_cards_by_category(category: StringName) -> Array[CardData]:
	var filtered: Array[CardData] = []
	
	for card in all_cards:
		if card == null:
			continue
		
		if card.category == category:
			filtered.append(card)
	
	return filtered
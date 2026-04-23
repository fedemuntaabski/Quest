extends HBoxContainer

class_name CardContainer

# Maximum equipped cards
const MAX_EQUIPPED_CARDS: int = 3

# Array to store equipped cards
var equipped_cards: Array = []

# Signal for when cards change
signal cards_changed(cards: Array)

func _ready():
	custom_minimum_size = Vector2(500, 200)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)
	print("CardContainer initialized - Max capacity: %d cards" % MAX_EQUIPPED_CARDS)

# Add a card to the container
func add_card(card_data: Dictionary) -> bool:
	"""
	Add a card to the equipped cards container.
	Returns true if successful, false if container is full.
	card_data should contain: {"name": str, "description": str, "stat": str, "base_damage": int}
	"""
	if equipped_cards.size() >= MAX_EQUIPPED_CARDS:
		push_warning("CardContainer: Cannot add card - container is full (max %d)" % MAX_EQUIPPED_CARDS)
		return false
	
	equipped_cards.append(card_data)
	print("CardContainer: Card added - '%s' (%d/%d)" % [card_data.get("name", "Unknown"), equipped_cards.size(), MAX_EQUIPPED_CARDS])
	
	# Emit signal for UI updates
	cards_changed.emit(equipped_cards)
	return true

# Remove a card by index
func remove_card(index: int) -> bool:
	"""Remove a card at the given index"""
	if index < 0 or index >= equipped_cards.size():
		push_warning("CardContainer: Invalid card index %d" % index)
		return false
	
	var removed_card = equipped_cards[index]
	equipped_cards.remove_at(index)
	print("CardContainer: Card removed - '%s' (%d/%d)" % [removed_card.get("name", "Unknown"), equipped_cards.size(), MAX_EQUIPPED_CARDS])
	
	cards_changed.emit(equipped_cards)
	return true

# Get a card by index
func get_card(index: int) -> Dictionary:
	"""Get card data at index, returns empty dict if index is invalid"""
	if index >= 0 and index < equipped_cards.size():
		return equipped_cards[index]
	return {}

# Get all equipped cards
func get_all_cards() -> Array:
	"""Return a copy of all equipped cards"""
	return equipped_cards.duplicate()

# Check if container is full
func is_full() -> bool:
	return equipped_cards.size() >= MAX_EQUIPPED_CARDS

# Check if container is empty
func is_empty() -> bool:
	return equipped_cards.size() == 0

# Get current card count
func get_card_count() -> int:
	return equipped_cards.size()

# Clear all cards
func clear_cards() -> void:
	"""Remove all equipped cards"""
	equipped_cards.clear()
	print("CardContainer: All cards cleared")
	cards_changed.emit(equipped_cards)

# Swap two cards by index
func swap_cards(index_a: int, index_b: int) -> bool:
	"""Swap positions of two cards"""
	if index_a < 0 or index_a >= equipped_cards.size() or index_b < 0 or index_b >= equipped_cards.size():
		push_warning("CardContainer: Invalid swap indices %d and %d" % [index_a, index_b])
		return false
	
	var temp = equipped_cards[index_a]
	equipped_cards[index_a] = equipped_cards[index_b]
	equipped_cards[index_b] = temp
	
	cards_changed.emit(equipped_cards)
	return true

# Display card container info (for debugging)
func debug_print_container() -> void:
	print("\n=== CardContainer Debug Info ===")
	print("Capacity: %d/%d" % [equipped_cards.size(), MAX_EQUIPPED_CARDS])
	for i in range(equipped_cards.size()):
		var card = equipped_cards[i]
		print("  [%d] %s (Stat: %s, Damage: %d)" % [i, card.get("name", "?"), card.get("stat", "?"), card.get("base_damage", 0)])
	print("================================\n")

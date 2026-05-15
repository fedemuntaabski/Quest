extends Node
class_name CardRewardManager

signal reward_completed(selected_card: CardData)

@export var card_manager: CardManager
@export var card_library: CardLibrary

# Exposed weights for balancing via the editor (sum may be any positive values)
@export_range(0, 100) var strength_weight: int = 33
@export_range(0, 100) var agility_weight: int = 33
@export_range(0, 100) var magic_weight: int = 33

var _available_cards: Array[CardData] = []
var _rewarded_cards: Dictionary = {}
var _on_reward_completed: Callable = Callable()
var _category_weights: Dictionary = {
	"strength": 1.0,
	"agility": 1.0,
	"magic": 1.0,
}

func _ready() -> void:
	add_to_group("card_reward_manager")
	_load_all_cards()
	_update_category_weights()

func _update_category_weights() -> void:
	# Normalize exported integer weights into float map
	var s : Variant = max(0, int(strength_weight))
	var a : Variant = max(0, int(agility_weight))
	var m : Variant = max(0, int(magic_weight))
	var total : Variant = float(s + a + m)
	if total <= 0.0:
		_category_weights["strength"] = 1.0
		_category_weights["agility"] = 1.0
		_category_weights["magic"] = 1.0
		return
	_category_weights["strength"] = float(s) / total
	_category_weights["agility"] = float(a) / total
	_category_weights["magic"] = float(m) / total

func _load_all_cards() -> void:
	# Prefer dynamic discovery of .tres card resources in card folders so newly added cards are available at runtime.
	_available_cards.clear()
	var seen_paths: Dictionary = {}
	_collect_cards_from_dir("res://resources/cards", seen_paths)

	# Fallback to card_library if nothing discovered
	if _available_cards.is_empty():
		if card_library == null:
			card_library = load("res://resources/cards/card_library.tres") as CardLibrary
		if card_library:
			_available_cards = card_library.get_reward_cards().duplicate()

	_available_cards = _filter_valid_cards(_available_cards)


func _collect_cards_from_dir(dir_path: String, seen_paths: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full_path := "%s/%s" % [dir_path, entry]
			if dir.current_is_dir():
				_collect_cards_from_dir(full_path, seen_paths)
			elif entry.to_lower().ends_with(".tres") and not seen_paths.has(full_path):
				seen_paths[full_path] = true
				var card := load(full_path) as CardData
				if card:
					_available_cards.append(card)
		entry = dir.get_next()
	dir.list_dir_end()

func _filter_valid_cards(cards: Array[CardData]) -> Array[CardData]:
	var filtered: Array[CardData] = []
	for card in cards:
		if card:
			filtered.append(card)
	return filtered

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

	for _i in range(min(count, pool.size())):
		var selected_category := _roll_category_from_pool(pool)
		if selected_category == "":
			break

		var category_cards := _get_cards_for_category(pool, selected_category)
		if category_cards.is_empty():
			continue

		var picked := category_cards[randi() % category_cards.size()]
		selected.append(picked)
		pool.erase(picked)
	
	return selected


func _roll_category_from_pool(pool: Array[CardData]) -> String:
	var totals: Dictionary = {}
	var total_weight := 0.0

	for card in pool:
		if card == null:
			continue
		var normalized := _normalize_category(card.category)
		var weight := float(_category_weights.get(normalized, 0.0))
		if weight <= 0.0:
			continue
		totals[normalized] = float(totals.get(normalized, 0.0)) + weight
		total_weight += weight

	if total_weight <= 0.0:
		return ""

	var roll := randf() * total_weight
	var cumulative := 0.0
	for key in totals.keys():
		cumulative += float(totals[key])
		if roll <= cumulative:
			return str(key)

	return str(totals.keys().back())


func _get_cards_for_category(pool: Array[CardData], category: String) -> Array[CardData]:
	var cards: Array[CardData] = []
	for card in pool:
		if card == null:
			continue
		if _normalize_category(card.category) == category:
			cards.append(card)
	return cards


func _normalize_category(category: String) -> String:
	var normalized := category.strip_edges().to_lower()
	if normalized == "dexterity":
		return "agility"
	return normalized

func apply_selected_reward(card: CardData, replace_slot_index: int = -1) -> void:
	if card == null:
		return
	print("[CARD_REWARD_MANAGER] Applying reward card: %s to slot %d" % [card.display_name, replace_slot_index])
	_rewarded_cards[card] = true
	if card_manager:
		_add_card_to_player(card, replace_slot_index)
	
	print("[CARD_REWARD_MANAGER] Emitting reward_completed signal for: %s" % card.display_name)
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

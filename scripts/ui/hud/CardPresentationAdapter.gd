extends Node
class_name CardPresentationAdapter

## Converts raw CardData and runtime payloads into typed CardDisplayData.
## Single point of truth for card display normalization.
## This is the adapter between gameplay data and UI presentation contracts.

## Create typed display data from CardData and optional runtime state
static func create_display_data(
	card: CardData,
	runtime_state: Dictionary = {}
) -> CardDisplayData:
	"""
	Create a CardDisplayData from CardData and optional runtime state.
	
	Args:
		card: Source CardData resource
		runtime_state: Runtime state dict with keys like cooldown_remaining, is_usable, etc.
	
	Returns:
		CardDisplayData with all fields populated and validated
	"""
	return CardDisplayData.from_card_data(card, runtime_state)

## Create typed display data from an equipped-slot payload entry.
## Returns null for empty or invalid entries so callers can preserve slot empties.
static func create_display_data_from_payload_entry(payload: Variant) -> CardDisplayData:
	if payload is CardDisplayData:
		return payload as CardDisplayData
	if payload is Dictionary:
		var payload_dict := payload as Dictionary
		if payload_dict.is_empty():
			return null
		var card_data := payload_dict.get("card") as CardData
		if card_data != null:
			return create_display_data(card_data, payload_dict)
	return null

## --- Formatting Helper Methods ---
## These are used by UI consumers to format display data consistently

static func get_stats_summary(display_data: CardDisplayData) -> String:
	"""Format stats summary line for tooltip or card display.
	Example output: 'STR x1.50 | D:5 | R:2 | CD:3'
	"""
	return "%s x%.2f | D:%d | R:%d | CD:%d" % [
		display_data.stat_label,
		display_data.damage_scaling,
		display_data.base_damage,
		display_data.range,
		display_data.cooldown
	]

static func get_cooldown_text(display_data: CardDisplayData) -> String:
	"""Get cooldown display text for UI elements.
	Returns: 'Ready', 'CD: X', or cooldown value.
	"""
	if display_data.cooldown <= 0:
		return "Ready"
	if display_data.cooldown_remaining > 0:
		return "CD: %d" % display_data.cooldown_remaining
	return "CD: %d" % display_data.cooldown

static func get_playability_text(display_data: CardDisplayData) -> String:
	"""Get playability indicator text.
	Returns: Empty string if fully playable, otherwise reason.
	"""
	if not display_data.is_usable:
		return display_data.playability_reason if not display_data.playability_reason.is_empty() else "Not usable"
	if not display_data.full_playable:
		return display_data.playability_reason if not display_data.playability_reason.is_empty() else "Restricted"
	return ""

static func get_category_color(category: String) -> Color:
	"""Get display color for a card category."""
	match category.to_lower():
		"strength":
			return QuestPalette.CARD_STRENGTH
		"agility":
			return QuestPalette.CARD_AGILITY
		"magic":
			return QuestPalette.CARD_MAGIC
		_:
			return QuestPalette.CARD_NEUTRAL

static func get_playability_color(display_data: CardDisplayData) -> Color:
	"""Get color indicator for playability state."""
	if not display_data.is_usable:
		return QuestPalette.UI_TEXT_BLOCKED
	if not display_data.full_playable:
		return QuestPalette.UI_TEXT_WARN
	return QuestPalette.UI_TEXT_READY

static func get_effects_summary(card: Resource) -> String:
	"""Get a readable comma-separated effect summary for reward and card detail UI."""
	if card == null:
		return ""

	var effects_arr: Array = []
	if "effects" in card:
		effects_arr = card.effects

	var effects_texts: Array[String] = []
	for effect in effects_arr:
		if effect == null:
			continue
		var desc := ""
		if typeof(effect) == TYPE_DICTIONARY:
			desc = str(effect.get("description", ""))
		elif effect is CardEffect:
			desc = str(effect.get_description())
		elif typeof(effect) == TYPE_OBJECT:
			var candidate = effect.get("description")
			if candidate != null and str(candidate) != "":
				desc = str(candidate)
		else:
			var text := str(effect)
			if text != "" and not (text.begins_with("res://") or text.begins_with("user://")):
				desc = text
		if desc != "":
			effects_texts.append(desc)

	return ", ".join(effects_texts)


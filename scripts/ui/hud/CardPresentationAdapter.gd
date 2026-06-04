extends Node
class_name CardPresentationAdapter

## Adapter: converts gameplay data into UI-ready CardDisplayData.
## This file ONLY handles transformation between layers.
## Formatting logic is delegated to internal helpers.

# =========================================================
# PUBLIC API - CREATION
# =========================================================

static func create_display_data(
	card: CardData,
	runtime_state: Dictionary = {}
) -> CardDisplayData:
	return CardDisplayData.from_card_data(card, runtime_state)


static func create_display_data_from_payload_entry(payload: Variant) -> CardDisplayData:
	if payload == null:
		return null

	if payload is CardDisplayData:
		return payload

	if payload is Dictionary:
		var payload_dict := payload as Dictionary
		if payload_dict.is_empty():
			return null

		var card_data = payload_dict.get("card")
		if card_data is CardData:
			return create_display_data(card_data, payload_dict)

	return null


# =========================================================
# PUBLIC API - FORMATTING (UI SAFE)
# =========================================================

static func get_stats_summary(display_data: CardDisplayData) -> String:
	if display_data == null:
		return ""

	return "%s x%.2f | D:%d | R:%d | CD:%d" % [
		display_data.stat_label,
		display_data.damage_scaling,
		display_data.base_damage,
		display_data.range,
		display_data.cooldown
	]


static func get_cooldown_text(display_data: CardDisplayData) -> String:
	if display_data == null:
		return ""

	if display_data.cooldown <= 0:
		return "Ready"

	if display_data.cooldown_remaining > 0:
		return "CD: %d" % display_data.cooldown_remaining

	return "CD: %d" % display_data.cooldown


static func get_playability_text(display_data: CardDisplayData) -> String:
	if display_data == null:
		return ""

	if not display_data.is_usable:
		return _safe_reason(display_data.playability_reason, "Not usable")

	if not display_data.full_playable:
		return _safe_reason(display_data.playability_reason, "Restricted")

	return ""


static func get_category_color(category: String) -> Color:
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
	if display_data == null:
		return QuestPalette.UI_TEXT_BLOCKED

	if not display_data.is_usable:
		return QuestPalette.UI_TEXT_BLOCKED

	if not display_data.full_playable:
		return QuestPalette.UI_TEXT_WARN

	return QuestPalette.UI_TEXT_READY


# =========================================================
# INTERNAL SAFE HELPERS
# =========================================================

static func _safe_reason(reason: String, fallback: String) -> String:
	if reason == null:
		return fallback

	var r := str(reason)
	if r.is_empty():
		return fallback

	return r


# =========================================================
# EFFECTS (refactored to avoid unsafe reflection)
# =========================================================

static func get_effects_summary(card: Resource) -> String:
	if card == null:
		return ""

	var effects_arr: Array = []

	if card.has_method("get_effects"):
		effects_arr = card.get_effects()
	elif "effects" in card:
		effects_arr = card.effects
	else:
		return ""

	var out: Array[String] = []

	for effect in effects_arr:
		if effect == null:
			continue

		var desc := _extract_effect_description(effect)
		if desc != "":
			out.append(desc)

	return ", ".join(out)


static func _extract_effect_description(effect: Variant) -> String:
	# Typed effect object
	if effect is CardEffect:
		if effect.has_method("get_description"):
			return str(effect.get_description())
		return ""

	# Dictionary effect
	if effect is Dictionary:
		return str(effect.get("description", ""))

	# Generic object with method
	if typeof(effect) == TYPE_OBJECT:
		if effect.has_method("get_description"):
			return str(effect.get_description())

		if effect.has_method("get"):
			var maybe = effect.get("description")
			if maybe != null:
				return str(maybe)

		return ""

	# Fallback safe string
	var text := str(effect)
	if text.begins_with("res://") or text.begins_with("user://"):
		return ""

	return text
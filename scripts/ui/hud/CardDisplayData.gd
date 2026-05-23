extends Resource
class_name CardDisplayData

## Explicit typed contract for card display across UI systems.
## Replaces implicit dictionary payloads with validated typed data.
## All fields have documented defaults and types.

# Display fields (from CardData + runtime formatting)
var display_name: String = "Unknown Card"
var description: String = ""
var icon: Texture2D = null
var category: String = "uncategorized"  # strength, agility, magic, etc.
var stat_label: String = "STR"  # Formatted stat type for display

# Gameplay value fields (from CardData)
var base_damage: int = 0
var damage_scaling: float = 1.0
var range: int = 1
var cooldown: int = 0

# Runtime state fields (from CardManager payload)
var cooldown_remaining: int = 0
var is_usable: bool = true
var full_playable: bool = true
var playability_reason: String = ""  # Empty if fully playable, otherwise reason why not

func _init(
	p_display_name: String = "Unknown Card",
	p_description: String = "",
	p_icon: Texture2D = null,
	p_category: String = "uncategorized",
	p_stat_label: String = "STR",
	p_base_damage: int = 0,
	p_damage_scaling: float = 1.0,
	p_range: int = 1,
	p_cooldown: int = 0,
	p_cooldown_remaining: int = 0,
	p_is_usable: bool = true,
	p_full_playable: bool = true,
	p_playability_reason: String = ""
) -> void:
	display_name = p_display_name
	description = p_description
	icon = p_icon
	category = p_category
	stat_label = p_stat_label
	base_damage = p_base_damage
	damage_scaling = p_damage_scaling
	range = p_range
	cooldown = p_cooldown
	cooldown_remaining = p_cooldown_remaining
	is_usable = p_is_usable
	full_playable = p_full_playable
	playability_reason = p_playability_reason
	_validate()

## Validation: ensure required fields are non-empty
func _validate() -> void:
	if display_name.is_empty():
		push_warning("[CardDisplayData] display_name is empty, defaulting to 'Unknown'")
		display_name = "Unknown"
	if stat_label.is_empty():
		stat_label = "STR"

## Static factory method for creating from CardData
static func from_card_data(card: CardData, runtime_state: Dictionary = {}) -> CardDisplayData:
	if card == null:
		push_error("[CardDisplayData] Cannot create from null CardData")
		return CardDisplayData.new()
	
	var stat_key = card.stat_key if card.has_meta("stat_key") or "stat_key" in card else "strength"
	var stat_label_str = StatTypes.get_label(stat_key) if StatTypes else stat_key
	
	var data = CardDisplayData.new(
		card.display_name if not card.display_name.is_empty() else "Unknown Card",
		card.description,
		card.icon,
		card.category,
		stat_label_str,
		card.base_damage,
		card.damage_scaling,
		card.range,
		card.cooldown
	)
	
	# Populate from runtime state (if provided)
	if runtime_state.has("cooldown_remaining"):
		data.cooldown_remaining = int(runtime_state.get("cooldown_remaining", 0))
	if runtime_state.has("is_usable"):
		data.is_usable = bool(runtime_state.get("is_usable", true))
	if runtime_state.has("full_playable"):
		data.full_playable = bool(runtime_state.get("full_playable", true))
	if runtime_state.has("playability_reason"):
		data.playability_reason = str(runtime_state.get("playability_reason", ""))
	
	return data


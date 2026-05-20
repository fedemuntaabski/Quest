# Phase 3: Payload Contract Stabilization

## Objective

Replace implicit runtime dictionary contracts with explicit, validated typed interfaces for card payloads shared across UI systems.

---

## Current State Analysis

### Card Payload Fields (Scattered Across 5+ Consumers)

| Field | Source | Consumers | Usage |
|-------|--------|-----------|-------|
| `display_name` | CardData | CardRewardUI, HotbarSlot, CardTooltip, CardPanelUI | Display label |
| `description` | CardData | CardRewardUI, CardTooltip, CardPanelUI | Tooltip/details text |
| `icon` | CardData | CardRewardUI, HotbarSlot, CardPanelUI, CardTooltip | Visual representation |
| `category` | CardData | CardRewardUI | Reward category badge |
| `stat_key` | CardData | CardRewardUI, HotbarSlot | Stat affinity label |
| `damage_scaling` | CardData | CardRewardUI | Damage formula display |
| `base_damage` | CardData | CardRewardUI | Damage value |
| `range` | CardData | CardRewardUI | Range value |
| `cooldown` | CardData | CardRewardUI | Cooldown value |
| `cooldown_remaining` | CardManager payload | HotbarSlot, CardTooltip, CardPanelUI | Remaining cooldown |
| `full_playable` | CardManager payload | HotbarSlot | Playability state |
| `is_usable` | CardManager payload | HotbarSlot | Usability flag |
| `playability_reasons` | CardManager payload | HotbarSlot | Fallback/debug info |

### Problems

1. **Schema is implicit**: No formal contract definition; fields are discovered by reading consumer code
2. **Duplication**: Each consumer independently formats the same fields (e.g., `display_name` rendering)
3. **Optional fields with fallbacks**: Multiple consumers have defensive `.get("field", default)` logic
4. **Silent failures**: Missing or misnamed fields degrade silently (fallback to default)
5. **Schema drift risk**: If CardManager changes payload structure, multiple UI surfaces break independently
6. **No validation at boundaries**: Consumers trust upstream payload structure

### Risk Assessment

- **Short-term**: Current code works, but scaling is risky
- **Medium-term**: Adding reroll, preview, or upgrade features will multiply payload duplication
- **Long-term**: Schema drift will cause inconsistent UI behavior and hard-to-debug issues

---

## Proposed Solution: Typed Payload Wrapper

### Step 1: Define Payload Contract

Create a lightweight typed class `CardDisplayData` that:
- **Documents** all expected fields explicitly
- **Normalizes** field naming and types
- **Provides defaults** for optional fields
- **Validates** on construction (optional)

### Step 2: Create Adapter Layer

Create `CardPresentationAdapter` that:
- Takes raw CardData and runtime payload dictionaries
- Normalizes and validates them
- Returns typed `CardDisplayData` objects
- **Single point of truth** for field interpretation

### Step 3: Update UI Consumers

Refactor CardTooltip, HotbarSlot, CardPanelUI, CardRewardUI to:
- Accept `CardDisplayData` instead of dictionaries
- Remove local fallback logic
- Use typed properties directly

### Step 4: Update Payload Sources

Update CardManager and other payload producers to:
- Use adapter before emitting payloads to UI
- Maintain backward compatibility during migration

---

## Implementation Plan

### Phase 3A: Create CardDisplayData Typed Wrapper

File: `scripts/core/cards/CardDisplayData.gd`

```gdscript
class_name CardDisplayData

## Explicit card display contract for UI systems.
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

## Optional: Validation method called on construction
func validate() -> bool:
	# Ensure required fields are non-empty
	if display_name.is_empty():
		push_warning("[CardDisplayData] display_name is empty")
		display_name = "Unknown"
	return true

## Static factory method for creating from CardData
static func from_card_data(card: CardData, runtime_state: Dictionary = {}) -> CardDisplayData:
	var data = CardDisplayData.new()
	
	# Populate from CardData
	data.display_name = card.display_name if not card.display_name.is_empty() else "Unknown Card"
	data.description = card.description
	data.icon = card.icon
	data.category = card.category
	data.stat_label = StatTypes.get_label(card.stat_key) if card.has_meta("stat_key") else "STR"
	data.base_damage = card.base_damage
	data.damage_scaling = card.damage_scaling
	data.range = card.range
	data.cooldown = card.cooldown
	
	# Populate from runtime state (if provided)
	if runtime_state.has("cooldown_remaining"):
		data.cooldown_remaining = int(runtime_state.get("cooldown_remaining", 0))
	if runtime_state.has("is_usable"):
		data.is_usable = bool(runtime_state.get("is_usable", true))
	if runtime_state.has("full_playable"):
		data.full_playable = bool(runtime_state.get("full_playable", true))
	if runtime_state.has("playability_reason"):
		data.playability_reason = str(runtime_state.get("playability_reason", ""))
	
	data.validate()
	return data
```

### Phase 3B: Create Presentation Adapter

File: `scripts/ui/hud/CardPresentationAdapter.gd`

```gdscript
class_name CardPresentationAdapter

## Converts raw CardData and runtime payloads into typed CardDisplayData.
## Single point for card display normalization.

static func create_display_data(
	card: CardData,
	runtime_state: Dictionary = {}
) -> CardDisplayData:
	"""Create a CardDisplayData from CardData and optional runtime state."""
	return CardDisplayData.from_card_data(card, runtime_state)

static func create_batch(
	cards: Array[CardData],
	runtime_states: Dictionary = {}  # key: card_id, value: state dict
) -> Array[CardDisplayData]:
	"""Create display data for multiple cards."""
	var results: Array[CardDisplayData] = []
	for card in cards:
		var state = runtime_states.get(card.resource_path, {})
		results.append(create_display_data(card, state))
	return results

## Formatting helpers (used by UI consumers)

static func get_stats_summary(display_data: CardDisplayData) -> String:
	"""Format stats for tooltip or display."""
	return "%s x%.2f | D:%d | R:%d | CD:%d" % [
		display_data.stat_label,
		display_data.damage_scaling,
		display_data.base_damage,
		display_data.range,
		display_data.cooldown
	]

static func get_cooldown_text(display_data: CardDisplayData) -> String:
	"""Get cooldown display text."""
	if display_data.cooldown <= 0:
		return "Ready"
	if display_data.cooldown_remaining > 0:
		return "CD: %d" % display_data.cooldown_remaining
	return "CD: %d" % display_data.cooldown

static func get_playability_text(display_data: CardDisplayData) -> String:
	"""Get playability indicator."""
	if not display_data.is_usable:
		return display_data.playability_reason if not display_data.playability_reason.is_empty() else "Not usable"
	if not display_data.full_playable:
		return display_data.playability_reason if not display_data.playability_reason.is_empty() else "Restricted"
	return ""
```

### Phase 3C: Update UI Consumers

Update each consumer to accept `CardDisplayData` instead of dictionaries:

- **HotbarSlot**: `update(display_data: CardDisplayData)`
- **CardTooltip**: `show(display_data: CardDisplayData)`
- **CardPanelUI**: `refresh(display_data_list: Array[CardDisplayData])`
- **CardRewardUI**: `_create_card_button(display_data: CardDisplayData)` (uses source CardData for details, but for consistency)

### Phase 3D: Update Payload Sources

Update CardManager and CardRewardUI to use adapter:

```gdscript
# In CardManager or wherever payloads are created
func _emit_ui_state_changed() -> void:
	var equipped_display: Array[CardDisplayData] = []
	for card in equipped_cards:
		var state = _get_card_runtime_state(card)
		equipped_display.append(CardPresentationAdapter.create_display_data(card, state))
	ui_state_changed.emit(equipped_display)
```

---

## Migration Strategy (Incremental)

### Phase 3A: Create (Non-Breaking)
1. Create `CardDisplayData` and `CardPresentationAdapter` classes
2. Leave all consumers unchanged initially
3. Verify compilation

### Phase 3B: Adopt (One Consumer at a Time)
1. Update `HotbarSlot` first (most isolated, smallest consumer)
2. Test in-game with hotbar interactions
3. Update `CardTooltip` next
4. Update `CardPanelUI`
5. Update `CardRewardUI` (most complex)

### Phase 3C: Optional: Remove Backward Compat
- Once all consumers use typed data, remove dictionary payloads from signal definitions
- This is optional; maintaining both is acceptable for robustness

---

## Verification Checklist

### Before Migration
- [ ] All field references in consumers documented in `CardDisplayData`
- [ ] Default values chosen and tested
- [ ] Adapter creates valid `CardDisplayData` objects for all card types

### After HotbarSlot Migration
- [ ] Hotbar displays correctly in-game
- [ ] Card icons, names, cooldowns render as expected
- [ ] No visual regressions

### After Full Migration
- [ ] No `.get("field", default)` calls remain in UI consumers
- [ ] Schema changes (new fields) only require adapter update, not consumer changes
- [ ] New UI surfaces can easily consume typed data

---

## Benefits Realized

1. **Schema Contract**: Future field additions/changes are explicit and documented
2. **Duplication Reduced**: All formatting logic moves to adapter or typed class methods
3. **Type Safety**: UI consumers work with typed objects, reducing silent failures
4. **Testability**: `CardDisplayData` can be unit-tested independently
5. **Extensibility**: New UI types (card upgrade preview, reroll UI, etc.) can easily get display data

---

## Rollback Plan

If migration causes issues:
1. Revert consumer changes to dictionary-based inputs
2. Keep `CardDisplayData` and adapter (non-breaking additions)
3. Plan phased re-adoption for next iteration


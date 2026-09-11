extends RefCounted
class_name QuestPalette

## Central reusable palette for Quest's low-color medieval visual direction.
## Consumed by UI chrome, card presentation, world feedback, combat FX, and theme helpers.

const DUNGEON_CHARCOAL: Color = Color(0.08, 0.07, 0.06, 1.0)
const DUNGEON_STONE: Color = Color(0.13, 0.12, 0.11, 1.0)
const DUNGEON_ASH: Color = Color(0.24, 0.23, 0.22, 1.0)
const DUNGEON_MUD: Color = Color(0.21, 0.17, 0.13, 1.0)

const PARCHMENT: Color = Color(0.95, 0.85, 0.62, 1.0)
const PARCHMENT_LIGHT: Color = Color(0.98, 0.92, 0.76, 1.0)
const PARCHMENT_FADED: Color = Color(0.80, 0.78, 0.72, 1.0)
const INK: Color = Color(0.05, 0.03, 0.02, 1.0)

const METAL: Color = Color(0.62, 0.66, 0.70, 1.0)
const STEEL: Color = Color(0.71, 0.75, 0.79, 1.0)

const GOLD: Color = Color(0.95, 0.78, 0.42, 1.0)
const GOLD_LIGHT: Color = Color(1.00, 0.88, 0.53, 1.0)
const GOLD_DARK: Color = Color(0.86, 0.67, 0.33, 1.0)

const BLOOD: Color = Color(0.78, 0.26, 0.24, 1.0)
const BLOOD_LIGHT: Color = Color(0.95, 0.35, 0.32, 1.0)
const MOSS: Color = Color(0.62, 0.80, 0.62, 1.0)
const VIOLET: Color = Color(0.61, 0.46, 0.74, 1.0)

const UI_PANEL_BG: Color = Color(0.08, 0.08, 0.10, 0.98)
const UI_PANEL_BG_SOFT: Color = Color(0.15, 0.15, 0.18, 0.80)
const UI_PANEL_BORDER: Color = Color(0.30, 0.32, 0.38, 1.0)
const UI_PANEL_BORDER_HOVER: Color = Color(0.40, 0.50, 0.70, 1.0)
const UI_PANEL_BORDER_SELECTED: Color = Color(0.60, 0.80, 1.00, 1.0)

const UI_TEXT_PRIMARY: Color = Color(0.95, 0.95, 0.92, 1.0)
const UI_TEXT_SECONDARY: Color = Color(0.80, 0.80, 0.80, 0.80)
const UI_TEXT_MUTED: Color = Color(0.60, 0.60, 0.60, 1.0)
const UI_TEXT_READY: Color = Color(0.62, 1.00, 0.62, 1.0)
const UI_TEXT_WARN: Color = Color(1.00, 0.90, 0.45, 1.0)
const UI_TEXT_BLOCKED: Color = Color(1.00, 0.55, 0.55, 1.0)

const COMBAT_TEXT_DAMAGE: Color = Color(1.00, 0.40, 0.30, 1.0)
const COMBAT_TEXT_HEAL: Color = Color(0.35, 1.00, 0.45, 1.0)
const COMBAT_TEXT_MISS: Color = Color(0.90, 0.90, 0.90, 1.0)
const COMBAT_FLASH_TINT: Color = Color(1.00, 0.90, 0.90, 1.0)
const COMBAT_PARTICLE_SPARK: Color = Color(1.00, 0.60, 0.20, 1.0)
const COMBAT_TARGET_TINT_DEFAULT: Color = Color(1.00, 0.60, 0.60, 1.0)

const COMBAT_ROLL_HIT: Color = Color(0.62, 1.00, 0.62, 1.0)
const COMBAT_ROLL_CRIT: Color = Color(1.00, 0.90, 0.45, 1.0)
const COMBAT_ROLL_FAIL: Color = Color(1.00, 0.55, 0.55, 1.0)

const TIMER_NORMAL: Color = Color(1.00, 1.00, 1.00, 1.0)
const TIMER_WARNING: Color = Color(1.00, 0.85, 0.20, 1.0)
const TIMER_CRITICAL: Color = Color(1.00, 0.24, 0.20, 1.0)

const CURRENCY_GOLD_POPUP: Color = Color(1.00, 0.84, 0.10, 1.0)

const CARD_STRENGTH: Color = BLOOD_LIGHT
const CARD_AGILITY: Color = STEEL
const CARD_MAGIC: Color = VIOLET
const CARD_VITALITY: Color = MOSS
const CARD_NEUTRAL: Color = PARCHMENT_FADED

static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
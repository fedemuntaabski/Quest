extends Node

## Lightweight theme facade for reusable palette-driven style boxes.
## Consumed by card UI, menus, and future shader/material helpers.

static func build_panel_style(bg_color: Color, border_color: Color, border_width: int = 2, radius: int = 10, content_margin: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	if content_margin > 0:
		style.content_margin_left = content_margin
		style.content_margin_top = content_margin
		style.content_margin_right = content_margin
		style.content_margin_bottom = content_margin
	return style

static func build_reward_card_style(border_color: Color) -> StyleBoxFlat:
	return build_panel_style(QuestPalette.UI_PANEL_BG, border_color, 2, 10)

static func build_slot_icon_style() -> StyleBoxFlat:
	return build_panel_style(QuestPalette.UI_PANEL_BG_SOFT, QuestPalette.UI_PANEL_BORDER, 1, 6)

static func get_combat_feedback_palette() -> Dictionary:
	return {
		"damage_text": QuestPalette.COMBAT_TEXT_DAMAGE,
		"miss_text": QuestPalette.COMBAT_TEXT_MISS,
		"flash_tint": QuestPalette.COMBAT_FLASH_TINT,
		"particle": QuestPalette.COMBAT_PARTICLE_SPARK,
		"target_tint": QuestPalette.COMBAT_TARGET_TINT_DEFAULT,
		"roll_hit": QuestPalette.COMBAT_ROLL_HIT,
		"roll_crit": QuestPalette.COMBAT_ROLL_CRIT,
		"roll_fail": QuestPalette.COMBAT_ROLL_FAIL,
		"timer_normal": QuestPalette.TIMER_NORMAL,
		"timer_warning": QuestPalette.TIMER_WARNING,
		"timer_critical": QuestPalette.TIMER_CRITICAL,
		"gold_popup": QuestPalette.CURRENCY_GOLD_POPUP,
	}

static func get_combat_feedback_timing() -> Dictionary:
	return {
		"damage_flash_duration": 0.12,
		"particle_count": 6,
		"hit_pause_duration": 0.04,
		"hit_pause_scale": 0.18,
		"screen_shake_intensity": 2.0,
		"screen_shake_duration": 0.12,
	}

static func tactical_hover_color(is_walkable: bool) -> Color:
	if is_walkable:
		return QuestPalette.with_alpha(QuestPalette.MOSS, 0.20)
	return QuestPalette.with_alpha(QuestPalette.BLOOD_LIGHT, 0.20)

static func tactical_path_fill_color(alpha: float) -> Color:
	return QuestPalette.with_alpha(QuestPalette.CARD_NEUTRAL, alpha)

static func tactical_path_border_color() -> Color:
	return QuestPalette.with_alpha(QuestPalette.UI_TEXT_PRIMARY, 0.22)

static func tactical_path_line_color() -> Color:
	return QuestPalette.with_alpha(QuestPalette.UI_TEXT_PRIMARY, 0.55)

static func tactical_range_fill_color() -> Color:
	return QuestPalette.with_alpha(QuestPalette.BLOOD, 0.18)

static func tactical_range_border_color() -> Color:
	return QuestPalette.with_alpha(QuestPalette.BLOOD_LIGHT, 0.95)

static func tactical_range_inner_color() -> Color:
	return QuestPalette.with_alpha(QuestPalette.PARCHMENT_FADED, 0.18)

static func tactical_hover_actor_color(in_range: bool) -> Color:
	if in_range:
		return QuestPalette.with_alpha(QuestPalette.MOSS, 0.20)
	return QuestPalette.with_alpha(QuestPalette.BLOOD_LIGHT, 0.20)

static func tactical_arrow_color() -> Color:
	return QuestPalette.with_alpha(QuestPalette.UI_TEXT_PRIMARY, 0.85)

static func tactical_path_dot_color() -> Color:
	return QuestPalette.with_alpha(
		QuestPalette.PARCHMENT_LIGHT,
		0.9
	)

static func tactical_hover_border_color() -> Color:
	return QuestPalette.with_alpha(
		QuestPalette.PARCHMENT_LIGHT,
		1.0
	)

static func tactical_enemy_ring_color() -> Color:
	return QuestPalette.with_alpha(
		QuestPalette.BLOOD_LIGHT,
		0.95
	)

static func tactical_destination_color() -> Color:
	return QuestPalette.with_alpha(
		QuestPalette.GOLD_LIGHT,
		1.0
	)
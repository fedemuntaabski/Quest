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

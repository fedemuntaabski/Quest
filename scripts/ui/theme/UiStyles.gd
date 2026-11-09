class_name UiStyles
extends RefCounted

## Static StyleBoxFlat builders shared by menus, HUD and card UI (not an autoload).

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


## Gold-framed menu button (Pausa, Opciones, dialogs, end screens); `danger` = red frame.
static func style_menu_button(button: Button, danger: bool = false) -> void:
	if button == null:
		return

	var border_base: Color = QuestPalette.BLOOD if danger else QuestPalette.GOLD_DARK
	var border_hover: Color = QuestPalette.BLOOD_LIGHT if danger else QuestPalette.GOLD_LIGHT
	var text_base: Color = QuestPalette.PARCHMENT
	var text_hover: Color = QuestPalette.PARCHMENT_LIGHT
	var text_pressed: Color = QuestPalette.BLOOD_LIGHT if danger else QuestPalette.GOLD

	button.add_theme_color_override("font_color", text_base)
	button.add_theme_color_override("font_focus_color", text_hover)
	button.add_theme_color_override("font_hover_color", text_hover)
	button.add_theme_color_override("font_pressed_color", text_pressed)
	button.add_theme_color_override("font_outline_color", QuestPalette.INK)
	button.add_theme_constant_override("outline_size", 3)

	button.add_theme_stylebox_override("normal", build_panel_style(QuestPalette.DUNGEON_MUD, border_base, 3, 16, 16))
	button.add_theme_stylebox_override("pressed", build_panel_style(QuestPalette.DUNGEON_CHARCOAL, border_base, 3, 16, 16))
	button.add_theme_stylebox_override("hover", build_panel_style(QuestPalette.DUNGEON_MUD, border_hover, 3, 16, 16))
	button.add_theme_stylebox_override("focus", build_panel_style(QuestPalette.DUNGEON_MUD, QuestPalette.PARCHMENT_LIGHT, 4, 16, 16))

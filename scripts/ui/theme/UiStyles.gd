class_name UiStyles
extends RefCounted

## Static StyleBoxFlat builders shared by menus, HUD and card UI (not an autoload).
## menu-33: the menu look lives here too (stone plaques with an aged-gold rim, framed
## panels with gold corners, titles, fields, tabs, hero cards); every menu screen calls
## these instead of keeping its own StyleBoxes in the .tscn.

const TITLE_FONT: FontFile = preload("res://assets/fonts/mainfont.ttf")
const UI_FONT: FontFile = preload("res://assets/fonts/secundaryfont.ttf")

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


# ---------------- BUTTONS ----------------

## One state of the menu plaque: dark crypt stone, heavier left rim, aged gold
## (banner red when `danger`). hover = warmer stone + ember glow (the shadow);
## focus = a pale gold ring drawn over the current state.
static func build_plaque_style(state: String, danger: bool = false, marker: bool = true) -> StyleBoxFlat:
	var rim: Color = QuestPalette.BANNER_RED if danger else QuestPalette.AGED_GOLD
	var rim_hot: Color = QuestPalette.BANNER_RED_LIGHT if danger else QuestPalette.RELIC_GOLD
	var glow: Color = QuestPalette.BANNER_RED_LIGHT if danger else QuestPalette.EMBER
	var s := StyleBoxFlat.new()
	s.content_margin_left = 46 if marker else 18
	s.content_margin_right = 28 if marker else 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.set_corner_radius_all(3)
	s.border_width_left = 3
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 2
	match state:
		"hover":
			s.bg_color = Color(0.17, 0.14, 0.10, 0.94)
			s.border_color = rim_hot
			s.shadow_color = Color(glow, 0.32)
			s.shadow_size = 14
		"pressed":
			s.bg_color = Color(0.05, 0.05, 0.05, 0.95)
			s.border_color = glow
			s.shadow_color = Color(glow, 0.45)
			s.shadow_size = 8
		"disabled":
			s.bg_color = Color(QuestPalette.CRYPT_STONE, 0.55)
			s.border_color = Color(rim, 0.35)
		"focus":
			s.draw_center = false
			s.set_border_width_all(2)
			s.border_color = QuestPalette.RELIC_GOLD_PALE
			s.set_expand_margin_all(4)
			s.set_corner_radius_all(5)
		_:
			s.bg_color = Color(QuestPalette.CRYPT_STONE, 0.88)
			s.border_color = rim
			s.shadow_color = Color(0, 0, 0, 0.45)
			s.shadow_size = 6
			s.shadow_offset = Vector2(0, 3)
	return s


static func _apply_plaque(button: Button, danger: bool, marker: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, build_plaque_style(state, danger, marker))
	button.add_theme_stylebox_override("hover_pressed", build_plaque_style("pressed", danger, marker))
	var hot: Color = QuestPalette.PARCHMENT_LIGHT
	button.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	button.add_theme_color_override("font_focus_color", hot)
	button.add_theme_color_override("font_hover_color", hot)
	button.add_theme_color_override("font_hover_pressed_color", hot)
	button.add_theme_color_override("font_pressed_color", QuestPalette.BANNER_RED_LIGHT if danger else QuestPalette.RELIC_GOLD)
	button.add_theme_color_override("font_disabled_color", Color(QuestPalette.PARCHMENT, 0.38))
	button.add_theme_color_override("font_outline_color", QuestPalette.INK)
	button.add_theme_constant_override("outline_size", 3)


## Gold-framed menu button (Pausa, Opciones, dialogs, end screens); `danger` = red frame.
## menu-33: same stone plaque as the main menu, without the side marker.
static func style_menu_button(button: Button, danger: bool = false) -> void:
	if button == null:
		return
	_apply_plaque(button, danger, false)


## menu-33: the main menu / sub-screen button: plaque + EB Garamond at `font_px`
## (Accessibility.font) + the lozenge marker that lights on hover/focus.
static func style_plaque_button(button: Button, danger: bool = false, font_px: int = 24, marker: bool = true) -> void:
	if button == null:
		return
	_apply_plaque(button, danger, marker)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", Accessibility.font(font_px))
	if marker:
		MenuButtonDecor.attach(button, danger)


# ---------------- PANELS / TEXT ----------------

## Framed panel: near-black crypt stone, thin aged-gold rim, deep shadow.
static func build_frame_style(content_margin: int = 30) -> StyleBoxFlat:
	var s := build_panel_style(Color(QuestPalette.CRYPT_INK, 0.92), Color(QuestPalette.AGED_GOLD, 0.9), 2, 2, content_margin)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 18
	return s


## Frame style + gold corner brackets (MenuFrameDecor). Panel / PanelContainer.
static func style_menu_frame(panel: Control, content_margin: int = 30) -> MenuFrameDecor:
	if panel == null:
		return null
	panel.add_theme_stylebox_override("panel", build_frame_style(content_margin))
	return MenuFrameDecor.attach(panel)


## Inner well inside a frame (slot details, hero preview, player list).
static func build_inset_style(content_margin: int = 18) -> StyleBoxFlat:
	return build_panel_style(Color(0.02, 0.03, 0.035, 0.66), Color(QuestPalette.AGED_GOLD, 0.45), 1, 2, content_margin)


## A Theme whose only setting is the default font (EB Garamond): set it on a menu root
## so code-built labels/checks use it. No size: the text scale keeps working.
static func menu_font_theme() -> Theme:
	var t := Theme.new()
	t.default_font = UI_FONT
	return t


## Almendra SC header in relic gold with a soft ember halo.
static func style_menu_title(label: Label, px: int = 36) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", Accessibility.font(px))
	label.add_theme_color_override("font_color", QuestPalette.RELIC_GOLD_PALE)
	label.add_theme_color_override("font_outline_color", QuestPalette.INK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color(QuestPalette.EMBER, 0.28))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 14)


## EB Garamond body text in parchment.
static func style_menu_text(label: Control, px: int = 20, color: Color = QuestPalette.PARCHMENT) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", Accessibility.font(px))
	label.add_theme_color_override("font_color", color)


## Gold rule with a centre lozenge, to put under a title.
static func make_ornament() -> MenuOrnament:
	return MenuOrnament.new()


## Puts a MenuOrnament right after `node` in its parent (once).
static func add_ornament_after(node: Control) -> MenuOrnament:
	if node == null or node.get_parent() == null:
		return null
	var parent := node.get_parent()
	var existing := parent.get_node_or_null(NodePath(node.name + "Ornament"))
	if existing:
		return existing as MenuOrnament
	var orn := make_ornament()
	orn.name = node.name + "Ornament"
	parent.add_child(orn)
	parent.move_child(orn, node.get_index() + 1)
	return orn


# ---------------- FIELDS ----------------

## OptionButton / LineEdit / SpinBox field: dark well, gold rim when hot.
static func style_menu_field(control: Control) -> void:
	if control == null:
		return
	var normal := build_panel_style(Color(0.02, 0.03, 0.035, 0.85), Color(QuestPalette.AGED_GOLD, 0.7), 1, 2)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hot := normal.duplicate() as StyleBoxFlat
	hot.border_color = QuestPalette.RELIC_GOLD
	hot.bg_color = Color(0.10, 0.09, 0.07, 0.92)
	var focus := build_plaque_style("focus")
	if control is LineEdit:
		control.add_theme_stylebox_override("normal", normal)
		control.add_theme_stylebox_override("focus", hot)
		control.add_theme_color_override("font_color", QuestPalette.PARCHMENT_LIGHT)
		control.add_theme_color_override("font_placeholder_color", Color(QuestPalette.PARCHMENT, 0.45))
		control.add_theme_color_override("caret_color", QuestPalette.RELIC_GOLD)
	elif control is Button:
		control.add_theme_stylebox_override("normal", normal)
		control.add_theme_stylebox_override("hover", hot)
		control.add_theme_stylebox_override("pressed", hot)
		control.add_theme_stylebox_override("hover_pressed", hot)
		control.add_theme_stylebox_override("focus", focus)
		control.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
		control.add_theme_color_override("font_hover_color", QuestPalette.PARCHMENT_LIGHT)
		control.add_theme_color_override("font_focus_color", QuestPalette.PARCHMENT_LIGHT)


## HSlider: thin dark groove, gold fill.
static func style_menu_slider(slider: Slider) -> void:
	if slider == null:
		return
	var groove := build_panel_style(Color(0.02, 0.03, 0.035, 0.9), Color(QuestPalette.AGED_GOLD, 0.55), 1, 2)
	groove.content_margin_top = 3
	groove.content_margin_bottom = 3
	var fill := build_panel_style(Color(QuestPalette.AGED_GOLD, 0.95), Color(QuestPalette.RELIC_GOLD, 1.0), 1, 2)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	var fill_hot := fill.duplicate() as StyleBoxFlat
	fill_hot.bg_color = QuestPalette.RELIC_GOLD
	slider.add_theme_stylebox_override("slider", groove)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hot)
	slider.add_theme_stylebox_override("focus", build_plaque_style("focus"))


## TabContainer: plaque tabs, the selected one lit, the page as an inset well.
static func style_menu_tabs(tabs: TabContainer) -> void:
	if tabs == null:
		return
	var tab := build_panel_style(Color(QuestPalette.CRYPT_STONE, 0.85), Color(QuestPalette.AGED_GOLD, 0.55), 1, 2)
	tab.content_margin_left = 16
	tab.content_margin_right = 16
	tab.content_margin_top = 6
	tab.content_margin_bottom = 6
	tab.border_width_bottom = 0
	var hover := tab.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.17, 0.14, 0.10, 0.94)
	hover.border_color = QuestPalette.RELIC_GOLD
	var selected := hover.duplicate() as StyleBoxFlat
	selected.border_width_top = 3
	selected.bg_color = Color(0.12, 0.10, 0.07, 0.98)
	tabs.add_theme_stylebox_override("tab_unselected", tab)
	tabs.add_theme_stylebox_override("tab_hovered", hover)
	tabs.add_theme_stylebox_override("tab_selected", selected)
	tabs.add_theme_stylebox_override("tab_focus", build_plaque_style("focus"))
	tabs.add_theme_stylebox_override("panel", build_inset_style(16))
	tabs.add_theme_color_override("font_unselected_color", Color(QuestPalette.PARCHMENT, 0.7))
	tabs.add_theme_color_override("font_hovered_color", QuestPalette.PARCHMENT_LIGHT)
	tabs.add_theme_color_override("font_selected_color", QuestPalette.RELIC_GOLD_PALE)
	tabs.add_theme_font_override("font", UI_FONT)


## Walks `root` and gives every field, slider, check and secondary button its menu
## style (the Opciones pages).
static func style_menu_controls(root: Node) -> void:
	for node in root.find_children("*", "", true, false):
		if node is OptionButton or node is LineEdit:
			style_menu_field(node)
		elif node is Slider:
			style_menu_slider(node)
		elif node is CheckButton or node is CheckBox:
			node.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
			node.add_theme_color_override("font_hover_color", QuestPalette.PARCHMENT_LIGHT)
			node.add_theme_color_override("font_pressed_color", QuestPalette.RELIC_GOLD_PALE)
			node.add_theme_color_override("font_focus_color", QuestPalette.PARCHMENT_LIGHT)
			node.add_theme_stylebox_override("focus", build_plaque_style("focus"))
		elif node is Button:  # secondary buttons inside a page (rebind, reset, open folder)
			style_menu_field(node)


## Godot dialogs (AcceptDialog / ConfirmationDialog) in the menu frame.
static func style_menu_dialog(dialog: AcceptDialog) -> void:
	if dialog == null:
		return
	dialog.add_theme_stylebox_override("panel", build_panel_style(QuestPalette.CRYPT_INK, QuestPalette.CRYPT_INK, 0, 0, 14))
	var frame := build_panel_style(QuestPalette.CRYPT_INK, QuestPalette.AGED_GOLD, 2, 2)
	frame.expand_margin_top = dialog.get_theme_constant("title_height") + 6  # the title bar sits in the border
	for side in ["expand_margin_left", "expand_margin_right", "expand_margin_bottom"]:
		frame.set(side, 6)
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 16
	dialog.add_theme_stylebox_override("embedded_border", frame)
	dialog.add_theme_stylebox_override("embedded_unfocused_border", frame)
	dialog.add_theme_color_override("title_color", QuestPalette.RELIC_GOLD_PALE)
	dialog.add_theme_font_override("title_font", TITLE_FONT)
	dialog.get_label().add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	for button: Button in dialog.get_ok_button().get_parent().find_children("*", "Button", false, false):
		style_menu_button(button)


# ---------------- HERO CARDS ----------------

## Hero tile states: "normal", "hot" (hover/focus), "picked", "taken" (another player's).
static func build_card_style(state: String) -> StyleBoxFlat:
	var s := build_panel_style(Color(QuestPalette.CRYPT_INK, 0.84), Color(QuestPalette.AGED_GOLD, 0.5), 1, 3)
	match state:
		"hot":
			s.bg_color = Color(0.10, 0.10, 0.09, 0.9)
			s.border_color = QuestPalette.RELIC_GOLD
			s.set_border_width_all(2)
			s.shadow_color = Color(QuestPalette.EMBER, 0.28)
			s.shadow_size = 12
		"picked":
			s.bg_color = Color(0.17, 0.13, 0.07, 0.92)
			s.border_color = QuestPalette.RELIC_GOLD_PALE
			s.set_border_width_all(3)
			s.shadow_color = Color(QuestPalette.RELIC_GOLD, 0.4)
			s.shadow_size = 16
		"taken":
			s.bg_color = Color(0.08, 0.03, 0.03, 0.8)
			s.border_color = QuestPalette.BANNER_RED
			s.set_border_width_all(2)
	return s

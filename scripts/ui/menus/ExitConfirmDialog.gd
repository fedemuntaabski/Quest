extends BaseSubPanel
class_name ExitConfirmDialog

signal confirmed
signal canceled

@export var confirm_text: String = "OK"
@export var cancel_text: String = "Cancelar"
@export var message_text: String = "¿Estás seguro de salir? Se perderán los datos de esta run actual."

@onready var dim_rect: ColorRect = %DimRect
@onready var dialog_panel: Panel = %DialogPanel
@onready var message_label: Label = %DialogMessage
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton


func _on_base_ready() -> void:
	pause_game_on_open = false
	visible = false
	animate_transitions = true
	entrance_trans = Tween.TRANS_BACK
	entrance_ease = Tween.EASE_OUT

	message_label.text = message_text
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text

	connect_button(confirm_button, _on_confirm_pressed)
	connect_button(cancel_button, _on_cancel_pressed)

	add_fade_target(dim_rect, 1.0)
	add_fade_target(dialog_panel, 1.0)
	add_scale_target(dialog_panel)

	_apply_theme()


func _on_before_open() -> void:
	confirm_button.grab_focus()


func _on_confirm_pressed() -> void:
	confirmed.emit()
	close()


func _on_cancel_pressed() -> void:
	canceled.emit()
	close()


func _apply_theme() -> void:
	if dialog_panel:
		dialog_panel.add_theme_stylebox_override("panel", ThemeManager.build_panel_style(QuestPalette.DUNGEON_CHARCOAL, QuestPalette.GOLD_DARK, 3, 20))
	if message_label:
		message_label.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	_style_button(cancel_button, false)
	_style_button(confirm_button, true)


func _style_button(button: Button, danger: bool = false) -> void:
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

	button.add_theme_stylebox_override("normal", ThemeManager.build_panel_style(QuestPalette.DUNGEON_MUD, border_base, 3, 16, 16))
	button.add_theme_stylebox_override("pressed", ThemeManager.build_panel_style(QuestPalette.DUNGEON_CHARCOAL, border_base, 3, 16, 16))
	button.add_theme_stylebox_override("hover", ThemeManager.build_panel_style(QuestPalette.DUNGEON_MUD, border_hover, 3, 16, 16))
	button.add_theme_stylebox_override("focus", ThemeManager.build_panel_style(QuestPalette.DUNGEON_MUD, QuestPalette.PARCHMENT_LIGHT, 4, 16, 16))

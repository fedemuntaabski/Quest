class_name CreditsPanel
extends Control

## CreditsPanel (progresion-10): full-screen credits over the main menu (button
## "CRÉDITOS"). Player-facing summary of docs/CREDITOS.md. Esc / Volver closes it.

signal closed

const TEXT := """[center][font_size=40][b][color=#f6d98c]QUEST[/color][/b][/font_size]
Un juego de Bazinga Studio

[font_size=26][b][color=#f6d98c]Arte[/color][/b][/font_size]
Tiny Dungeon — Kenney (kenney.nl), CC0
Tiny Creatures — Clint Bellanger, CC0
DungeonTileset II — 0x72, CC0
Efectos, armaduras, grimorios y Reliquia — arte propio
Ilustraciones de los menús — arte propio (generadas con ChatGPT)

[font_size=26][b][color=#f6d98c]Fuentes[/color][/b][/font_size]
Almendra SC — Ana Sanfelippo, SIL Open Font License 1.1
EB Garamond — Georg Duffner y The EB Garamond Project Authors, SIL Open Font License 1.1

[font_size=26][b][color=#f6d98c]Motor[/color][/b][/font_size]
Godot Engine — Juan Linietsky, Ariel Manzur y colaboradores, licencia MIT (godotengine.org/license)
GodotSteam — Gramps y colaboradores, licencia MIT

[font_size=26][b][color=#f6d98c]Gracias por jugar[/color][/b][/font_size][/center]"""

var _text: RichTextLabel


## menu-33: the crypt illustration, dimmed, behind a framed parchment column.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := MenuBackdrop.new()
	bg.name = "Backdrop"
	bg.texture = preload("res://assets/ui/menu_cripta.png")
	bg.tint = Color(0.01, 0.02, 0.03, 0.8)
	bg.gem = Vector3(0.712, 0.441, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(1100, 880)
	UiStyles.style_menu_frame(card, 40)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override("normal_font", UiStyles.UI_FONT)
	_text.add_theme_font_override("bold_font", UiStyles.TITLE_FONT)  # headers: Almendra SC
	_text.add_theme_font_size_override("normal_font_size", Accessibility.font(22))
	_text.add_theme_color_override("default_color", QuestPalette.PARCHMENT_LIGHT)
	_text.text = TEXT
	box.add_child(_text)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "VOLVER"
	back.custom_minimum_size = Vector2(260, 58)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyles.style_plaque_button(back, false, 26)
	back.pressed.connect(close)
	box.add_child(back)
	back.grab_focus.call_deferred()
	MenuTransitionFX.play_panel_in(self, card, 0.34)


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

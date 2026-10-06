class_name CreditsPanel
extends Control

## CreditsPanel (progresion-10): full-screen credits over the main menu (button
## "CRÉDITOS"). Player-facing summary of docs/CREDITOS.md, including the mandatory
## unTied Games attribution. Esc / Volver closes it.

signal closed

const TEXT := """[center][font_size=40][color=#f2c76b]QUEST[/color][/font_size]
Un juego de Bazinga Studio

[font_size=26][color=#f2c76b]Arte[/color][/font_size]
Tiny Dungeon — Kenney (kenney.nl), CC0
Tiny Creatures — Clint Bellanger, CC0
DungeonTileset II — 0x72, CC0
Super Pixel Effects Gigapack — Will Tice / unTied Games

[font_size=26][color=#f2c76b]Fuentes[/color][/font_size]
Almendra SC — Ana Sanfelippo, SIL Open Font License 1.1
EB Garamond — Georg Duffner y The EB Garamond Project Authors, SIL Open Font License 1.1

[font_size=26][color=#f2c76b]Motor[/color][/font_size]
Godot Engine — Juan Linietsky, Ariel Manzur y colaboradores, licencia MIT (godotengine.org/license)
GodotSteam — Gramps y colaboradores, licencia MIT

[font_size=26][color=#f2c76b]Gracias por jugar[/color][/font_size][/center]"""

var _text: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.02, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 160)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_color_override("default_color", QuestPalette.PARCHMENT_LIGHT)
	_text.text = TEXT
	box.add_child(_text)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Volver"
	back.custom_minimum_size = Vector2(220, 56)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(close)
	box.add_child(back)


func get_text() -> String:
	return _text.get_parsed_text() if _text else ""


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

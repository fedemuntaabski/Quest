extends Control
class_name IntroScreen

## IntroScreen (intro-tutorial-17): the premise, shown once per install before the
## first floor of a new run (Main._play_intro_if_due). The paragraphs fade in one
## after another; "Saltar" (or Esc/Enter/Space) ends it at any moment, and once
## everything is read the same button says "Comenzar".

signal finished

## SettingsManager first-time id (user://first_help.cfg, Opciones > Accesibilidad).
const HELP_ID := "intro"
const TITLE := "La abadía saqueada"
const PARAGRAPHS: Array[String] = [
	"Una noche sin luna, el señor demonio entró en la abadía de San Bricio y se llevó sus cinco reliquias.",
	"Las hundió en la mazmorra que hay bajo el claustro, una en cada piso, cada uno más hondo que el anterior.",
	"Bajá con tus héroes, encendé las salas oscuras y traé de vuelta cada reliquia antes de que la mazmorra despierte del todo.",
]
const PARAGRAPH_SEC := 2.2
const TITLE_FONT := preload("res://assets/fonts/mainfont.ttf")
const UI_FONT := preload("res://assets/fonts/secundaryfont.ttf")

var button: Button
var paragraphs: Array[Label] = []
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.02, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)
	var title := Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", Accessibility.font(52))
	title.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT)
	box.add_child(title)
	for text in PARAGRAPHS:
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", UI_FONT)
		label.add_theme_font_size_override("font_size", Accessibility.font(24))
		label.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
		label.modulate.a = 0.0
		box.add_child(label)
		paragraphs.append(label)
	button = Button.new()
	button.text = "Saltar"
	button.custom_minimum_size = Vector2(220, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", Accessibility.font(22))
	button.pressed.connect(skip)
	box.add_child(button)
	button.grab_focus.call_deferred()
	var tween := create_tween().set_ignore_time_scale()
	for label in paragraphs:
		tween.tween_property(label, "modulate:a", 1.0, PARAGRAPH_SEC * 0.4)
		tween.tween_interval(PARAGRAPH_SEC * 0.6)
	tween.tween_callback(func() -> void: button.text = "Comenzar")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		skip()


## Ends the intro (once).
func skip() -> void:
	if _done:
		return
	_done = true
	finished.emit()

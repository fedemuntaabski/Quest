extends PanelContainer
class_name HelpCard

## HelpCard: first-time help, in the left column under the objective. It has its
## own panel and queue, so the top hint card (rooms, invasions) never replaces one.
## HUDController.show_help() decides whether a help is due (SettingsManager).

const WIDTH := 340.0
const HOLD_SEC := 14.0
const FADE_SEC := 0.6
## id -> [title, text]. %s in "controles" = the current show_help key.
const HELP := {
	"controles": ["Cómo se juega", "Clic izquierdo: elegí un héroe o abrí una puerta de su sala.\nClic derecho: mové a los elegidos a otra sala.\n%s: todos los controles."],
	"sala_oscura": ["Sala oscura", "De las salas oscuras salen enemigos. Clic central sobre la sala para encenderla con Brasas: deja de generarlos y abre huecos para construir obras."],
	"heroe_caido": ["Héroe caído", "Para reanimarlo hace falta un aliado en su sala y Comida: clic en el cuerpo o en Reanimar. Si bajás de piso sin reanimarlo, se pierde. Si caen todos, termina la partida."],
}

var shown_id := ""
var _queue: Array[String] = []
var _title: Label
var _body: Label
var _tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	add_theme_stylebox_override("panel", UiStyles.build_panel_style(Color(0.08, 0.06, 0.04, 0.94), QuestPalette.GOLD_LIGHT, 2, 6, 10))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", Accessibility.font(18))
	_title.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT)
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(WIDTH - 24.0, 0)
	_body.add_theme_font_size_override("font_size", Accessibility.font(15))
	box.add_child(_body)


func enqueue(id: String) -> void:
	if not HELP.has(id):
		return
	_queue.append(id)
	if shown_id == "":
		_show_next()


func get_body_text() -> String:
	return _body.text


func queued() -> Array[String]:
	return _queue


func clear() -> void:
	_queue.clear()
	shown_id = ""
	if _tween:
		_tween.kill()
	hide()


func _show_next() -> void:
	shown_id = ""
	if _queue.is_empty():
		hide()
		return
	shown_id = _queue.pop_front()
	var entry: Array = HELP[shown_id]
	_title.text = entry[0]
	_body.text = entry[1] % InputBindings.label("show_help") if "%s" in entry[1] else entry[1]
	modulate.a = 1.0
	show()
	_tween = create_tween().set_ignore_time_scale()
	_tween.tween_interval(HOLD_SEC)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	_tween.tween_callback(_show_next)

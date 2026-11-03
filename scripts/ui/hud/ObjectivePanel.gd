extends PanelContainer
class_name ObjectivePanel

## ObjectivePanel: the floor's three steps, always on screen under "Piso N/M". It
## re-reads the world every frame (a few cheap checks), so every path that changes
## the state counts: host, client, reconnection, bosses dying.

const STEP_DONE := "✓"
const STEP_NOW := "▶"
const STEP_NEXT := "·"

var _labels: Array[Label] = []
var _last_lines: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiStyles.build_panel_style(Color(0.05, 0.05, 0.06, 0.8), QuestPalette.GOLD_DARK, 1, 6, 8))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var title := Label.new()
	title.text = "Objetivo"
	title.add_theme_font_size_override("font_size", Accessibility.font(16))
	title.add_theme_color_override("font_color", QuestPalette.GOLD)
	box.add_child(title)
	for i in 3:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", Accessibility.font(15))
		box.add_child(label)
		_labels.append(label)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


## 0 = find the exit, 1 = take the Reliquia, 2 = carry it to the exit.
func current_step() -> int:
	var extraction := ManagerLocator.get_extraction_manager()
	if extraction and extraction.current_phase == ExtractionManager.Phase.EXTRACTION:
		return 2
	var rooms := ManagerLocator.get_room_manager()
	return 1 if rooms and rooms.is_zone_revealed(rooms.get_exit_zone_id()) else 0


func step_texts() -> Array[String]:
	return ["Abrí puertas hasta encontrar la salida", "Recogé la Reliquia en la sala inicial", _carry_text()]


func get_lines() -> Array[String]:
	var lines: Array[String] = []
	var texts := step_texts()
	var step := current_step()
	for i in texts.size():
		lines.append("%s %s" % [STEP_DONE if i < step else (STEP_NOW if i == step else STEP_NEXT), texts[i]])
	return lines


func _carry_text() -> String:
	var relic := ManagerLocator.get_relic()
	if relic and relic.is_dropped():
		return "Recuperá la Reliquia caída"
	var enemies := ManagerLocator.get_enemy_manager()
	if enemies and enemies.is_boss_alive():
		return "Derrotá al jefe y llevá la Reliquia a la salida"
	return "Llevá la Reliquia a la salida"


func _refresh() -> void:
	var lines := get_lines()
	if lines == _last_lines:
		return
	_last_lines = lines
	var step := current_step()
	for i in _labels.size():
		_labels[i].text = lines[i]
		var color := QuestPalette.UI_TEXT_SECONDARY if i < step else (QuestPalette.GOLD_LIGHT if i == step else QuestPalette.PARCHMENT)
		_labels[i].add_theme_color_override("font_color", color)
	reset_size()

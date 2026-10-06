class_name RunSummary
extends VBoxContainer

## RunSummary (progresion-10): the end-of-run numbers on the death / final-victory
## overlays (GameSession.run_stats + SaveManager records). lines() is static so the
## tests read exactly what is shown.

const RECORD_LABELS := {
	"best_floor": "Piso más profundo",
	"fastest_victory_sec": "Victoria más rápida",
	"most_kills": "Más enemigos en una run",
}

var _labels: Array[Label] = []


## `stats`: GameSession.run_stats + "heroes_fallen" (names). `new_records`: keys of
## RECORD_LABELS beaten by this run. `records`: the slot's records for this difficulty.
func fill(stats: Dictionary, new_records: Array[String] = [], records: Dictionary = {}) -> void:
	for label in _labels:
		label.queue_free()
	_labels.clear()
	add_theme_constant_override("separation", 6)
	for line in lines(stats, new_records, records):
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		var is_record := line.begins_with("¡Nuevo récord")
		label.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT if is_record else QuestPalette.PARCHMENT_LIGHT)
		add_child(label)
		_labels.append(label)


static func lines(stats: Dictionary, new_records: Array[String] = [], records: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var difficulty := DifficultyConfig.get_default().get_level(str(stats.get("difficulty", "normal")))
	out.append("Dificultad: %s" % (difficulty.display_name if difficulty else "Normal"))
	out.append("Pisos: llegaste al %d, superaste %d" % [int(stats.get("floor_reached", 1)), int(stats.get("floors_cleared", 0))])
	out.append("Tiempo: %s" % format_time(float(stats.get("elapsed_sec", 0.0))))
	out.append("Enemigos derrotados: %d" % int(stats.get("kills", 0)))
	out.append("Objetos obtenidos: %d" % int(stats.get("items", 0)))
	var fallen: Array = stats.get("heroes_fallen", [])
	out.append("Héroes caídos: %s" % (", ".join(PackedStringArray(fallen)) if not fallen.is_empty() else "ninguno"))
	out.append("Registros nuevos del bestiario: %d" % int(stats.get("bestiary_new", 0)))
	if not records.is_empty():
		out.append("Récords del slot: %d victorias en %d runs, mejor piso %d" % [int(records.get("victories", 0)), int(records.get("runs", 0)), int(records.get("best_floor", 0))])
	for key in new_records:
		out.append("¡Nuevo récord! %s" % RECORD_LABELS.get(key, key))
	return out


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]

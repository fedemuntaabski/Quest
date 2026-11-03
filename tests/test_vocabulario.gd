extends SceneTree

## Session medieval-15: no player-visible text uses the old vocabulary. Scans what
## the player can read: text fields of .tres/.tscn and the string literals of
## scripts/ (log lines excepted, they are English diagnostics).
##   godot --headless --path . --script res://tests/test_vocabulario.gd

const OLD_WORDS := "Nexo|Industria|Ciencia|Polvo|M[oó]dulo|Generador|Torreta|Energ[ií]a|Energ[ií]z|Sobrecarga|Tanque|Cristal|N[uú]cleo|Engranaje|[Zz]umb|M[aá]quina"
## "run"/"slot" are ordinary code keys, so they only count inside a sentence.
const OLD_IN_PROSE := "\\b(run|slots?)\\b"
const TEXT_FIELD := "^\\s*(text|tooltip_text|title|placeholder_text|display_name|description|hint|banner_text|lore|role|passive_ability_\\w+|active_ability_\\w+) = \"(.*)\""
const SKIP_LINE := ["QuestLogger", "push_error", "push_warning", "printerr", "print("]

var failures: Array[String] = []
var _old: RegEx
var _prose: RegEx
var _field: RegEx
var _literal: RegEx


func _initialize() -> void:
	_old = RegEx.create_from_string("(?i)\\b(" + OLD_WORDS + ")")
	_prose = RegEx.create_from_string(OLD_IN_PROSE)
	_field = RegEx.create_from_string(TEXT_FIELD)
	_literal = RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	_check_detector()
	var scanned := 0
	for path in _files("res://resources") + _files("res://scenes") + _files("res://scripts"):
		scanned += 1
		_scan(path)
	_expect(scanned > 300, "scanned too few files (%d)" % scanned)
	_check_runtime_labels()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_vocabulario: %s (%d files, %d failures)" % ["OK" if failures.is_empty() else "FAILED", scanned, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## The scan itself must bite, or a green run proves nothing.
func _check_detector() -> void:
	_expect(_bad("Falta Industria"), "detector misses Industria")
	_expect(_bad("el módulo"), "detector misses módulo")
	_expect(_bad("Nueva run"), "detector misses run in a sentence")
	_expect(not _bad("res"), "detector flags a plain key")
	_expect(not _bad("anexo de la Reliquia"), "detector flags 'anexo'")
	_expect(not _bad("run"), "detector flags the bare 'run' key")


func _bad(text: String) -> bool:
	if _old.search(text) != null:
		return true
	return text.contains(" ") and _prose.search(text) != null


func _files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_files(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() in ["gd", "tres", "tscn"]:
			found.append(dir_path.path_join(file))
	return found


func _scan(path: String) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var is_script := path.ends_with(".gd")
	for i in lines.size():
		var line: String = lines[i]
		if is_script:
			_scan_script_line(path, i + 1, line)
		else:
			var field := _field.search(line)
			if field != null and _bad(field.get_string(2)):
				failures.append("%s:%d: %s" % [path, i + 1, line.strip_edges()])


func _scan_script_line(path: String, number: int, line: String) -> void:
	var code := line.strip_edges()
	if code.begins_with("#") or code.begins_with("@export_group"):
		return
	for skip in SKIP_LINE:
		if line.contains(skip):
			return
	for literal in _literal.search_all(line):
		var text := literal.get_string(1)
		if text.begins_with("res://") or text.begins_with("user://"):
			continue
		if _bad(text):
			failures.append("%s:%d: %s" % [path, number, text])


func _check_runtime_labels() -> void:
	var expected := {"iron": "Hierro", "food": "Comida", "lore": "Saber", "embers": "Brasas"}
	_expect(Building.RESOURCE_LABELS == expected, "building labels: %s" % str(Building.RESOURCE_LABELS))
	_expect(PrisonerCage.RESOURCE_NAMES == expected, "cage labels: %s" % str(PrisonerCage.RESOURCE_NAMES))
	_expect(ItemData.SLOT_LABELS[ItemData.Slot.TALISMAN] == "Talismán", "the equipment slot is the Talismán")

extends SceneTree

## assets/art nuevos: hojas en celdas de 16 px, índice de FX coherente con las
## hojas, filtro Nearest en el proyecto y .import lossless sin mipmaps (si existen).

const SHEETS := [
	"res://assets/art/armor/armours.png",
	"res://assets/art/weapons/weapons.png",
	"res://assets/art/items/chests.png",
	"res://assets/art/items/consumables.png",
	"res://assets/art/items/potions.png",
	"res://assets/art/items/books.png",
	"res://assets/art/items/cave_gems.png",
]
const IMPORT_DIRS := ["armor", "weapons", "items", "vfx"]

var _failures := 0


func _init() -> void:
	_check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "filtro por defecto = Nearest")
	for path: String in SHEETS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(img != null and img.get_width() % 16 == 0 and img.get_height() % 16 == 0, "%s en celdas de 16 px" % path)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/vfx/index.json"))
	_check(index.size() == 42, "42 FX en index.json (hay %d)" % index.size())
	for fx: String in index:
		var e: Dictionary = index[fx]
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/vfx/%s.png" % fx))
		var cols := int(e["columns"])
		var rows := ceili(float(e["frames"]) / cols)
		_check(img != null and cols * int(e["frame_w"]) <= img.get_width() and rows * int(e["frame_h"]) <= img.get_height() and int(e["frames"]) > 0, "FX %s: frames caben en la hoja" % fx)
	for dir: String in IMPORT_DIRS:
		_check_imports("res://assets/art/" + dir)
	QuestLogger.info(QuestLogger.Category.GENERAL, "test_assets_art: %d fallos" % _failures)
	quit(1 if _failures else 0)


func _check_imports(dir: String) -> void:
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".png.import"):
			continue
		var text := FileAccess.get_file_as_string(dir + "/" + file)
		_check("compress/mode=0" in text and "mipmaps/generate=false" in text, "%s lossless sin mipmaps" % file)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)

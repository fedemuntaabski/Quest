extends SceneTree

## assets/art nuevos: hojas en celdas de 16 px, índice de FX coherente con las
## hojas, filtro Nearest en el proyecto y .import lossless sin mipmaps (si existen).

const SHEETS := [
	"res://assets/art/own/items.png",
	"res://assets/art/tiles/kenney_tiny_dungeon_packed.png",
]
const VFX_DIR := "res://assets/art/own/vfx/"
const IMPORT_DIRS := ["items", "own", "own/vfx"]

var _failures := 0


func _init() -> void:
	_check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "filtro por defecto = Nearest")
	for path: String in SHEETS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(img != null and img.get_width() % 16 == 0 and img.get_height() % 16 == 0, "%s en celdas de 16 px" % path)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VFX_DIR + "index.json"))
	var config: VfxConfig = load("res://resources/vfx/vfx_config.tres")
	for key in config.effects:
		var sheet := String(config.effects[key].get("sheet", ""))
		_check(sheet == "" or index.has(sheet), "vfx_config %s: hoja '%s' está en index.json" % [key, sheet])
	for fx: String in index:
		var e: Dictionary = index[fx]
		var img := Image.load_from_file(ProjectSettings.globalize_path(VFX_DIR + "%s.png" % fx))
		var cols := int(e["columns"])
		var rows := ceili(float(e["frames"]) / cols)
		_check(img != null and cols * int(e["frame_w"]) <= img.get_width() and rows * int(e["frame_h"]) <= img.get_height() and int(e["frames"]) > 0, "FX %s: frames caben en la hoja" % fx)
	var doc := FileAccess.get_file_as_string("res://docs/MISSING_ICONS.md")
	var listed := 0
	for line in doc.split("\n"):
		if line.begins_with("| `") and not "placeholder_" in line:
			var icon_name := line.get_slice("`", 1)
			var path := "res://assets/art/ui/placeholder_%s.png" % icon_name
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			listed += 1 if img != null else 0
			if img != null:
				_check(img.get_size() == Vector2i(16, 16), "placeholder_%s es 16x16" % icon_name)
	_check(listed == 29, "MISSING_ICONS.md lista 29 placeholders existentes (hay %d)" % listed)
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

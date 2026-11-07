extends SceneTree

## Licencias: toda referencia res:// a un archivo de arte, fuente o audio en
## scenes/, resources/, scripts/ y project.godot tiene que caer bajo una regla de
## la tabla "Licencias permitidas" de docs/CREDITOS.md (entre los marcadores
## licencias:inicio / licencias:fin). Una ruta que no existe (audio aún no
## agregado) no se distribuye y se ignora; una ruta con %s se valida por su prefijo.

const DOC := "res://docs/CREDITOS.md"
const ROOTS := ["res://scenes", "res://resources", "res://scripts"]
const CODE_EXT := ["gd", "tscn", "tres", "gdshader"]
const MEDIA := "png|jpg|jpeg|webp|svg|ttf|otf|woff2?|ogg|wav|mp3"
## Nunca pueden estar permitidos (licencia desconocida o sin permiso para el repo público).
const BANNED := ["res://assets/art/_rejected/", "res://assets/art/_source/items_sheets/",
	"res://assets/art/_source/super_pixel_effects/", "res://assets/art/_source/raven_fantasy_icons/"]

var _failures := 0
var _rules: Array[String] = []


func _init() -> void:
	_load_rules()
	_check(_rules.size() >= 10, "la tabla de licencias tiene reglas (hay %d)" % _rules.size())
	for rule in _rules:
		for banned: String in BANNED:
			_check(not rule.begins_with(banned) and not banned.begins_with(rule), "regla %s no habilita %s" % [rule, banned])
	_check(_allowed("res://assets/art/own/items.png"), "control: arte propio permitido")
	_check(not _allowed("res://assets/art/_rejected/licencia/items/cave_gems.png"), "control: cave_gems rechazada")

	var refs := {}  # path -> archivo que la nombra
	var files: Array[String] = ["res://project.godot"]
	for root: String in ROOTS:
		_collect(root, files)
	var re := RegEx.create_from_string("res://[^\"'\\n]+?\\.(%s)\\b|res://assets/[^\"'\\n]+?\\.json\\b" % MEDIA)
	var uid_re := RegEx.create_from_string("uid://[a-z0-9]+")
	for file in files:
		var text := FileAccess.get_file_as_string(file)
		for m in re.search_all(text):
			refs[m.get_string()] = file
		if file == "res://project.godot":  # ícono y splash van solo por uid
			for m in uid_re.search_all(text):
				var id := ResourceUID.text_to_id(m.get_string())
				if ResourceUID.has_id(id):
					refs[ResourceUID.get_id_path(id)] = file
	_check(refs.size() > 50, "se encontraron referencias (hay %d)" % refs.size())

	var checked := 0
	for path: String in refs:
		var dynamic := path.contains("%")
		var key := path.get_slice("%", 0) if dynamic else path
		if not dynamic and not FileAccess.file_exists(path):
			continue
		checked += 1
		_check(_allowed(key), "%s (en %s) no tiene licencia conocida en docs/CREDITOS.md" % [path, refs[path]])
	print("test_licencias: %d referencias, %d verificadas, %d fallos" % [refs.size(), checked, _failures])
	quit(1 if _failures else 0)


func _load_rules() -> void:
	var inside := false
	for line in FileAccess.get_file_as_string(DOC).split("\n"):
		if "licencias:inicio" in line:
			inside = true
		elif "licencias:fin" in line:
			inside = false
		elif inside and line.begins_with("| `res://"):
			_rules.append(line.get_slice("`", 1))


func _allowed(path: String) -> bool:
	for rule in _rules:
		if path == rule or (rule.ends_with("/") and path.begins_with(rule)):
			return true
	return false


func _collect(dir: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + sub, out)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in CODE_EXT:
			out.append(dir + "/" + f)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)

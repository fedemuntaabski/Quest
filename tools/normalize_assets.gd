extends SceneTree

## Copia los packs de assets/art/_source a su carpeta final, aplica el filtro de
## estética y escribe assets/art/vfx/index.json. Reproducible, idempotente:
##   godot --headless --path . --script res://tools/normalize_assets.gd
## Reglas de tamaño: ítems/íconos = celdas de 16x16 (sin reescalar: los packs ya
## vienen a 16 px). FX: ninguna hoja `small` baja a 16 px por factor entero exacto
## (probado: 0/96), así que se conservan nativas y se dibujan con ART_SCALE como
## todo el arte (1 px de FX = 1 px de arte). Ver docs/ASSETS.md "Tamaños finales".

const SRC := "res://assets/art/_source/"
const ART := "res://assets/art/"
const SHEETS := SRC + "items_sheets/"
const FX := SRC + "super_pixel_effects/"
const CELL := 16

## hoja -> carpeta destino (todas en celdas de 16x16).
const ITEM_SHEETS := {
	"armours.png": "armor/armours.png",
	"weapons.png": "weapons/weapons.png",
	"chests.png": "items/chests.png",
	"consumables.png": "items/consumables.png",
	"potions.png": "items/potions.png",
	"books.png": "items/books.png",
}
## La hoja de cueva mide 99 px de ancho; las 3 últimas columnas están vacías.
const CAVE := "pixelquest16-july-2025-cave.png"

## Categorías FX conservadas (medieval/oscuro) y animaciones rechazadas dentro de ellas.
const FX_KEEP := ["Fantasy Spells", "Magic Bursts", "Impacts", "Lightning", "Smoke Bursts", "Explosions", "Symbols"]
const FX_REJECT_PREFIX := {
	"Explosions": ["stylized_"],
	"Magic Bursts": ["directional_bubble", "directional_music", "round_firework", "round_heart"],
	"Symbols": ["symbol_alert_text", "symbol_bonus", "symbol_complete", "symbol_cool", "symbol_crown", "symbol_failure", "symbol_game_over", "symbol_level_up", "symbol_lightbulb", "symbol_place_", "symbol_rank_", "symbol_success", "symbol_thumbs", "symbol_wow", "symbol_you_"],
}
const FX_REJECT_CATEGORIES := ["Sci-fi", "Splatters"]

var _sizes := {}  # "Epic Explosion 001 Small (Explosions/epic_explosion_001)" -> Vector2i


func _init() -> void:
	_items()
	_fx()
	quit()


func _items() -> void:
	for sheet: String in ITEM_SHEETS:
		_copy(SHEETS + sheet, ART + ITEM_SHEETS[sheet])
	var cave := Image.load_from_file(ProjectSettings.globalize_path(SHEETS + CAVE))
	cave.convert(Image.FORMAT_RGBA8)
	var cropped := cave.get_region(Rect2i(0, 0, int(cave.get_width() / CELL) * CELL, int(cave.get_height() / CELL) * CELL))
	_ensure_dir(ART + "items/")
	cropped.save_png(ProjectSettings.globalize_path(ART + "items/cave_gems.png"))
	print("cave_gems %s" % cropped.get_size())


func _fx() -> void:
	_parse_asset_list()
	var index := {}
	var rejected := 0
	for category in _dirs(FX + "spritesheet/"):
		for anim in _dirs(FX + "spritesheet/%s/" % category):
			var keep := _keep_fx(category, anim)
			for variant in _dirs(FX + "spritesheet/%s/%s/" % [category, anim]):
				if not "_small_" in variant:
					continue
				var from := FX + "spritesheet/%s/%s/%s/spritesheet.png" % [category, anim, variant]
				var color: String = variant.get_slice("_small_", 1)
				var file := "%s_%s.png" % [anim, color]
				if not keep:
					_copy(from, ART + "_rejected/vfx/" + file)
					rejected += 1
					continue
				_copy(from, ART + "vfx/" + file)
				var frame: Vector2i = _sizes.get("%s/%s" % [category, anim], Vector2i.ZERO)
				var tex := Image.load_from_file(ProjectSettings.globalize_path(from))
				var frames := int(tex.get_width() / max(frame.x, 1))
				index[file.get_basename()] = {"category": category, "frame_w": frame.x, "frame_h": frame.y, "frames": frames, "fps": 15}
	var f := FileAccess.open(ART + "vfx/index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "\t", true))
	print("vfx kept=%d rejected=%d" % [index.size(), rejected])


func _keep_fx(category: String, anim: String) -> bool:
	if category in FX_REJECT_CATEGORIES or not category in FX_KEEP:
		return false
	for prefix: String in FX_REJECT_PREFIX.get(category, []):
		if anim.begins_with(prefix):
			return false
	return true


## asset_list.txt: "[Free] Epic Explosion 001 Small (Explosions/epic_explosion_001): 64x64"
func _parse_asset_list() -> void:
	var re := RegEx.create_from_string("Small \\(([^)]+)\\): (\\d+)x(\\d+)")
	for line in FileAccess.get_file_as_string(FX + "asset_list.txt").split("\n"):
		var m := re.search(line)
		if m:
			_sizes[m.get_string(1)] = Vector2i(int(m.get_string(2)), int(m.get_string(3)))


func _dirs(path: String) -> PackedStringArray:
	var d := DirAccess.get_directories_at(path)
	d.sort()
	return d


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _copy(from: String, to: String) -> void:
	_ensure_dir(to.get_base_dir() + "/")
	DirAccess.copy_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))

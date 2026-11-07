extends SceneTree

## Arte propio del proyecto (sin licencias de terceros salvo Kenney CC0 teñido).
## Reemplaza las hojas de ítems de licencia desconocida, la gema de cave_gems y
## los efectos de unTied Games (sesión licencias-20, docs/CREDITOS.md).
##   godot --headless --path . --script res://tools/build_own_art.gd
## Escribe:
##   assets/art/own/items.png   celdas 16x16: OWN_CELLS en ese orden (fila única)
##   assets/art/own/vfx/*.png   tiras horizontales + index.json (formato de VfxEffect)
## Idempotente; después correr tools/build_items.gd si cambió el orden de celdas.
## Un PNG con su .ase en own/src/ (retoque a mano, tools/libresprite.sh) no se regenera.

const OUT := "res://assets/art/own/"
const KENNEY := "res://assets/art/_source/kenney_tinyDungeon/Tilemap/tilemap_packed.png"
const CELL := 16
const FPS := 15

## Orden de celdas en items.png (build_items.gd y Pickup.gd usan el índice).
const OWN_CELLS := ["armor_leather", "armor_robe", "armor_iron", "armor_copper", "armor_steel",
	"armor_gold", "armor_jade", "book_embers", "book_tides", "relic_gem", "sword_jade", "sword_gold"]

## Re-color de tiles de Kenney: armaduras = escudo (101 madera, 102 metal); espadas
## de jade y oro = espadas 105/106. [tile, oscuro, claro].
const ARMOR := {
	"armor_leather": [101, Color("4a2a17"), Color("c08850")],
	"armor_robe": [101, Color("2a1840"), Color("9a70d0")],
	"armor_iron": [102, Color("2c2f36"), Color("a8adb5")],
	"armor_copper": [102, Color("3a2a14"), Color("6fbf8a")],
	"armor_steel": [102, Color("26324a"), Color("d6e2f0")],
	"armor_gold": [102, Color("4a3008"), Color("ffe070")],
	"armor_jade": [102, Color("0e3a24"), Color("7ff0b0")],
	"sword_jade": [105, Color("0e3a24"), Color("9affc8")],
	"sword_gold": [106, Color("4a3008"), Color("fff0a0")],
}

const GEM := [
	"................",
	"................",
	"................",
	"....oooooooo....",
	"...owllllmmmo...",
	"..owwlllmmmmdo..",
	".owwwlllmmmmddo.",
	".olmmmmmmmmdddo.",
	"..olmmmmmmdddo..",
	"...olmmmmmddo...",
	"....olmmmmdo....",
	".....olmmdo.....",
	"......omdo......",
	".......oo.......",
	"................",
	"................",
]
const GEM_PAL := {"o": "2a0a12", "d": "6e0f1e", "m": "b3202f", "l": "e0505a", "w": "ffd8d8"}

const BOOK := [
	"................",
	"................",
	"..oooooooooooo..",
	"..ocmmmmmmmmmo..",
	"..ocmmmmmmmmmo..",
	"..ocmmmmymmmmo..",
	"..ocmmmyyymmmo..",
	"..ocmmyyyyymmo..",
	"..ocmmmyyymmmo..",
	"..ocmmmmymmmmo..",
	"..ocmmmmmmmmmo..",
	"..ocmmmmmmmmmo..",
	"..ocpppppppppo..",
	"..oooooooooooo..",
	"................",
	"................",
]
const BOOK_PAL := {
	"book_embers": {"o": "1b1420", "c": "5a1010", "m": "a8321e", "y": "ffc040", "p": "e8dcb5"},
	"book_tides": {"o": "1b1420", "c": "102a5a", "m": "2a5ea8", "y": "a8f0ff", "p": "e8dcb5"},
}

var _rng := RandomNumberGenerator.new()
var _old_index: Dictionary = {}


func _init() -> void:
	_rng.seed = 20
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "vfx/"))
	_items()
	_vfx()
	quit()


func _items() -> void:
	if FileAccess.file_exists(OUT + "src/items.ase"):
		print("own items: hay src/items.ase (retoque de LibreSprite), no se pisa")
		return
	var sheet := Image.create(CELL * OWN_CELLS.size(), CELL, false, Image.FORMAT_RGBA8)
	var kenney := Image.load_from_file(ProjectSettings.globalize_path(KENNEY))
	kenney.convert(Image.FORMAT_RGBA8)
	for i in OWN_CELLS.size():
		var id: String = OWN_CELLS[i]
		var cell: Image
		if ARMOR.has(id):
			cell = _recolor(kenney, ARMOR[id][0], ARMOR[id][1], ARMOR[id][2])
		elif BOOK_PAL.has(id):
			cell = _ascii(BOOK, BOOK_PAL[id])
		else:
			cell = _ascii(GEM, GEM_PAL)
		sheet.blit_rect(cell, Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, 0))
	sheet.save_png(ProjectSettings.globalize_path(OUT + "items.png"))
	print("own items: %d celdas" % OWN_CELLS.size())


## Mapa de gradiente: luminancia del tile Kenney → oscuro..claro; el contorno casi negro queda.
func _recolor(src: Image, tile: int, dark: Color, light: Color) -> Image:
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	var ox := (tile % 12) * CELL
	var oy := (tile / 12) * CELL
	for y in CELL:
		for x in CELL:
			var c := src.get_pixel(ox + x, oy + y)
			if c.a < 0.5:
				continue
			var lum := c.get_luminance()
			img.set_pixel(x, y, c if lum < 0.12 else dark.lerp(light, clampf((lum - 0.12) / 0.75, 0.0, 1.0)))
	return img


func _ascii(rows: Array, pal: Dictionary) -> Image:
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if pal.has(row[x]):
				img.set_pixel(x, y, Color(pal[row[x]]))
	return img


# --- VFX: tiras horizontales, frames de `size` px, dibujadas a mano por fórmula ---

func _vfx() -> void:
	if FileAccess.file_exists(OUT + "vfx/index.json"):
		_old_index = JSON.parse_string(FileAccess.get_file_as_string(OUT + "vfx/index.json"))
	var index := {}
	index["own_slash"] = _strip("own_slash", 32, 6, _slash)
	index["own_sparks_yellow"] = _strip("own_sparks_yellow", 32, 6, _sparks.bind(Color("ffe060")))
	index["own_smoke_brown"] = _strip("own_smoke_brown", 32, 8, _smoke.bind(Color("8a7058")))
	index["own_sparkle_green"] = _strip("own_sparkle_green", 32, 8, _sparkle.bind(Color("70ff90")))
	index["own_ring_red"] = _strip("own_ring_red", 40, 8, _ring.bind(Color("ff5040")))
	index["own_ring_blue"] = _strip("own_ring_blue", 40, 8, _ring.bind(Color("60a8ff")))
	index["own_ring_violet"] = _strip("own_ring_violet", 40, 8, _ring.bind(Color("c080ff")))
	index["own_ring_green"] = _strip("own_ring_green", 40, 8, _ring.bind(Color("80ff70")))
	var f := FileAccess.open(OUT + "vfx/index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "\t", true))
	print("own vfx: %d hojas" % index.size())


func _strip(sheet: String, size: int, frames: int, draw: Callable) -> Dictionary:
	if FileAccess.file_exists(OUT + "src/vfx/%s.ase" % sheet) and _old_index.has(sheet):
		return _old_index[sheet]  # retocada en LibreSprite (tools/libresprite.sh): no se pisa
	var img := Image.create(size * frames, size, false, Image.FORMAT_RGBA8)
	_rng.seed = hash(sheet)
	var seeds := []
	for i in 12:
		seeds.append(Vector2(_rng.randf(), _rng.randf()))
	for i in frames:
		draw.call(img, Vector2(i * size, 0), size, float(i) / float(frames - 1), seeds)
	img.save_png(ProjectSettings.globalize_path(OUT + "vfx/%s.png" % sheet))
	return {"frame_w": size, "frame_h": size, "frames": frames, "columns": frames, "fps": FPS}


func _px(img: Image, o: Vector2, size: int, p: Vector2, c: Color) -> void:
	var q := Vector2i(p.round())
	if q.x < 0 or q.y < 0 or q.x >= size or q.y >= size:
		return
	var at := Vector2i(o) + q
	img.set_pixelv(at, img.get_pixelv(at).blend(c))


## Tajo blanco hacia +x (VfxEffect rota y tiñe): arco que barre −70°..70° y se apaga.
func _slash(img: Image, o: Vector2, size: int, t: float, _s: Array) -> void:
	var center := Vector2(size * 0.3, size * 0.5)
	var head := lerpf(-70.0, 70.0, minf(t * 1.6, 1.0))
	var fade := 1.0 - maxf(t - 0.5, 0.0) * 2.0
	for step in 60:
		var a := lerpf(-70.0, head, float(step) / 59.0)
		var tail := float(step) / 59.0
		for r in [11.0, 12.0, 13.0]:
			var w := (1.0 if r == 12.0 else 0.55) * tail * fade
			_px(img, o, size, center + Vector2.from_angle(deg_to_rad(a)) * r, Color(1, 1, 1, w))


## Chispas: puntos que salen del centro en 10 rayos y se apagan.
func _sparks(img: Image, o: Vector2, size: int, t: float, seeds: Array, color: Color) -> void:
	var c := Vector2(size, size) * 0.5
	for i in 10:
		var dir := Vector2.from_angle(TAU * (i + seeds[i].x * 0.5) / 10.0)
		var d: float = (3.0 + seeds[i].y * 3.0) + t * 10.0
		var col := color.lerp(Color.WHITE, 1.0 - t)
		col.a = 1.0 - t * 0.85
		_px(img, o, size, c + dir * d, col)
		_px(img, o, size, c + dir * (d - 1.0), Color(col, col.a * 0.6))


## Humo: 6 bocanadas que crecen, suben un poco y se desvanecen.
func _smoke(img: Image, o: Vector2, size: int, t: float, seeds: Array, color: Color) -> void:
	var c := Vector2(size, size) * 0.5
	for i in 6:
		var dir := Vector2.from_angle(TAU * i / 6.0 + seeds[i].x)
		var pos := c + dir * (2.0 + t * 7.0) + Vector2(0, -t * 4.0)
		var r: float = 2.0 + t * 3.5 + seeds[i].y
		_disc(img, o, size, pos, r, Color(color.lerp(Color("c8c0b0"), t), 0.85 * (1.0 - t)))


## Destellos en cruz que suben (curación).
func _sparkle(img: Image, o: Vector2, size: int, t: float, seeds: Array, color: Color) -> void:
	for i in 7:
		var phase := fmod(t + seeds[i].y, 1.0)
		var pos := Vector2(5.0 + seeds[i].x * (size - 10.0), size - 4.0 - phase * (size - 10.0))
		var a := sin(phase * PI)
		var col := Color(color.lerp(Color.WHITE, 0.4), a)
		_px(img, o, size, pos, Color(1, 1, 1, a))
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_px(img, o, size, pos + d, col)


## Anillo que se expande + chispas que suben (buffs, nivel).
func _ring(img: Image, o: Vector2, size: int, t: float, seeds: Array, color: Color) -> void:
	var c := Vector2(size, size) * 0.5
	var r := 4.0 + t * (size * 0.4)
	var a := 1.0 - t
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c)
			if absf(d - r) < 1.0:
				_px(img, o, size, Vector2(x, y), Color(color.lerp(Color.WHITE, a * 0.5), a))
	for i in 6:
		var pos := c + Vector2((seeds[i].x - 0.5) * size * 0.6, 6.0 - t * 14.0 - seeds[i].y * 4.0)
		_px(img, o, size, pos, Color(color, a))
		_px(img, o, size, pos + Vector2.DOWN, Color(color, a * 0.5))


func _disc(img: Image, o: Vector2, size: int, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if Vector2(x, y).distance_to(c) <= r:
				_px(img, o, size, Vector2(x, y), col)

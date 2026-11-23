extends SceneTree

## Arte propio del proyecto (sin licencias de terceros salvo Kenney CC0 teñido).
## Reemplaza las hojas de ítems de licencia desconocida, la gema de cave_gems y
## los efectos de unTied Games (sesión licencias-20, docs/CREDITOS.md).
##   godot --headless --path . --script res://tools/build_own_art.gd
## Escribe:
##   assets/art/own/items.png   celdas 16x16: OWN_CELLS en ese orden (fila única)
##   assets/art/own/vfx/*.png   tiras horizontales + index.json (formato de VfxEffect)
##   assets/art/own/abilities/ability_<id>.png  íconos de habilidades 16x16 (juego-36)
##   assets/art/own/dungeon_decor.png  interior de las salas (mazmorra-31): OWN_DECOR, fila única
## Idempotente; después correr tools/build_items.gd si cambió el orden de celdas.
## Un PNG con su .ase en own/src/ (retoque a mano, tools/libresprite.sh) no se regenera.

const OUT := "res://assets/art/own/"
const KENNEY := "res://assets/art/tiles/kenney_tiny_dungeon_packed.png"
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
	_decor()
	_abilities()
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


func _ascii(rows: Array, pal: Dictionary, size := Vector2i(CELL, CELL)) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	_stamp(img, rows, pal, Vector2i.ZERO)
	return img


## Draws ASCII rows at `at` (characters not in `pal` stay as they are).
func _stamp(img: Image, rows: Array, pal: Dictionary, at: Vector2i) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var p := at + Vector2i(x, y)
			if pal.has(row[x]) and p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixel(p.x, p.y, Color(pal[row[x]]))


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
	# juego-21: sala encendida, Reliquia, aparición de enemigos.
	index["own_flame_gold"] = _strip("own_flame_gold", 40, 8, _flame.bind(Color("ffb030")))
	index["own_ring_gold"] = _strip("own_ring_gold", 40, 8, _ring.bind(Color("ffd860")))
	index["own_portal_red"] = _strip("own_portal_red", 40, 8, _portal.bind(Color("d02828")))
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


## Encendido: lenguas de fuego que nacen abajo, suben y se apagan + brasas sueltas.
func _flame(img: Image, o: Vector2, size: int, t: float, seeds: Array, color: Color) -> void:
	var base := Vector2(size * 0.5, size - 5.0)
	var grow := minf(t * 3.0, 1.0) * clampf(1.0 - (t - 0.6) / 0.4, 0.0, 1.0)
	_disc(img, o, size, base, 6.0 * grow, Color(color, 0.35 * grow))  # brillo en la base
	for i in 5:
		var x: float = base.x + (float(i) - 2.0) * 4.0 + (seeds[i].x - 0.5) * 2.0
		var h: float = (10.0 + seeds[i].y * 10.0) * grow * (1.0 - absf(float(i) - 2.0) * 0.2)
		for k in int(h):
			var f := float(k) / maxf(h, 1.0)
			var sway := sin(t * TAU * 1.5 + seeds[i].x * 6.0 + f * 3.0) * f * 1.5
			var col := Color("fff4c0").lerp(color, minf(f * 2.0, 1.0)).lerp(Color("d03010"), maxf(f - 0.5, 0.0) * 2.0)
			var half := int(round((1.0 - f) * 1.5))
			for w in range(-half, half + 1):
				_px(img, o, size, Vector2(x + sway + w, base.y - k), Color(col, 1.0 if w == 0 else 0.7))
	for i in 8:
		var phase := fmod(t * 1.3 + seeds[i + 4].y, 1.0)
		var pos := Vector2(6.0 + seeds[i + 4].x * (size - 12.0), base.y - 4.0 - phase * (size - 12.0))
		_px(img, o, size, pos, Color(Color("ffd060"), sin(phase * PI) * (1.0 - t * 0.5)))


## Aparición: anillo que se cierra hacia el centro con rayos oscuros y un destello final.
func _portal(img: Image, o: Vector2, size: int, t: float, seeds: Array, color: Color) -> void:
	var c := Vector2(size, size) * 0.5
	var r := (size * 0.45) * (1.0 - t * 0.85)
	var a := minf(t * 3.0, 1.0) * (1.0 - maxf(t - 0.75, 0.0) * 4.0)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c)
			if absf(d - r) < 1.0:
				_px(img, o, size, Vector2(x, y), Color(color, a))
			elif d < r and fmod(d + t * 8.0, 4.0) < 1.0:
				_px(img, o, size, Vector2(x, y), Color(Color("400810"), a * 0.6))
	for i in 8:
		var dir := Vector2.from_angle(TAU * (i + seeds[i].x * 0.3) / 8.0)
		for k in 3:
			_px(img, o, size, c + dir * (r + 2.0 + k), Color(color.lerp(Color.BLACK, 0.3), a * (1.0 - k / 3.0)))
	if t > 0.7:
		_disc(img, o, size, c, 3.0 * (1.0 - t) / 0.3 + 0.5, Color(Color("ff8060"), (1.0 - t) / 0.3))


func _disc(img: Image, o: Vector2, size: int, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if Vector2(x, y).distance_to(c) <= r:
				_px(img, o, size, Vector2(x, y), col)


# --- Interior de las salas (mazmorra-31): paleta de 0x72 DungeonTileset II ---

## Orden de celdas de dungeon_decor.png = DungeonTiles.PIT/RUG/SLABS/RUBBLE.
## mazmorra-32: + animated torch/brazier/candles (4 frames each, side by side = TileSet
## animation), wall pieces (shelves, chains), flat scatter and type props; rows 1-2 hold the
## Altar (32x32, active + used) at DungeonTiles.ALTAR_REGION / ALTAR_USED_REGION (a Sprite2D, not a tile).
const OWN_DECOR := ["pit_tl", "pit_tr", "pit_bl", "pit_br",
	"rug_tl", "rug_t", "rug_tr", "rug_l", "rug_c", "rug_r", "rug_bl", "rug_b", "rug_br",
	"slab_a", "slab_b", "rubble_a", "rubble_b", "rubble_c",
	"torch_0", "torch_1", "torch_2", "torch_3", "brazier_0", "brazier_1", "brazier_2", "brazier_3",
	"candles_0", "candles_1", "candles_2", "candles_3", "shelf_a", "shelf_b", "chains", "shackles",
	"bones_a", "bones_b", "cobweb_l", "cobweb_r", "crack_a", "crack_b", "puddle", "blood_a", "blood_b",
	"moss_a", "moss_b", "bedroll_l", "bedroll_r"]
const DECOR_ROWS := 3
const SHEET_0X72 := "res://assets/art/tiles/dungeon_tileset_ii.png"
const FLOOR_1 := Vector2i(16, 64)  # floor_1 en la hoja 0x72 (px)
const P_K := Color("222222")  # contorno
const P_D := Color("21141b")  # sombra profunda
const P_F := Color("483b3a")  # suelo
const P_M := Color("775c55")  # junta / piedra media
const P_L := Color("aa8d7a")  # piedra clara
const P_W := Color("d3bfa9")  # hueso
const P_R := Color("6f3343")  # carmesí de los estandartes 9f294e, 55 % hacia el suelo 483b3a (mazmorra-32)
const P_O := Color("943b40")  # borde: rojo da4e38/9f294e, 35 % hacia el suelo (mazmorra-32)
const P_RD := Color("4a1a2a")
const RUBBLE := {
	"rubble_a": [
		"................", "................", "................", "................",
		"................", "......kkk.......", ".....kllmk......", "....kllmmmk.....",
		"....kmmmmdk..kk.", ".....kkddk..klmk", "...........kmmdk", "..kk........kkk.",
		".klmk...........", ".kmdk...........", "..kk............", "................"],
	"rubble_b": [
		"................", "................", "..........kk....", ".........klmk...",
		".........kmdk...", "..........kk....", "................", "...kkkk.........",
		"..kllmmk........", ".kllmmmmk.......", ".kmmmmmdk...kk..", "..kmmddk...klk..",
		"...kkkk....kdk..", "............k...", "................", "................"],
	"rubble_c": [
		"................", "..k.............", ".kl.......k.....", "..k......klk....",
		".........kk.....", "....k...........", "...kmk......k...", "....k......kmk..",
		"............k...", "......kkk.......", ".....klmmk......", ".....kmmdk......",
		"......kkk...k...", "...........kl...", "................", "................"],
}


func _decor() -> void:
	if FileAccess.file_exists(OUT + "src/dungeon_decor.ase"):
		print("own decor: hay src/dungeon_decor.ase (retoque de LibreSprite), no se pisa")
		return
	var sheet := Image.create(CELL * OWN_DECOR.size(), CELL * DECOR_ROWS, false, Image.FORMAT_RGBA8)
	var src := Image.load_from_file(ProjectSettings.globalize_path(SHEET_0X72))
	src.convert(Image.FORMAT_RGBA8)
	var pit := _pit(src)
	var pal := {"k": P_K.to_html(false), "l": P_W.to_html(false), "m": P_L.to_html(false), "d": P_M.to_html(false)}
	for i in OWN_DECOR.size():
		var id: String = OWN_DECOR[i]
		var cell: Image
		if id.begins_with("pit_"):
			var q := ["pit_tl", "pit_tr", "pit_bl", "pit_br"].find(id)
			cell = pit.get_region(Rect2i((q % 2) * CELL, (q / 2) * CELL, CELL, CELL))
		elif id.begins_with("rug_"):
			cell = _rug(id)
		elif id.begins_with("slab_"):
			cell = _slab(id == "slab_b")
		elif RUBBLE.has(id):
			cell = _ascii(RUBBLE[id], pal)
		else:
			cell = _decor_cell(id)
		sheet.blit_rect(cell, Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, 0))
	sheet.blit_rect(_altar(false), Rect2i(0, 0, CELL * 2, CELL * 2), Vector2i(0, CELL))
	sheet.blit_rect(_altar(true), Rect2i(0, 0, CELL * 2, CELL * 2), Vector2i(CELL * 2, CELL))
	sheet.save_png(ProjectSettings.globalize_path(OUT + "dungeon_decor.png"))
	print("own decor: %d celdas" % OWN_DECOR.size())


## Pozo de 1 celda (32x32 = 2x2 tiles): suelo 0x72 en las esquinas, boca redondeada con
## contorno, pared del fondo en ladrillo (arriba) y negro que se hunde hacia abajo.
func _pit(src: Image) -> Image:
	var img := Image.create(CELL * 2, CELL * 2, false, Image.FORMAT_RGBA8)
	var inside := func(x: int, y: int) -> bool:
		if x < 2 or y < 2 or x > 29 or y > 29:
			return false
		var cx := clampi(x, 6, 25)
		var cy := clampi(y, 6, 25)
		return Vector2(x, y).distance_to(Vector2(cx, cy)) <= 4.5
	for y in CELL * 2:
		for x in CELL * 2:
			if not inside.call(x, y):
				img.set_pixel(x, y, src.get_pixel(FLOOR_1.x + x % CELL, FLOOR_1.y + y % CELL))
			elif not (inside.call(x - 1, y) and inside.call(x + 1, y) and inside.call(x, y - 1) and inside.call(x, y + 1)):
				img.set_pixel(x, y, P_L if y > 20 and not inside.call(x, y + 1) else P_K)  # lit near lip
			elif y < 8:
				var mortar := y == 5 or (y < 5 and (x + 2) % 6 == 0) or (y > 5 and (x + 5) % 6 == 0)
				img.set_pixel(x, y, P_K if mortar else (P_L if y == 3 else P_M))
			else:
				var deep := clampf((y - 8) / 16.0, 0.0, 1.0)
				img.set_pixel(x, y, P_D.lerp(Color("0b0709"), deep))
	return img


## Alfombra carmesí de borde hueso; rug_t/l/r/b/c y esquinas según qué lados son borde.
func _rug(id: String) -> Image:
	var part := id.substr(4)
	var top := part.begins_with("t")
	var bottom := part.begins_with("b")
	var left := part.ends_with("l") and part != "l" or part == "l"
	var right := part.ends_with("r") and part != "r" or part == "r"
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	for y in CELL:
		for x in CELL:
			var d := 99
			if top: d = mini(d, y)
			if bottom: d = mini(d, CELL - 1 - y)
			if left: d = mini(d, x)
			if right: d = mini(d, CELL - 1 - x)
			var c: Color
			match d:
				0: c = P_K
				1: c = P_L
				2, 3: c = P_O
				4: c = P_RD
				_:
					var a := posmod(x + y, 8)
					var b := posmod(x - y, 8)
					c = P_RD if a == 0 or b == 0 else (P_O if a == 4 and b == 4 else P_R)
			img.set_pixel(x, y, c)
	return img


## Losa grande: piedra media con junta oscura arriba/izquierda, brillo y sombra interiores.
## slab_b = dos losas de 16x8.
func _slab(split: bool) -> Image:
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	var base := P_F.lerp(P_M, 0.45)
	for y in CELL:
		for x in CELL:
			var ly := y % 8 if split else y
			var h := 8 if split else CELL
			var c := base
			if x == 0 or ly == 0:
				c = P_K
			elif x == 1 or ly == 1:
				c = P_M
			elif x == CELL - 1 or ly == h - 1:
				c = P_F
			elif posmod(x * 7 + y * 13, 23) == 0:
				c = P_F
			elif posmod(x * 11 + y * 5, 29) == 0:
				c = P_L.lerp(base, 0.5)  # flecks (mazmorra-32)
			img.set_pixel(x, y, c)
	return img


# --- mazmorra-32: decoración propia (paleta 0x72 + fuego, hierro, madera, sangre, musgo, agua) ---

const DECOR_PAL := {
	"k": "222222", "d": "21141b", "f": "483b3a", "m": "775c55", "l": "aa8d7a", "w": "d3bfa9",
	"I": "3d3d45", "i": "6b6b78", "j": "a3a3b0", "b": "5d3a26", "n": "8a5a3b", "t": "b07a4f",
	"r": "e2582c", "o": "f7a541", "y": "ffe9a3", "e": "8e2a1e", "R": "9f294e", "X": "6a1424",
	"B": "3f5a8a", "G": "4f7a3a", "g": "2f4a2a", "h": "7aa84a", "p": "35506b", "q": "1d2b3a",
	"s": "6e93b0", "c": "d3bfa98c", "v": "40506e", "u": "6d7fa3", "z": "c8b89a", "a": "c49a5a", "A": "8a6a3a",
}
## Torch flame, 5x7, 4 frames (the TileSet plays them at random start times).
const FLAME := [
	["..r..", ".ror.", ".ror.", "rooor", "royor", "ryyor", ".ryr."],
	["...r.", "..rr.", ".roor", ".royr", "royor", "royyr", ".ryr."],
	["...o.", "..r..", ".ror.", "rooor", "royyr", "ryyor", ".ryr."],
	[".r...", ".rr..", "roor.", "royor", "royor", "ryyyr", ".ryr."],
]
## Candle flame, 2x3, 4 frames.
const SMALL_FLAME := [[".o", "oy", "ry"], ["o.", "yo", "yr"], ["..", "oy", "ry"], [".r", "yo", "ry"]]
const TORCH := [
	"", "", "", "", "", "", "",
	"......kjjk......",
	"......kIIk......",
	".......nb.......",
	".....k.nb.k.....",
	".....kinbik.....",
	"......kkkk......",
	".......kk.......",
	"......kIIk......",
	"......kkkk......",
]
const BRAZIER := [
	"", "", "", "", "", "", "", "",
	"..keroeoreoerk..",
	"..kjjjjjjjjjjk..",
	"...kiiiiiiiik...",
	"....kIIIIIIk....",
	".....kkkkkk.....",
	"....ki.kk.ik....",
	"...ki..kk..ik...",
	"...kk..kk..kk...",
]
const CANDLES := [
	"", "", "", "", "",
	"......kwwk......",
	"......kwlk......",
	"......kwlk......",
	".kwwk.kwlk......",
	".kwlk.kwlk......",
	".kwlk.kwlk.kwwk.",
	".kwlk.kwlk.kwlk.",
	".kwlk.kwlk.kwlk.",
	".kwlk.kwlk.kwlk.",
	".kkkk.kkkk.kkkk.",
]
const SPRITES := {
	"shelf_a": [
		"", ".kkkkkkkkkkkkkk.", ".kbnnnnnnnnnnbk.", ".kbRRdBBGGdwlbk.", ".kbRRdBBGGdwlbk.",
		".kbRRdBBGGdwlbk.", ".kbRRdBBGGdwlbk.", ".kbttttttttttbk.", ".kbnnnnnnnnnnbk.",
		".kbdlwldBBdRRbk.", ".kbdjwjdBBdRRbk.", ".kbdjwjdBBdRRbk.", ".kbdkkkdBBdRRbk.",
		".kbttttttttttbk.", ".kbnnnnnnnnnnbk.", ".kkkkkkkkkkkkkk."],
	"shelf_b": [
		"", ".kkkkkkkkkkkkkk.", ".kbnnnnnnnnnnbk.", ".kbddddddddddbk.", ".kbdwwddsddRdbk.",
		".kbwlwdspddRRbk.", ".kbwlwdspddRRbk.", ".kbttttttttttbk.", ".kbnnnnnnnnnnbk.",
		".kbddddddddddbk.", ".kbwwwwdddGGdbk.", ".kblllwdddGGdbk.", ".kbddddddGGddbk.",
		".kbttttttttttbk.", ".kbnnnnnnnnnnbk.", ".kkkkkkkkkkkkkk."],
	"chains": [
		"", "...kk......kk...", "...ji......ji...", "..k..k....k..k..", "...ij......ij...",
		"..k..k....k..k..", "...ji......ji...", "..k..k....k..k..", "...ij......ij...",
		"..k..k....k..k..", "...ji......ji...", "..kiik....kiik..", ".ki..ik..ki..ik.",
		".kj..jk..kj..jk.", "..kjjk....kjjk.."],
	"shackles": [
		"", "", "", "", "", "...kkk", "..kjjjk", "..kj.ik", "..kiiikkk.kkk", "...kkk.jik.jik",
		".......kkk.kkk", "...........kjjjk", "...........kj.ik", "...........kiiik", "............kkk"],
	"bones_a": [
		"", "", "", "", "......kkkk", ".....kwwwwk", "....kwwwwlwk", "....kwkwwkwk", "....kwkwwkwk",
		".....kwwwwlk", ".....kwkwkwk", "......kkkkk", "..kk......kk", ".kwlkkkkkkkwlk", ".kwwwwwwwwwwlk",
		"..kk......kk"],
	"bones_b": [
		"", "", "", "...kk......kk", "..kwlk....kwlk", "...kwlk..kwlk", "....kwlkkwlk", ".....kwllwk",
		".....kwllwk", "....kwlkkwlk", "...kwlk..kwlk", "..kwlk....kwlk", "...kk......kk"],
	"cobweb_l": [
		"cccccccccccccc", "cc...c.....c", "c.c..c....c", "c..c.c...c", "c...ccc.c", "cccccc.c",
		"c...c.cc", "c..c..c", "c.c..c", "cc..c", "c..c", "c.c", "cc", "c", "c"],
	"crack_a": [
		"", "", "........k", ".......kd", "......kd", "......k", ".....kdk", "....kd..k",
		"....k....kd", "...kd.....k", "...k.......kd", "..kd.........k", "..k"],
	"crack_b": [
		"", "", "", "", "", "", "..k", "...kd", "....kkd...kd", ".......kkdk.k", "..........k..kd",
		"...............k"],
	"puddle": [
		"", "", "", "", "", "......qqqq", "....qqppppqq", "...qppppssppq", "..qppsppppppq",
		"..qpppppppppqq", "...qqpppppppq", ".....qqqqppq", "........qqq", "..qq"],
	"blood_a": [
		"", "", "", "", "......X", ".....XRX...X", "....XRRRX", "...XRRRRRXX", "..XRRRRRRRRX.X",
		"...XRRRRRRX", "....XXRRXX", "..X...XX....X", "........X"],
	"blood_b": [
		"", "", "", "", "", "", ".X..........X", "...XX.....XRX", "..XRRXX..XRRX", "...XRRRXXRRX",
		"....XXRRRRX", "......XXXX...X", "..X"],
	"moss_a": [
		"", "", "", "..........g", ".........gGg", "........gGhGg", ".........ggg", "", "",
		"....g", "...gGg....g", "..gGhGg..gGg", ".gGhhGGggGhGg", ".gGGGGGGGGGGg", "..ggggggggggg"],
	"moss_b": [
		"", ".g", "gGg......g", ".gGg....gGg", "..g......g", "", "", "", ".....gg", "....gGhg",
		"...gGhhGg...g", "....gGGg...gGg", ".....gg.....g"],
}
const BEDROLL := [
	"", "", "",
	"..kkkkkkkkkkkkkkkkkkkkkkkkkkkk",
	".kAaaaaaakvvvvvvvvvvvvvvvvvvvvk",
	".kazzzzzakvuuuuuuuuuuuuuuuuuuvk",
	".kazwwwzakvuuvuuuuvuuuuvuuuuuvk",
	".kazwwwzakvuuuuuuuuuuuuuuuuuuvk",
	".kazwwwzakvuuuvuuuuvuuuuvuuuuvk",
	".kazzzzzakvuuuuuuuuuuuuuuuuuuvk",
	".kaaaaaaakvvvvvvvvvvvvvvvvvvvvk",
	".kAAAAAAAAAAAAAAAAAAAAAAAAAAAAk",
	"..kkkkkkkkkkkkkkkkkkkkkkkkkkkk",
]


func _decor_cell(id: String) -> Image:
	var frame := int(id.get_slice("_", 1)) if id.get_slice("_", 1).is_valid_int() else 0
	if id.begins_with("torch_"):
		var img := _ascii(TORCH, DECOR_PAL)
		_stamp(img, FLAME[frame], DECOR_PAL, Vector2i(5, 0))
		return img
	if id.begins_with("brazier_"):
		var img := _ascii(BRAZIER, DECOR_PAL)
		_stamp(img, FLAME[(frame + 1) % 4], DECOR_PAL, Vector2i(3, 1))
		_stamp(img, FLAME[(frame + 2) % 4], DECOR_PAL, Vector2i(8, 1))
		_stamp(img, FLAME[frame], DECOR_PAL, Vector2i(5, 0))
		return img
	if id.begins_with("candles_"):
		var img := _ascii(CANDLES, DECOR_PAL)
		_stamp(img, SMALL_FLAME[(frame + 1) % 4], DECOR_PAL, Vector2i(2, 5))
		_stamp(img, SMALL_FLAME[frame], DECOR_PAL, Vector2i(7, 2))
		_stamp(img, SMALL_FLAME[(frame + 3) % 4], DECOR_PAL, Vector2i(12, 7))
		return img
	if id.begins_with("bedroll_"):
		var bed := _ascii(BEDROLL, DECOR_PAL, Vector2i(CELL * 2, CELL))
		return bed.get_region(Rect2i(0 if id == "bedroll_l" else CELL, 0, CELL, CELL))
	if id == "cobweb_r":
		var web := _ascii(SPRITES["cobweb_l"], DECOR_PAL)
		web.flip_x()
		return web
	return _ascii(SPRITES[id], DECOR_PAL)


func _box(img: Image, r: Rect2i, fill: Color, outline: Color) -> void:
	img.fill_rect(r, outline)
	img.fill_rect(r.grow(-1), fill)


## Blood altar, 32x32: plinth, carved body, top slab with a bowl and candle stubs, and (active)
## a floating crimson gem + glowing rune + a drip down the front; used = dry and dark.
func _altar(used: bool) -> Image:
	var img := Image.create(CELL * 2, CELL * 2, false, Image.FORMAT_RGBA8)
	var c := func(key: String) -> Color: return Color(DECOR_PAL[key])
	_box(img, Rect2i(4, 26, 24, 5), c.call("m"), c.call("k"))  # plinth
	img.fill_rect(Rect2i(5, 27, 22, 1), c.call("l"))
	_box(img, Rect2i(8, 16, 16, 11), c.call("m"), c.call("k"))  # body
	img.fill_rect(Rect2i(9, 17, 1, 9), c.call("l"))
	img.fill_rect(Rect2i(22, 17, 1, 9), c.call("f"))
	_box(img, Rect2i(5, 11, 22, 6), c.call("l"), c.call("k"))  # top slab
	img.fill_rect(Rect2i(6, 12, 20, 1), c.call("w"))
	img.fill_rect(Rect2i(6, 15, 20, 1), c.call("m"))
	_box(img, Rect2i(11, 12, 10, 3), c.call("d" if used else "X"), c.call("k"))  # bowl
	if not used:
		img.fill_rect(Rect2i(13, 13, 6, 1), c.call("R"))
	for x: int in [6, 24]:  # candle stubs
		_box(img, Rect2i(x, 8, 3, 4), c.call("w"), c.call("k"))
		if not used:
			img.set_pixel(x + 1, 6, c.call("o"))
			img.set_pixel(x + 1, 7, c.call("y"))
	var rune: Color = c.call("d") if used else c.call("R")
	for p: Vector2i in [Vector2i(15, 18), Vector2i(16, 18), Vector2i(14, 19), Vector2i(17, 19), Vector2i(15, 20),
			Vector2i(16, 20), Vector2i(15, 21), Vector2i(16, 21), Vector2i(14, 22), Vector2i(17, 22), Vector2i(15, 23), Vector2i(16, 23)]:
		img.set_pixelv(p, rune)
	if not used:
		img.fill_rect(Rect2i(19, 16, 1, 3), c.call("R"))  # drip
		img.set_pixel(19, 19, c.call("X"))
		_stamp(img, ["..kk..", ".kRRk.", "kRllRk", "kRRRXk", ".kRXk.", "..kk.."], DECOR_PAL, Vector2i(13, 1))  # gem
	return img

# --- Íconos de habilidades (juego-36): 16x16 como los ítems, una PNG por habilidad ---
# o contorno; d/m/l/w sombra → luz; el resto, acentos de cada ícono.

const ABILITY_ICONS := {
	"warrior_passive": [[  # Piel de Hierro: coraza
		"................",
		"..oooo....oooo..",
		".owllmoooomdddo.",
		".olmmmmwlmmmddo.",
		".olmmmmwlmmmddo.",
		"..olmmmwlmmmdo..",
		"..olmmmwlmmmdo..",
		"..olmmmwlmmmdo..",
		"..oyyyyyyyyyyo..",
		"..olmmmwlmmmdo..",
		"...olmmwlmmdo...",
		"....olmwlmdo....",
		".....oooooo.....",
		"................",
		"................",
		"................",
	], {"o": "16181e", "d": "3c4250", "m": "7a8494", "l": "b4bcc8", "w": "eef2f6", "y": "8a5a2a"}],
	"warrior_active": [[  # Grito de Guerra: cuerno
		"..s.......oooo..",
		"s..s.....olllloo",
		".s..s...olkkkklo",
		"..s.....olkkkklo",
		".......olmlkklo.",
		"......olmmdlloo.",
		".....olmyydoo...",
		"....olmyydo.....",
		"...olmmddo......",
		"..olmmddo.......",
		"..olmddo........",
		".oldddo.........",
		".oyyo...........",
		"..oo............",
		"................",
		"................",
	], {"o": "2a1a10", "d": "6a4a2a", "m": "b08850", "l": "e8d0a0", "y": "d8a830", "s": "f0e6c8", "k": "1e120a"}],
	"mage_passive": [[  # Mente Analítica: ojo arcano
		"................",
		".......s........",
		"...s.......s....",
		"................",
		".....oooooo.....",
		"...oowwwwwwoo...",
		"..owwwvvvvwwwo..",
		".owwwvvkgvvwwwo.",
		"owwwvvkkkkvvwwwo",
		".owwwvvkkvvwwwo.",
		"..owwwvvvvwwwo..",
		"...oowwwwwwoo...",
		".....oooooo.....",
		"................",
		".....s.....s....",
		"................",
	], {"o": "1a1028", "w": "e4dcec", "v": "8a4ad0", "k": "1a0830", "g": "ffffff", "s": "c080ff"}],
	"rogue_passive": [[  # Paso Ligero: bota alada
		"................",
		"................",
		".o....ooooo.....",
		"owo...ollldo....",
		"owwo..olmmdo....",
		"owwwooolmmdo....",
		".owgwwolmmdo....",
		"owwwgwolmmdo....",
		".oowwwolmmdo....",
		"...oooolmmmdooo.",
		"......olmmmmmddo",
		"......olmmmmmmdo",
		"......oddddddddo",
		".......oooooooo.",
		"................",
		"................",
	], {"o": "20140c", "d": "4a2c16", "m": "8a5a30", "l": "c08850", "w": "f4f0e4", "g": "b8b4a8"}],
	"rogue_active": [[  # Golpe Furtivo: daga
		"................",
		"................",
		"............oo..",
		"...........owo..",
		"..........owlo..",
		".........owlo...",
		"...oo...owlo....",
		"...oyo.owlo.....",
		"....oyowlo......",
		".....oyyo.......",
		"....ohoyo.......",
		"...oho.oyo......",
		"..oho...oo......",
		".oho............",
		".opo............",
		"..o.............",
	], {"o": "141418", "w": "f0f4f8", "l": "8a94a4", "y": "b08030", "h": "5a3420", "p": "c0a040"}],
	"tank_passive": [[  # Muro Viviente: muralla almenada
		"................",
		".oooo.oooo.oooo.",
		".ollo.ollo.ollo.",
		".omdo.omdo.omdo.",
		".ommmmmmmmmmmdo.",
		".olmmmkmmmmkmdo.",
		".okkkkkkkkkkkko.",
		".olmkmmmmkmmmdo.",
		".olmkmmmmkmmmdo.",
		".okkkkkkkkkkkko.",
		".olmmmkmmmmkmdo.",
		".olmmmkmmmmkmdo.",
		".okkkkkkkkkkkko.",
		".olmkmmmmkmmmdo.",
		".oooooooooooooo.",
		"................",
	], {"o": "1a1612", "d": "4a4238", "m": "7c7262", "l": "aca08a", "k": "2e2822"}],
	"tank_active": [[  # Interposición: escudo que para una flecha
		"................",
		"................",
		".....oooooooooo.",
		".....owllyymmdo.",
		".....olllyymmdo.",
		"f....olllyymmdo.",
		"faaah.oyyyyyyyyo",
		"f....ollmyymmdo.",
		".....olmmyymmdo.",
		"......olmyymdo..",
		"......olmyymdo..",
		".......omyydo...",
		"........oyyo....",
		".........oo.....",
		"................",
		"................",
	], {"o": "141a28", "w": "a8c8f0", "l": "6090d0", "m": "3a68b0", "d": "24407a", "y": "e0b040", "a": "8a6a40", "h": "c8ccd4", "f": "e8e0d0"}],
}

## Bendición de las Obras: engranaje de bronce con un rayo dorado encima (por fórmula).
const BOLT := [
	"................",
	"................",
	"..........oo....",
	".........owo....",
	"........oyo.....",
	".......oyyoo....",
	"......oyyyyo....",
	".....ooooyo.....",
	".......oyo......",
	"......oyo.......",
	"......oo........",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const BOLT_PAL := {"o": "3a2400", "y": "ffd040", "w": "fff4b0"}


func _abilities() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "abilities/"))
	var ids: Array = ABILITY_ICONS.keys() + ["mage_active"]
	for id: String in ids:
		if FileAccess.file_exists(OUT + "src/abilities/%s.ase" % id):
			continue  # retocado en LibreSprite: no se pisa
		var img: Image
		if id == "mage_active":
			img = _gear(Color("16181e"), Color("3c4250"), Color("6c7484"), Color("a4acb8"))
			_stamp(img, BOLT, BOLT_PAL, Vector2i.ZERO)
		else:
			img = _ascii(ABILITY_ICONS[id][0], ABILITY_ICONS[id][1])
		img.save_png(ProjectSettings.globalize_path(OUT + "abilities/ability_%s.png" % id))
	print("own abilities: %d íconos" % ids.size())


## Engranaje de 8 dientes con agujero; luz arriba a la izquierda y contorno de 1 px.
func _gear(outline: Color, dark: Color, mid: Color, light: Color) -> Image:
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	var c := Vector2(8.0, 8.0)
	var solid := func(x: int, y: int) -> bool:
		var v := Vector2(x + 0.5, y + 0.5) - c
		var r := v.length()
		var tooth := absf(fposmod(v.angle() + PI / 6.0, PI / 3.0) - PI / 6.0) < PI / 11.0
		return r >= 1.9 and r <= (7.4 if tooth else 5.2)
	for y in CELL:
		for x in CELL:
			if solid.call(x, y):
				var shade := (Vector2(x + 0.5, y + 0.5) - c).normalized().dot(Vector2(-0.7, -0.7))
				img.set_pixel(x, y, light if shade > 0.6 else (dark if shade < -0.3 else mid))
	for y in CELL:
		for x in CELL:
			if solid.call(x, y):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < CELL and q.y < CELL and solid.call(q.x, q.y):
					img.set_pixel(x, y, outline)
					break
	return img

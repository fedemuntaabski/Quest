extends SceneTree

## personajes-46: own art for the characters, built from the 0x72 heroes and weapons (CC0) with the
## 0x72 palette, as the base that is then touched up in LibreSprite (tools/libresprite.sh import ->
## edit assets/art/own/src/{characters,vfx}/*.ase -> export). A strip whose .ase exists is never
## overwritten here (the .ase owns it).
##  - assets/art/own/characters/<prefix>_attack.png: 4 frames (wind-up, swing, strike + arc or flash,
##    recover) of the hero holding its weapon;
##  - assets/art/own/characters/<prefix>_fall.png: 4 frames (hurt, tipping, falling, lying);
##    both on a 48x44 canvas with the 16x28 body where the idle frame is (feet stay on the origin);
##  - assets/art/own/vfx/own_hit_burst.png (32 px, 5 frames, white: tinted by code) and
##    own_death_soul.png (32 px, 8 frames: a wisp that rises and fades) + their index.json rows.
## The hero SpriteFrames (resources/sprite_frames/hero_<prefix>.tres: idle/run/hit from the 0x72
## frames + attack/fall as AtlasTextures over these strips) are written by tools/libresprite.sh frames.
##   godot --headless --path . --script res://tools/build_personajes_art.gd

const CHAR_DIR := "res://assets/art/characters/"
const ITEM_DIR := "res://assets/art/items/"
const OWN := "res://assets/art/own/"
## 0x72 prefix -> [weapon, style]
const HEROES := {
	"knight_m": ["weapon_knight_sword", "swing"],
	"wizzard_m": ["weapon_red_magic_staff", "cast"],
	"elf_m": ["weapon_knife", "stab"],
	"dwarf_m": ["weapon_hammer", "swing"],
	"lizard_m": ["weapon_bow", "shoot"],
	"elf_f": ["weapon_mace", "swing"],
}
## Per frame: [body dx, weapon angle (deg, clockwise from pointing up), weapon in front, effect]
const STYLES := {
	"swing": [[-1, -60, false, false], [0, 0, true, false], [1, 85, true, true], [0, 40, true, false]],
	"stab": [[-1, 40, true, false], [1, 85, true, false], [2, 90, true, true], [0, 55, true, false]],
	"cast": [[0, -20, true, false], [0, -5, true, true], [-1, 15, true, true], [0, 0, true, false]],
	"shoot": [[0, 0, true, false], [-1, 0, true, false], [-1, 0, true, true], [0, 0, true, false]],
}
const W := 48
const H := 44
## Where the 16x28 body sits in the canvas (centred: same feet as the idle frame).
const BODY := Vector2i(16, 8)
const FALL_DEG := [0.0, 25.0, 60.0, 90.0]
const ATTACK_FPS := 20
const FALL_FPS := 12


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(_abs(OWN + "characters"))
	var index := {}
	for prefix: String in HEROES:
		var idle := _img(CHAR_DIR + prefix + "_idle_anim_f0.png")
		var hurt := _img(CHAR_DIR + prefix + "_hit_anim_f0.png")
		var weapon := _img(ITEM_DIR + HEROES[prefix][0] + ".png")
		_save_strip("characters", prefix + "_attack", _attack(idle, weapon, HEROES[prefix][1]), 4)
		_save_strip("characters", prefix + "_fall", _fall(hurt), 4)
		index[prefix + "_attack"] = _row(W, H, 4, ATTACK_FPS)
		index[prefix + "_fall"] = _row(W, H, 4, FALL_FPS)
	_write_index(OWN + "characters/index.json", index)
	var vfx := {}
	_save_strip("vfx", "own_hit_burst", _hit_burst(), 5)
	_save_strip("vfx", "own_death_soul", _death_soul(), 8)
	vfx["own_hit_burst"] = _row(32, 32, 5, 15)
	vfx["own_death_soul"] = _row(32, 32, 8, 15)
	_write_index(OWN + "vfx/index.json", vfx)
	print("build_personajes_art: %d heroes, 2 vfx" % HEROES.size())
	quit()


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _img(path: String) -> Image:
	var img := Image.load_from_file(_abs(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _row(fw: int, fh: int, frames: int, fps: int) -> Dictionary:
	return {"frame_w": fw, "frame_h": fh, "frames": frames, "columns": frames, "fps": fps}


## Merges `rows` into the index (rows already there that are not ours are kept).
func _write_index(path: String, rows: Dictionary) -> void:
	var index := {}
	if FileAccess.file_exists(path):
		index = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key in rows:
		if not FileAccess.file_exists(OWN + "src/%s/%s.ase" % [path.get_base_dir().get_file(), key]):
			index[key] = rows[key]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "\t", true) + "\n")


func _save_strip(dir: String, name: String, frames: Array[Image], count: int) -> void:
	if FileAccess.file_exists(OWN + "src/%s/%s.ase" % [dir, name]):
		print("skip %s (its .ase owns it)" % name)
		return
	var fw := frames[0].get_width()
	var strip := Image.create(fw * count, frames[0].get_height(), false, Image.FORMAT_RGBA8)
	for i in count:
		strip.blit_rect(frames[i], Rect2i(Vector2i.ZERO, frames[i].get_size()), Vector2i(i * fw, 0))
	strip.save_png(_abs(OWN + "%s/%s.png" % [dir, name]))


## Opaque bounding box of `img`.
func _bbox(img: Image) -> Rect2i:
	return img.get_used_rect()


## Brightest and most saturated opaque colours of `img` (arc and flash colours).
func _bright(img: Image) -> Color:
	var best := Color.WHITE
	var v := -1.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.v > v:
				v = c.v
				best = c
	return best


func _vivid(img: Image) -> Color:
	var best := _bright(img)
	var s := -1.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.s * c.v > s:
				s = c.s * c.v
				best = c
	return best


## Pastes `src` rotated by `deg` (clockwise) so its point `pivot` lands on `at` (nearest neighbour).
func _blit_rotated(dst: Image, src: Image, pivot: Vector2, at: Vector2, deg: float) -> void:
	var a := deg_to_rad(deg)
	var c := cos(a)
	var s := sin(a)
	for y in dst.get_height():
		for x in dst.get_width():
			var v := Vector2(x + 0.5, y + 0.5) - at
			var p := pivot + Vector2(v.x * c + v.y * s, -v.x * s + v.y * c)
			var px := floori(p.x)
			var py := floori(p.y)
			if px < 0 or py < 0 or px >= src.get_width() or py >= src.get_height():
				continue
			var col := src.get_pixel(px, py)
			if col.a > 0.5:
				dst.set_pixel(x, y, col)


func _attack(idle: Image, weapon: Image, style: String) -> Array[Image]:
	var out: Array[Image] = []
	var body := _bbox(idle)
	var wbox := _bbox(weapon)
	var grip := Vector2(wbox.position.x + wbox.size.x * 0.5, wbox.end.y - 1.5)
	var arc := _bright(weapon)
	var flash := _vivid(weapon)
	for step: Array in STYLES[style]:
		var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
		var origin := BODY + Vector2i(int(step[0]), 0)
		var hand := Vector2(origin) + Vector2(body.end.x - 2.5, body.end.y - 7.5)
		var angle := float(step[1])
		if not step[2]:
			_blit_rotated(img, weapon, grip, hand, angle)
		img.blend_rect(idle, Rect2i(Vector2i.ZERO, idle.get_size()), origin)
		if step[2]:
			_blit_rotated(img, weapon, grip, hand, angle)
		if step[3]:
			_effect(img, style, hand, wbox.size.y, arc, flash)
		out.append(img)
	return out


## The strike's trace: a swing arc, a thrust streak, a spell spark at the staff tip, an arrow.
func _effect(img: Image, style: String, hand: Vector2, reach: int, arc: Color, flash: Color) -> void:
	match style:
		"swing":
			for deg in range(15, 110, 6):
				var r := reach * 0.75
				var p := hand + Vector2.from_angle(deg_to_rad(deg - 90.0)) * r
				_dot(img, p, arc)
				if deg % 12 == 0:
					_dot(img, p + Vector2.from_angle(deg_to_rad(deg - 90.0)), Color(arc, 0.6))
		"stab":
			for i in 5:
				_dot(img, hand + Vector2(reach + 2 + i * 2, -1), Color(arc, 1.0 - i * 0.18))
		"cast":
			var tip := hand + Vector2(0, -reach + 1)
			for d: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_dot(img, tip + d, flash if d == Vector2.ZERO else Color(flash, 0.8))
			for d: Vector2 in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
				_dot(img, tip + d, Color(arc, 0.7))
		"shoot":
			for i in 9:
				_dot(img, hand + Vector2(4 + i, -1), arc if i < 7 else flash)
			_dot(img, hand + Vector2(11, -2), flash)
			_dot(img, hand + Vector2(11, 0), flash)


func _dot(img: Image, p: Vector2, col: Color) -> void:
	var x := floori(p.x)
	var y := floori(p.y)
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


func _fall(hurt: Image) -> Array[Image]:
	var out: Array[Image] = []
	var body := _bbox(hurt)
	var feet := Vector2(body.position.x + body.size.x * 0.5, body.end.y)
	for deg: float in FALL_DEG:
		var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
		var lift := body.size.x * 0.5 * sin(deg_to_rad(deg))
		_blit_rotated(img, hurt, feet, Vector2(BODY) + feet - Vector2(0, lift), deg)
		out.append(img)
	return out


func _hit_burst() -> Array[Image]:
	var out: Array[Image] = []
	for i in 5:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var c := Vector2(16, 16)
		var r := 3.0 + i * 2.5
		var a := 1.0 - i * 0.18
		for k in 8:
			var dir := Vector2.from_angle(k * TAU / 8.0)
			var length := (4 if k % 2 == 0 else 2) - (i / 2)
			for j in maxi(length, 1):
				_dot(img, c + dir * (r + j), Color(1, 1, 1, a))
		if i < 2:
			for d: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_dot(img, c + d, Color.WHITE)
		out.append(img)
	return out


## Pale wisp (0x72-ish greys/blues) rising from the body and fading out.
func _death_soul() -> Array[Image]:
	var out: Array[Image] = []
	var light := Color("c0cbdc")
	var mid := Color("8b9bb4")
	var dark := Color("5a6988")
	for i in 8:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var y := 24.0 - i * 2.4
		var a := 1.0 if i < 4 else 1.0 - (i - 3) * 0.2
		var sway := 1.0 if i % 4 < 2 else -1.0
		var rows := [[-2, 2, light], [-3, 3, light], [-3, 3, mid], [-2, 2, mid], [-1 + sway, 1 + sway, dark], [sway, sway, dark]]
		for k in rows.size():
			var row: Array = rows[k]
			for x in range(int(row[0]), int(row[1]) + 1):
				_dot(img, Vector2(16 + x, y - 3 + k), Color(row[2], a))
		_dot(img, Vector2(15, y - 1), Color(Color("21141b"), a))
		_dot(img, Vector2(17, y - 1), Color(Color("21141b"), a))
		out.append(img)
	return out

class_name MenuBackdrop
extends Control

## menu-33: animated backdrop of the menu screens. The illustration is cover-fitted
## (like STRETCH_KEEP_ASPECT_COVERED) and drifts a few pixels against the mouse
## (parallax); additive warm glows flicker on its torches/braziers/candles (`flames`),
## the relic gem pulses slowly (`gem`), embers rise from the floor, a vignette darkens
## the edges and an optional `tint` unifies an older picture. Everything runs on real
## time (Time ticks) and only reads the mouse position: no input events are handled.
## Accessibility.reduce_flashes turns the flicker into a steady glow.

## The illustration.
@export var texture: Texture2D:
	set(value):
		texture = value
		if _image:
			_image.texture = value
			_layout()
## x, y = point on the image (0..1), z = glow radius as a fraction of the image height.
@export var flames: PackedVector3Array = PackedVector3Array()
## Relic gem (slow pulse): x, y on the image, z = radius (<= 0: none).
@export var gem: Vector3 = Vector3.ZERO
## Flat colour over the picture (alpha = strength), e.g. to cool and darken it.
@export var tint: Color = Color(0, 0, 0, 0)
@export_range(0.0, 1.0) var vignette: float = 0.7
## Max parallax drift in pixels (0 = off).
@export var parallax_px: float = 10.0
@export var embers: bool = true
@export var ember_amount: int = 34

const FLAME_COLOR := Color(1.0, 0.6, 0.24)
const GEM_COLOR := Color(1.0, 0.84, 0.42)

static var _glow_texture: GradientTexture2D
static var _add_material: CanvasItemMaterial

var _image: TextureRect
var _glow_layer: Control
var _glows: Array[TextureRect] = []
var _gem_glow: TextureRect
var _ember_fx: CPUParticles2D
var _parallax := Vector2.ZERO
var _last_ms: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build()
	resized.connect(_layout)
	_layout()
	_last_ms = Time.get_ticks_msec()


func _build() -> void:
	_image = TextureRect.new()
	_image.name = "Image"
	_image.texture = texture
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image, false, Node.INTERNAL_MODE_FRONT)

	_glow_layer = Control.new()
	_glow_layer.name = "Glows"
	_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow_layer, false, Node.INTERNAL_MODE_FRONT)
	for i in flames.size():
		_glows.append(_make_glow(FLAME_COLOR))
	if gem.z > 0.0:
		_gem_glow = _make_glow(GEM_COLOR)

	if tint.a > 0.0:
		var shade := ColorRect.new()
		shade.name = "Tint"
		shade.color = tint
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shade, false, Node.INTERNAL_MODE_FRONT)

	# Embers are created on first show (_process): CPUParticles2D draws from the global
	# RNG when it starts, and a hidden backdrop (Opciones inside the pause menu) must not
	# shift the seed a floor is generated from.

	if vignette > 0.0:
		var vig := TextureRect.new()
		vig.name = "Vignette"
		vig.texture = _vignette_texture(vignette)
		vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vig.stretch_mode = TextureRect.STRETCH_SCALE
		vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(vig, false, Node.INTERNAL_MODE_FRONT)


func _make_glow(color: Color) -> TextureRect:
	if _glow_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.6))
		g.set_color(1, Color(1, 1, 1, 0.0))
		g.add_point(0.35, Color(1, 1, 1, 0.22))
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = g
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(0.5, 0.0)
		_glow_texture.width = 128
		_glow_texture.height = 128
		_add_material = CanvasItemMaterial.new()
		_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := TextureRect.new()
	glow.texture = _glow_texture
	glow.material = _add_material
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.self_modulate = color
	_glow_layer.add_child(glow)
	return glow


func _make_embers() -> CPUParticles2D:
	var fx := CPUParticles2D.new()
	fx.name = "Embers"
	fx.amount = ember_amount
	fx.lifetime = 7.0
	fx.preprocess = 7.0
	fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fx.direction = Vector2(0.15, -1.0)
	fx.spread = 22.0
	fx.gravity = Vector2(4.0, -10.0)
	fx.initial_velocity_min = 22.0
	fx.initial_velocity_max = 60.0
	fx.scale_amount_min = 1.5
	fx.scale_amount_max = 3.5
	fx.angular_velocity_min = -40.0
	fx.angular_velocity_max = 40.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(QuestPalette.EMBER, 0.0))
	ramp.set_color(1, Color(QuestPalette.EMBER, 0.0))
	ramp.add_point(0.12, Color(QuestPalette.RELIC_GOLD_PALE, 0.95))
	ramp.add_point(0.6, Color(QuestPalette.EMBER, 0.65))
	fx.color_ramp = ramp
	if "use_fixed_seed" in fx:
		fx.set("use_fixed_seed", true)
		fx.set("seed", 1733)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = mat
	return fx


static func _vignette_texture(strength: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, strength))
	g.add_point(0.55, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	return tex


## Where image point `uv` (0..1) lands in this control, with the parallax margin.
func image_to_local(uv: Vector2) -> Vector2:
	var rect := _image_rect()
	if texture == null:
		return rect.position + rect.size * uv
	var tex := texture.get_size()
	var k := maxf(rect.size.x / tex.x, rect.size.y / tex.y)
	var drawn := tex * k
	return rect.position + (rect.size - drawn) * 0.5 + drawn * uv


func _image_rect() -> Rect2:
	var m := Vector2(parallax_px, parallax_px)
	return Rect2(-m, size + m * 2.0)


func _drawn_height() -> float:
	if texture == null:
		return size.y
	var rect := _image_rect()
	var tex := texture.get_size()
	return tex.y * maxf(rect.size.x / tex.x, rect.size.y / tex.y)


func _layout() -> void:
	if _image == null:
		return
	var rect := _image_rect()
	_image.position = rect.position + _parallax
	_image.size = rect.size
	_glow_layer.position = _parallax
	_glow_layer.size = size
	var h := _drawn_height()
	for i in _glows.size():
		_place(_glows[i], flames[i], h)
	if _gem_glow:
		_place(_gem_glow, gem, h)
	if _ember_fx:
		_ember_fx.position = Vector2(size.x * 0.5, size.y + 8.0)
		_ember_fx.emission_rect_extents = Vector2(size.x * 0.55, 12.0)


func _place(glow: TextureRect, spec: Vector3, drawn_h: float) -> void:
	var r := spec.z * drawn_h
	glow.size = Vector2(r, r) * 2.0
	glow.position = image_to_local(Vector2(spec.x, spec.y)) - Vector2(r, r)
	glow.pivot_offset = Vector2(r, r)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	if embers and _ember_fx == null:
		_ember_fx = _make_embers()
		# above the image, glows and tint; under the vignette
		var vig := get_node_or_null("Vignette")
		add_child(_ember_fx, false, Node.INTERNAL_MODE_FRONT)
		if vig:
			move_child(_ember_fx, vig.get_index(true))
		_layout()
	var now := Time.get_ticks_msec()
	var dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	var t := now / 1000.0

	if parallax_px > 0.0:
		var view := get_viewport_rect().size
		var target := Vector2.ZERO
		if view.x > 0.0 and view.y > 0.0:
			var m := get_viewport().get_mouse_position() / view - Vector2(0.5, 0.5)
			target = (m.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)) * -2.0) * parallax_px
		var next := _parallax.lerp(target, 1.0 - exp(-2.5 * dt))
		if next.distance_squared_to(_parallax) > 0.0001:
			_parallax = next
			_image.position = _image_rect().position + _parallax
			_glow_layer.position = _parallax

	var steady := Accessibility.reduce_flashes
	for i in _glows.size():
		var ph := i * 1.93
		var f := 0.9 if steady else 0.76 + 0.12 * sin(t * 8.7 + ph) + 0.07 * sin(t * 21.1 + ph * 2.3) + 0.05 * sin(t * 2.9 + ph)
		_glows[i].modulate.a = f
	if _gem_glow:
		var p := 0.5 + 0.5 * sin(t * 1.9)
		_gem_glow.modulate.a = 0.8 if steady else 0.62 + 0.38 * p
		var s := 1.0 if steady else 0.94 + 0.1 * p
		_gem_glow.scale = Vector2(s, s)

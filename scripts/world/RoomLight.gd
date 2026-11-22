extends Node2D
class_name RoomLight

## RoomLight: per-room lighting placeholder, child of a room-kind RoomZone.
## Dark (unlit) = pulsing dark-red overlay (enemies spawn in dark rooms);
## lit = overlay fades out and a warm PointLight2D fades in. Driven only
## by signals: RoomZone.light_changed and ResourceManager.resource_changed
## (gold outline when the player can afford RoomZone.get_light_cost() right now).

const LIGHT_TEXTURE_SIZE := 256

var config: MapVisualConfig
var _overlay: Polygon2D
var _afford_outline: Line2D
var _light: PointLight2D
var _pulse: Tween
var _lit: bool = false
var _zone: RoomZone
## mazmorra-32: torch / brazier / candles lights of this room, their phases and the shared 0..1 level
## the light-up tween drives (the flicker rides on top of it in _process).
var _flames: Array[PointLight2D] = []
var _phases: Array[float] = []
var _flame_level: float = 0.0
static var _soft_texture: GradientTexture2D


## `shape` (mazmorra-31): the zone's outline for cut-corner rooms (empty = the size_px rect).
func setup(zone: RoomZone, size_px: Vector2, p_config: MapVisualConfig, shape: PackedVector2Array = PackedVector2Array()) -> void:
	_zone = zone
	config = p_config
	var half := size_px / 2.0
	var points := shape if not shape.is_empty() else PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])

	_overlay = Polygon2D.new()
	_overlay.name = "DarkOverlay"
	_overlay.polygon = points
	_overlay.color = config.dark_overlay_color
	add_child(_overlay)

	_afford_outline = Line2D.new()
	_afford_outline.name = "AffordOutline"
	var closed := points.duplicate()
	closed.append(points[0])
	_afford_outline.points = closed
	_afford_outline.width = 2.0
	_afford_outline.default_color = config.affordable_outline_color
	_afford_outline.visible = false
	add_child(_afford_outline)

	_light = PointLight2D.new()
	_light.name = "WarmLight"
	_light.texture = _make_light_texture()
	_light.shadow_enabled = config.room_light_shadows
	_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_light.shadow_filter_smooth = 2.0
	_light.texture_scale = maxf(size_px.x, size_px.y) / LIGHT_TEXTURE_SIZE * 1.2
	_light.color = config.warm_light_color
	_light.energy = 0.0
	_light.enabled = false
	add_child(_light)

	zone.light_changed.connect(_on_light_changed)
	var resources := ManagerLocator.get_resource_manager()
	if resources:
		resources.resource_changed.connect(_on_resource_changed)
		_on_resource_changed("embers", resources.get_resource("embers"), 0)
		# Research can lower the light cost without any embers change.
		resources.research_changed.connect(_on_research_changed)
	set_process(false)
	_start_danger_pulse()


## mazmorra-31: the room type's light colour (RoomTypeVisual.light_color).
func set_light_color(color: Color) -> void:
	_light.color = color
	for flame in _flames:
		flame.color = color


## mazmorra-32: one flame light at `at` (global px), kind "torch" / "brazier" / "candles"; lit with the room.
func add_flame(at: Vector2, kind: String) -> void:
	var flame := PointLight2D.new()
	flame.name = "Flame%d" % _flames.size()
	flame.texture = _make_light_texture()
	var radius: float = {"torch": config.torch_radius, "brazier": config.brazier_radius}.get(kind, config.candles_radius)
	flame.texture_scale = radius / (LIGHT_TEXTURE_SIZE * 0.5)
	flame.color = _light.color
	flame.energy = 0.0
	flame.enabled = _lit
	flame.shadow_enabled = config.flame_shadows
	flame.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	add_child(flame)
	flame.global_position = at
	_flames.append(flame)
	_phases.append(float(_flames.size()) * 2.399)  # golden angle: neighbours never flicker in step
	set_process(true)


func get_flames() -> Array[PointLight2D]:
	return _flames


## Flicker: two sines per flame on real time (pause-proof), scaled by the light-up level.
func _process(_delta: float) -> void:
	if _flame_level <= 0.0:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var depth := config.flame_flicker
	for i in _flames.size():
		var p := _phases[i]
		var wobble := 0.5 + 0.3 * sin(t * 9.0 + p) + 0.2 * sin(t * 23.0 + p * 2.0)
		_flames[i].energy = config.flame_energy * _flame_level * (1.0 - depth + depth * wobble)


func is_dark() -> bool:
	return not _lit


func is_affordable_highlighted() -> bool:
	return _afford_outline.visible


func _on_light_changed(_zone_id: String, lit: bool) -> void:
	_lit = lit
	refresh_affordable()
	if _pulse:
		_pulse.kill()
	# Real time: lighting a room during the tactical pause (time_scale 0) shows at once.
	var tween := create_tween().set_parallel().set_ignore_time_scale().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var t := config.light_transition_time
	if lit:
		_light.enabled = true
		for flame in _flames:
			flame.enabled = true
		tween.tween_property(_overlay, "color:a", 0.0, t)
		tween.tween_property(_light, "energy", config.warm_light_energy, t)
		tween.tween_property(self, "_flame_level", 1.0, t * 0.6).set_delay(t * 0.2)
	else:
		tween.tween_property(_overlay, "color", config.dark_overlay_color, t)
		tween.tween_property(_light, "energy", 0.0, t)
		tween.tween_property(self, "_flame_level", 0.0, t * 0.5)
		tween.chain().tween_callback(_on_darkened)


func _on_darkened() -> void:
	_light.enabled = false
	for flame in _flames:
		flame.energy = 0.0
		flame.enabled = false
	_start_danger_pulse()


func _on_research_changed() -> void:
	refresh_affordable()


## Gold outline: dark and the embers covers THIS room's next light cost.
func refresh_affordable() -> void:
	var resources := ManagerLocator.get_resource_manager()
	_on_resource_changed("embers", resources.get_resource("embers") if resources else 0, 0)


func _on_resource_changed(key: String, amount: int, _delta: int) -> void:
	if key == "embers":
		_afford_outline.visible = not _lit and amount >= (_zone.next_light_cost() if _zone else RoomZone.get_light_cost())


func _start_danger_pulse() -> void:
	if not is_inside_tree():
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_overlay, "color", config.danger_overlay_color, config.danger_pulse_time).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_overlay, "color", config.dark_overlay_color, config.danger_pulse_time).set_trans(Tween.TRANS_SINE)


## One soft radial texture shared by every room light and flame.
func _make_light_texture() -> GradientTexture2D:
	if _soft_texture:
		return _soft_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = LIGHT_TEXTURE_SIZE
	texture.height = LIGHT_TEXTURE_SIZE
	_soft_texture = texture
	return texture

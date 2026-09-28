extends Node2D
class_name RoomLight

## RoomLight: per-room lighting placeholder, child of a room-kind RoomZone.
## Dark (unpowered) = pulsing dark-red overlay (enemies spawn in dark rooms);
## powered = overlay fades out and a warm PointLight2D fades in. Driven only
## by signals: RoomZone.power_changed and ResourceManager.resource_changed
## (gold outline when the player can afford RoomZone.POWER_COST right now).

const LIGHT_TEXTURE_SIZE := 256

var config: MapVisualConfig
var _overlay: Polygon2D
var _afford_outline: Line2D
var _light: PointLight2D
var _pulse: Tween
var _powered: bool = false


func setup(zone: RoomZone, size_px: Vector2, p_config: MapVisualConfig) -> void:
	config = p_config
	var half := size_px / 2.0
	var points := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])

	_overlay = Polygon2D.new()
	_overlay.name = "DarkOverlay"
	_overlay.polygon = points
	_overlay.color = config.dark_overlay_color
	add_child(_overlay)

	_afford_outline = Line2D.new()
	_afford_outline.name = "AffordOutline"
	_afford_outline.points = PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	_afford_outline.width = 2.0
	_afford_outline.default_color = config.affordable_outline_color
	_afford_outline.visible = false
	add_child(_afford_outline)

	_light = PointLight2D.new()
	_light.name = "WarmLight"
	_light.texture = _make_light_texture()
	_light.texture_scale = maxf(size_px.x, size_px.y) / LIGHT_TEXTURE_SIZE * 1.2
	_light.color = config.warm_light_color
	_light.energy = 0.0
	_light.enabled = false
	add_child(_light)

	zone.power_changed.connect(_on_power_changed)
	var resources := ManagerLocator.get_resource_manager()
	if resources:
		resources.resource_changed.connect(_on_resource_changed)
		_on_resource_changed("dust", resources.get_resource("dust"), 0)
	_start_danger_pulse()


func is_dark() -> bool:
	return not _powered


func is_affordable_highlighted() -> bool:
	return _afford_outline.visible


func _on_power_changed(_zone_id: String, powered: bool) -> void:
	_powered = powered
	_afford_outline.visible = false
	if _pulse:
		_pulse.kill()
	var tween := create_tween().set_parallel()
	var t := config.power_transition_time
	if powered:
		_light.enabled = true
		tween.tween_property(_overlay, "color:a", 0.0, t)
		tween.tween_property(_light, "energy", config.warm_light_energy, t)
	else:
		tween.tween_property(_overlay, "color", config.dark_overlay_color, t)
		tween.tween_property(_light, "energy", 0.0, t)
		tween.chain().tween_callback(_on_darkened)


func _on_darkened() -> void:
	_light.enabled = false
	_start_danger_pulse()


func _on_resource_changed(key: String, amount: int, _delta: int) -> void:
	if key == "dust":
		_afford_outline.visible = not _powered and amount >= RoomZone.POWER_COST


func _start_danger_pulse() -> void:
	if not is_inside_tree():
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_overlay, "color", config.danger_overlay_color, config.danger_pulse_time).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_overlay, "color", config.dark_overlay_color, config.danger_pulse_time).set_trans(Tween.TRANS_SINE)


func _make_light_texture() -> GradientTexture2D:
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
	return texture

extends Node2D
class_name ExitIndicator

## ExitIndicator: shows where the floor exit is. Scene-instantiated per Main2d
## (group "exit_indicator"). Owns a world-space marker over the exit room
## (drawn above fog) and a screen-edge arrow on its own CanvasLayer (HUD
## layer) that points at the exit while it is off-camera.
##
## Visibility follows MapVisualConfig.exit_hint_mode; carrying the crystal
## (ExtractionManager EXTRACTION phase) always shows it, recolored and pulsing
## harder. State only changes on signals: config.changed,
## DoorTurnSystem.room_revealed, ExtractionManager.phase_changed. _process
## only places the arrow (the camera moves every frame).

const HUD_LAYER := 5
const MARKER_Z := 50

var room_manager: RoomManager
var config: MapVisualConfig
var exit_zone_id: String = ""

var _carrying: bool = false
var _hint_visible: bool = false
var _marker: Node2D
var _marker_shape: Polygon2D
var _marker_label: Label
var _arrow: Polygon2D
var _pulse: Tween


func _ready() -> void:
	add_to_group("exit_indicator")


func setup(p_room_manager: RoomManager, door_turn_system: DoorTurnSystem, extraction_manager: ExtractionManager) -> void:
	room_manager = p_room_manager
	config = room_manager.visual_config
	exit_zone_id = room_manager.get_exit_zone_id()
	if exit_zone_id == "":
		QuestLogger.warn(QuestLogger.Category.MAP, "ExitIndicator: layout has no exit room; indicator disabled.")
		set_process(false)
		return

	_build_marker(room_manager.get_center(exit_zone_id))
	_build_arrow()

	config.changed.connect(_refresh)
	door_turn_system.room_revealed.connect(func(_id: String, _cells: Array[Vector2i]): _refresh())
	if extraction_manager:
		extraction_manager.phase_changed.connect(_on_phase_changed)
	_refresh()


func is_hint_visible() -> bool:
	return _hint_visible


func is_emphasized() -> bool:
	return _hint_visible and _carrying


func _on_phase_changed(new_phase: ExtractionManager.Phase, _old_phase: ExtractionManager.Phase) -> void:
	_carrying = new_phase == ExtractionManager.Phase.EXTRACTION
	_refresh()


func _refresh() -> void:
	match config.exit_hint_mode:
		MapVisualConfig.ExitHintMode.ALWAYS:
			_hint_visible = true
		MapVisualConfig.ExitHintMode.ON_DISCOVERY:
			_hint_visible = _carrying or room_manager.is_zone_revealed(exit_zone_id)
		MapVisualConfig.ExitHintMode.ON_CRYSTAL:
			_hint_visible = _carrying

	var color := config.exit_crystal_color if _carrying else config.exit_color
	_marker.visible = _hint_visible
	_marker_shape.color = color
	_marker_label.modulate = color
	_marker_label.text = "¡SALIDA! Traé el Nexo" if _carrying else "SALIDA"
	_arrow.color = color
	_arrow.visible = false  # placed by _process
	set_process(_hint_visible)
	_restart_pulse()


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var screen_pos := viewport.get_canvas_transform() * _marker.global_position
	var rect := viewport.get_visible_rect().grow(-config.arrow_margin)
	if rect.has_point(screen_pos):
		_arrow.visible = false
		return
	_arrow.visible = true
	_arrow.position = edge_point(rect, screen_pos)
	_arrow.rotation = (screen_pos - rect.get_center()).angle()


## Where the ray from `rect`'s center toward `target` leaves `rect`.
static func edge_point(rect: Rect2, target: Vector2) -> Vector2:
	var center := rect.get_center()
	var dir := target - center
	if dir == Vector2.ZERO:
		return center
	var tx := INF if is_zero_approx(dir.x) else absf(rect.size.x / 2.0 / dir.x)
	var ty := INF if is_zero_approx(dir.y) else absf(rect.size.y / 2.0 / dir.y)
	return center + dir * minf(minf(tx, ty), 1.0)


func _restart_pulse() -> void:
	if _pulse:
		_pulse.kill()
	if not _hint_visible or not is_inside_tree():
		return
	var peak := 1.35 if _carrying else 1.12
	var period := 0.35 if _carrying else 0.9
	_pulse = create_tween().set_loops().set_parallel(false)
	_pulse.tween_property(_marker, "scale", Vector2.ONE * peak, period).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_arrow, "scale", Vector2.ONE * peak, period).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_marker, "scale", Vector2.ONE, period).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_arrow, "scale", Vector2.ONE, period).set_trans(Tween.TRANS_SINE)


func _build_marker(world_pos: Vector2) -> void:
	_marker = Node2D.new()
	_marker.name = "ExitMarker"
	_marker.z_index = MARKER_Z
	_marker.global_position = world_pos
	add_child(_marker)

	_marker_shape = Polygon2D.new()
	_marker_shape.polygon = PackedVector2Array([Vector2(0, -34), Vector2(24, 0), Vector2(0, 34), Vector2(-24, 0)])
	_marker.add_child(_marker_shape)

	_marker_label = Label.new()
	_marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker_label.position = Vector2(-120, 38)
	_marker_label.size = Vector2(240, 24)
	_marker.add_child(_marker_label)


func _build_arrow() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ExitArrowLayer"
	layer.layer = HUD_LAYER
	add_child(layer)
	_arrow = Polygon2D.new()
	_arrow.name = "ExitArrow"
	_arrow.polygon = PackedVector2Array([Vector2(26, 0), Vector2(-14, -18), Vector2(-6, 0), Vector2(-14, 18)])
	_arrow.visible = false
	layer.add_child(_arrow)

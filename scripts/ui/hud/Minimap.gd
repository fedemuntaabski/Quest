extends Control
class_name Minimap

## Minimap: HUD corner map drawn with _draw(). Revealed zones only (rooms
## filled, powered rooms gold, Rest/Loot/Elite with a corner square in
## MapVisualConfig.room_type_color), one dot per hero, exit marker only while
## ExitIndicator's hint is visible. Redraws on signals, never polls:
## DoorTurnSystem.room_revealed, RoomManager.room_power_changed,
## Player.zone_changed, ExitIndicator.hint_changed.
## Left-click moves the GameCamera there (and, being MOUSE_FILTER_STOP, the
## minimap also blocks camera edge scrolling while hovered).

const MAP_SIZE := Vector2(200, 150)
const PADDING := 8.0
const BG_COLOR := Color(0, 0, 0, 0.55)
const ROOM_COLOR := Color(0.55, 0.55, 0.6, 0.9)
const POWERED_COLOR := Color(1.0, 0.85, 0.4, 0.95)
const CORRIDOR_COLOR := Color(0.4, 0.4, 0.45, 0.9)
const HERO_COLOR := Color(0.3, 0.8, 1.0, 1.0)
## Room-type marker: corner square, this fraction of the room's short side.
const TYPE_MARKER_FRACTION := 0.45
const TYPE_MARKER_MIN := 8.0

const NEXO_ALERT_COLOR := Color(0.95, 0.2, 0.2)
## Enemies just appeared in a room: blinking orange ring for this long (real time).
const SPAWN_ALERT_COLOR := Color(1.0, 0.55, 0.1)
const SPAWN_ALERT_MSEC := 6000

var _room_manager: RoomManager
var _heroes: Array[Player] = []
var _exit_indicator: ExitIndicator
var _nexo: Nexo
var _bounds := Rect2i()
## zone_id -> Time.get_ticks_msec() when its spawn alert expires.
var _spawn_alerts: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = MAP_SIZE
	size = MAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_room_manager = ManagerLocator.get_room_manager()
	if _room_manager == null:
		QuestLogger.warn(QuestLogger.Category.UI, "Minimap: RoomManager not found; minimap disabled.")
		hide()
		return
	# Bounds over every zone (not just revealed) so the map never rescales.
	var first := true
	for zone_id in _room_manager.get_zone_ids():
		var rect: Rect2i = _room_manager.get_zone(zone_id)["rect"]
		_bounds = rect if first else _bounds.merge(rect)
		first = false

	if _room_manager.door_turn_system:
		_room_manager.door_turn_system.room_revealed.connect(func(_id: String, _cells: Array[Vector2i]): queue_redraw())
	_room_manager.room_power_changed.connect(func(_id: String, _on: bool): queue_redraw())
	_heroes = ManagerLocator.get_heroes()
	for hero in _heroes:
		hero.zone_changed.connect(func(_id: String): queue_redraw())
	_nexo = ManagerLocator.get_nexo()
	if _nexo:
		_nexo.under_attack_changed.connect(func(_active: bool): _update_process(); queue_redraw())
	var enemy_manager := ManagerLocator.get_enemy_manager()
	if enemy_manager:
		enemy_manager.enemies_appeared.connect(_on_enemies_appeared)
	set_process(false)
	_exit_indicator = ManagerLocator.get_exit_indicator()
	if _exit_indicator:
		_exit_indicator.hint_changed.connect(func(_v: bool): queue_redraw())


## Native tooltip: name + one-liner of the revealed room type under the mouse
## (RoomTypeVisual). Unrevealed rooms and plain ones give nothing (no spoilers).
func _get_tooltip(at_position: Vector2) -> String:
	if _room_manager == null or _bounds.size == Vector2i.ZERO:
		return ""
	var scale_px := _scale()
	var cell := Vector2i((Vector2(_bounds.position) + (at_position - _offset(scale_px)) / scale_px).floor())
	for zone_id in _room_manager.get_zone_ids():
		if _room_manager.get_zone_kind(zone_id) == "room" and _room_manager.get_zone(zone_id)["rect"].has_point(cell):
			return tooltip_for_zone(zone_id)
	return ""


func tooltip_for_zone(zone_id: String) -> String:
	if _room_manager == null or not _room_manager.is_zone_revealed(zone_id):
		return ""
	var visual := _room_manager.visual_config.room_type_visual(_room_manager.get_room_type(zone_id))
	if visual == null or visual.display_name == "" or visual.description == "":
		return ""
	return "%s: %s" % [visual.display_name, visual.description]


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var camera := get_viewport().get_camera_2d() as GameCamera
	if camera == null or _room_manager == null or _bounds.size == Vector2i.ZERO:
		return
	var scale_px := _scale()
	var cell: Vector2 = Vector2(_bounds.position) + (event.position - _offset(scale_px)) / scale_px
	camera.focus_on(GridUtils.cell_to_world(_room_manager.tilemap, Vector2i(cell.floor())))
	accept_event()


func _scale() -> float:
	var inner := size - Vector2.ONE * PADDING * 2.0
	return minf(inner.x / _bounds.size.x, inner.y / _bounds.size.y)


func _offset(scale_px: float) -> Vector2:
	var inner := size - Vector2.ONE * PADDING * 2.0
	return Vector2.ONE * PADDING + (inner - Vector2(_bounds.size) * scale_px) / 2.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	if _room_manager == null or _bounds.size == Vector2i.ZERO:
		return
	var scale_px := _scale()
	var offset := _offset(scale_px)

	for zone_id in _room_manager.get_zone_ids():
		if not _room_manager.is_zone_revealed(zone_id):
			continue
		var color := CORRIDOR_COLOR
		if _room_manager.get_zone_kind(zone_id) == "room":
			color = POWERED_COLOR if _room_manager.is_zone_powered(zone_id) else ROOM_COLOR
		var zone_rect := _to_map(_room_manager.get_zone(zone_id)["rect"], scale_px, offset)
		draw_rect(zone_rect, color)
		# Room type marker (RoomTypeVisual): corner square in the type color with
		# its icon on top, independent of power.
		var visual := _room_manager.visual_config.room_type_visual(_room_manager.get_room_type(zone_id))
		if visual and visual.show_marker:
			var side := maxf(TYPE_MARKER_MIN, minf(zone_rect.size.x, zone_rect.size.y) * TYPE_MARKER_FRACTION)
			var marker := Rect2(zone_rect.position, Vector2.ONE * side)
			draw_rect(marker, visual.color)
			if visual.icon:
				var fit := side / maxf(visual.icon.get_width(), visual.icon.get_height())
				draw_texture_rect(visual.icon, Rect2(marker.position, visual.icon.get_size() * fit), false)

	if _exit_indicator and _exit_indicator.is_hint_visible():
		var exit_id := _room_manager.get_exit_zone_id()
		var exit_rect := _to_map(_room_manager.get_zone(exit_id)["rect"], scale_px, offset)
		var cfg := _room_manager.visual_config
		draw_rect(exit_rect, cfg.exit_crystal_color if _exit_indicator.is_emphasized() else cfg.exit_color, false, 2.0)

	# Side by side (party order), so heroes sharing a zone stay readable.
	var radius := maxf(3.0, scale_px * 0.8)
	for i in _heroes.size():
		var hero := _heroes[i]
		if not is_instance_valid(hero) or hero.current_zone_id == "":
			continue
		var hero_rect := _to_map(_room_manager.get_zone(hero.current_zone_id)["rect"], scale_px, offset)
		draw_circle(hero_rect.get_center() + Vector2((i - (_heroes.size() - 1) * 0.5) * radius * 2.0, 0.0), radius, HERO_COLOR)

	# Nexo under attack: blinking red ring on the room (or carrier's room) it is in.
	if _nexo and _nexo.under_attack and (Time.get_ticks_msec() / 250) % 2 == 0:
		var nexo_zone := _nexo.get_target_zone(_room_manager)
		if nexo_zone != "" and _room_manager.is_zone_revealed(nexo_zone):
			var nexo_rect := _to_map(_room_manager.get_zone(nexo_zone)["rect"], scale_px, offset)
			draw_arc(nexo_rect.get_center(), radius * 2.2, 0.0, TAU, 24, NEXO_ALERT_COLOR, 2.0)

	# Enemies just spawned here: blinking orange ring on each room.
	if (Time.get_ticks_msec() / 250) % 2 == 0:
		for zone_id in _spawn_alerts:
			if _room_manager.is_zone_revealed(zone_id):
				var alert_rect := _to_map(_room_manager.get_zone(zone_id)["rect"], scale_px, offset)
				draw_arc(alert_rect.get_center(), radius * 2.8, 0.0, TAU, 24, SPAWN_ALERT_COLOR, 2.5)


func _on_enemies_appeared(zone_ids: Array[String], _count: int, _source: String) -> void:
	for zone_id in zone_ids:
		_spawn_alerts[zone_id] = Time.get_ticks_msec() + SPAWN_ALERT_MSEC
	_update_process()
	queue_redraw()


## Runs only while something blinks: the Nexo under attack or a live spawn alert.
func _update_process() -> void:
	set_process((_nexo != null and _nexo.under_attack) or not _spawn_alerts.is_empty())


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for zone_id in _spawn_alerts.keys():
		if _spawn_alerts[zone_id] <= now:
			_spawn_alerts.erase(zone_id)
	_update_process()
	queue_redraw()


func _to_map(rect: Rect2i, scale_px: float, offset: Vector2) -> Rect2:
	return Rect2(offset + Vector2(rect.position - _bounds.position) * scale_px, Vector2(rect.size) * scale_px)

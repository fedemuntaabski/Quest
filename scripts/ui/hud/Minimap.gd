extends Control
class_name Minimap

## Minimap: HUD corner map drawn with _draw(). Revealed zones only (rooms
## filled, powered rooms gold), hero dot, exit marker only while
## ExitIndicator's hint is visible. Redraws on signals, never polls:
## DoorTurnSystem.room_revealed, RoomManager.room_powered,
## Player.zone_changed, ExitIndicator.hint_changed.

const MAP_SIZE := Vector2(200, 150)
const PADDING := 8.0
const BG_COLOR := Color(0, 0, 0, 0.55)
const ROOM_COLOR := Color(0.55, 0.55, 0.6, 0.9)
const POWERED_COLOR := Color(1.0, 0.85, 0.4, 0.95)
const CORRIDOR_COLOR := Color(0.4, 0.4, 0.45, 0.9)
const HERO_COLOR := Color(0.3, 0.8, 1.0, 1.0)

var _room_manager: RoomManager
var _player: Player
var _exit_indicator: ExitIndicator
var _bounds := Rect2i()


func _ready() -> void:
	custom_minimum_size = MAP_SIZE
	size = MAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_room_manager.room_powered.connect(func(_id: String): queue_redraw())
	_player = ManagerLocator.get_player()
	if _player:
		_player.zone_changed.connect(func(_id: String): queue_redraw())
	_exit_indicator = ManagerLocator.get_exit_indicator()
	if _exit_indicator:
		_exit_indicator.hint_changed.connect(func(_v: bool): queue_redraw())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	if _room_manager == null or _bounds.size == Vector2i.ZERO:
		return
	var inner := size - Vector2.ONE * PADDING * 2.0
	var scale_px := minf(inner.x / _bounds.size.x, inner.y / _bounds.size.y)
	var offset := Vector2.ONE * PADDING + (inner - Vector2(_bounds.size) * scale_px) / 2.0

	for zone_id in _room_manager.get_zone_ids():
		if not _room_manager.is_zone_revealed(zone_id):
			continue
		var color := CORRIDOR_COLOR
		if _room_manager.get_zone_kind(zone_id) == "room":
			color = POWERED_COLOR if _room_manager.is_zone_powered(zone_id) else ROOM_COLOR
		draw_rect(_to_map(_room_manager.get_zone(zone_id)["rect"], scale_px, offset), color)

	if _exit_indicator and _exit_indicator.is_hint_visible():
		var exit_id := _room_manager.get_exit_zone_id()
		var exit_rect := _to_map(_room_manager.get_zone(exit_id)["rect"], scale_px, offset)
		var cfg := _room_manager.visual_config
		draw_rect(exit_rect, cfg.exit_crystal_color if _exit_indicator.is_emphasized() else cfg.exit_color, false, 2.0)

	if _player and _player.current_zone_id != "":
		var hero_rect := _to_map(_room_manager.get_zone(_player.current_zone_id)["rect"], scale_px, offset)
		draw_circle(hero_rect.get_center(), maxf(3.0, scale_px * 0.8), HERO_COLOR)


func _to_map(rect: Rect2i, scale_px: float, offset: Vector2) -> Rect2:
	return Rect2(offset + Vector2(rect.position - _bounds.position) * scale_px, Vector2(rect.size) * scale_px)

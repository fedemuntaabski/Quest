extends Camera2D
class_name GameCamera

## GameCamera: DotE-style free camera on Player.tscn's Camera2D. top_level, so
## it doesn't inherit the hero's transform: follows the hero until the player
## pans (move_* keys / screen edges), wheel zoom with smoothing, position
## clamped to the discovered rooms + margin, camera_recenter resumes following.
## Tunables live in CameraConfig. A new floor = a new Player → follows again.

@export var config: CameraConfig = preload("res://resources/camera/camera_config.tres")

var _hero: Node2D
var _room_manager: RoomManager
var _following := true
var _snap := true
var _target_zoom := 1.0
var _bounds := Rect2()


func _ready() -> void:
	top_level = true
	# Main2d is PROCESS_MODE_ALWAYS; the camera must freeze with pause/death/victory.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_hero = get_parent() as Node2D
	_target_zoom = zoom.x
	_room_manager = ManagerLocator.get_room_manager()
	if _room_manager and _room_manager.door_turn_system:
		_room_manager.door_turn_system.room_revealed.connect(func(_id: String, _cells: Array[Vector2i]): refresh_bounds())
	refresh_bounds()


func _process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down") + _edge_direction()
	if dir != Vector2.ZERO:
		_following = false
		global_position += dir.limit_length(1.0) * config.pan_speed * delta / zoom.x
	elif _following and _hero:
		global_position = _hero.global_position
	global_position = clamp_to_bounds(global_position)
	if _snap:
		_snap = false
		reset_smoothing()
	zoom = zoom.lerp(Vector2.ONE * _target_zoom, 1.0 - exp(-config.zoom_smoothing * delta))


func _unhandled_input(event: InputEvent) -> void:
	# Never set_input_as_handled here: the GUI already eats wheel events over
	# the HUD, and mouse clicks must still reach Area2D picking.
	if event.is_action_pressed("camera_recenter"):
		recenter()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_target_zoom(_target_zoom * config.zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_target_zoom(_target_zoom / config.zoom_step)


func set_target_zoom(value: float) -> void:
	_target_zoom = clampf(value, config.zoom_min, config.zoom_max)


func get_target_zoom() -> float:
	return _target_zoom


func recenter() -> void:
	_following = true


func is_following() -> bool:
	return _following


## Minimap click: look at `world_pos` and stop following.
func focus_on(world_pos: Vector2) -> void:
	_following = false
	global_position = clamp_to_bounds(world_pos)


func clamp_to_bounds(p: Vector2) -> Vector2:
	if not _bounds.has_area():
		return p
	return p.clamp(_bounds.position, _bounds.end)


## Discovered zones (room + corridor cells) in world space, grown by the margin.
func refresh_bounds() -> void:
	if _room_manager == null or _room_manager.tilemap == null:
		return
	var first := true
	for zone_id in _room_manager.get_zone_ids():
		if not _room_manager.is_zone_revealed(zone_id):
			continue
		var rect: Rect2i = _room_manager.get_zone(zone_id)["rect"]
		var a := GridUtils.cell_to_world(_room_manager.tilemap, rect.position)
		var b := GridUtils.cell_to_world(_room_manager.tilemap, rect.end - Vector2i.ONE)
		var world := Rect2(a, Vector2.ZERO).expand(b)
		_bounds = world if first else _bounds.merge(world)
		first = false
	if not first:
		_bounds = _bounds.grow(config.bounds_margin)


func get_bounds() -> Rect2:
	return _bounds


## Unit-ish direction from the mouse touching a screen edge; none over the HUD.
func _edge_direction() -> Vector2:
	if not config.edge_scroll_enabled:
		return Vector2.ZERO
	var vp := get_viewport()
	if vp.gui_get_hovered_control() != null:
		return Vector2.ZERO
	var size := vp.get_visible_rect().size
	var mouse := vp.get_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(mouse):
		return Vector2.ZERO  # cursor outside the window
	var m := config.edge_scroll_margin
	var dir := Vector2.ZERO
	if mouse.x <= m:
		dir.x = -1
	elif mouse.x >= size.x - m:
		dir.x = 1
	if mouse.y <= m:
		dir.y = -1
	elif mouse.y >= size.y - m:
		dir.y = 1
	return dir

extends Node
class_name RoomCameraController

## Hybrid camera controller: switches between ROOM and CORRIDOR modes dynamically
## ROOM mode: tight margins, room-centered framing
## CORRIDOR mode: expanded bounds, active player follow

# Preload camera mode classes for type resolution
const CameraMode_Room = preload("res://scripts/world/camera/CameraMode_Room.gd")
const CameraMode_Corridor = preload("res://scripts/world/camera/CameraMode_Corridor.gd")

@export var move_duration: float = 0.35
@export var initial_delay: float = 0.08
@export var margin_factor: float = 0.9
@export var min_zoom: float = 0.6
@export var max_zoom: float = 2.5

var dungeon: DungeonGenerator = null
var active_tween: Tween = null
var _has_initialized: bool = false

var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0

## Camera state modes
var current_mode: CameraMode = null
var room_mode: CameraMode_Room = null
var corridor_mode: CameraMode_Corridor = null
var _last_was_corridor: bool = false

# ─────────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────────
func setup(dg: DungeonGenerator) -> void:
	dungeon = dg
	
	# Initialize camera modes
	room_mode = CameraMode_Room.new(dungeon)
	corridor_mode = CameraMode_Corridor.new(dungeon)
	current_mode = room_mode  # Start in room mode by default

	if dungeon != null and not dungeon.room_changed.is_connected(Callable(self, "_on_room_changed")):
		dungeon.room_changed.connect(Callable(self, "_on_room_changed"))

	# Connect to visual feedback screen shake if present
	var vfs := get_tree().get_nodes_in_group("visual_feedback")
	if vfs.size() > 0:
		var vf := vfs[0]
		if not vf.is_connected("screen_shake", Callable(self, "_on_screen_shake")):
			vf.connect("screen_shake", Callable(self, "_on_screen_shake"))

	call_deferred("_sync_to_current_room")
	set_process(true)

# ─────────────────────────────────────────────
# INIT SYNC
# ─────────────────────────────────────────────
func _sync_to_current_room() -> void:
	if dungeon == null:
		return

	var player: CharacterBody2D = dungeon.get_spawned_player()
	if player == null:
		call_deferred("_sync_to_current_room")
		return

	var node: Node = player.get_node_or_null("Camera2D")
	if node == null:
		call_deferred("_sync_to_current_room")
		return

	var camera: Camera2D = node as Camera2D
	if camera == null:
		call_deferred("_sync_to_current_room")
		return

	if dungeon.active_room_id >= 0:
		_update_camera_for_room(dungeon.active_room_id, false)
		_has_initialized = true

# ─────────────────────────────────────────────
# EVENTOS
# ─────────────────────────────────────────────
func _on_room_changed(room_id: int) -> void:
	_update_camera_for_room(room_id, _has_initialized)
	_has_initialized = true

# ─────────────────────────────────────────────
# CORE
# ─────────────────────────────────────────────
func _update_camera_for_room(room_id: int, animate: bool) -> void:
	if dungeon == null:
		return

	if room_id < 0:
		return

	var room_info: Dictionary = dungeon.get_room_info(room_id)
	if room_info.is_empty():
		return

	var player: CharacterBody2D = dungeon.get_spawned_player()
	if player == null:
		return

	var node: Node = player.get_node_or_null("Camera2D")
	if node == null:
		return

	var camera: Camera2D = node as Camera2D
	if camera == null:
		return

	# Reset to room mode on room transition
	_switch_camera_mode(false)
	_last_was_corridor = false

	var room_rect: Rect2i = room_info["rect"]
	var center_cell: Vector2i = room_info["center_cell"]

	var target_pos: Vector2 = dungeon.grid_to_world_coords(center_cell)

	var room_size_px: Vector2 = Vector2(room_rect.size) * dungeon.tile_size
	if room_size_px.x <= 0.0 or room_size_px.y <= 0.0:
		return

	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var viewport_size: Vector2 = viewport_rect.size

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var zoom_x: float = viewport_size.x / room_size_px.x
	var zoom_y: float = viewport_size.y / room_size_px.y
	var base_zoom: float = (zoom_x + zoom_y) * 0.5

	var target_zoom_value: float = clamp(base_zoom * margin_factor, min_zoom, max_zoom)
	var zoom_vec: Vector2 = Vector2(target_zoom_value, target_zoom_value)

	var base_margin: float = 3.0  # Room base margin
	var margin_px: float = base_margin * dungeon.tile_size
	var room_world_pos: Vector2 = dungeon.grid_to_world_coords(room_rect.position)
	var room_world_end: Vector2 = dungeon.grid_to_world_coords(room_rect.end)

	camera.limit_left = int(room_world_pos.x - margin_px)
	camera.limit_top = int(room_world_pos.y - margin_px)
	camera.limit_right = int(room_world_end.x + margin_px)
	camera.limit_bottom = int(room_world_end.y + margin_px)
	camera.limit_smoothed = true

	_kill_tween()

	if not animate:
		camera.global_position = target_pos
		camera.zoom = zoom_vec
		return

	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_IN_OUT)

	if initial_delay > 0.0:
		active_tween.tween_interval(initial_delay)

	active_tween.set_parallel(true)
	active_tween.tween_property(camera, "global_position", target_pos, move_duration)
	active_tween.tween_property(camera, "zoom", zoom_vec, move_duration)

# ─────────────────────────────────────────────
# UTILS
# ─────────────────────────────────────────────
func _kill_tween() -> void:
	if active_tween != null:
		active_tween.kill()
		active_tween = null

func _is_player_in_corridor() -> bool:
	if dungeon == null:
		return false

	var player: CharacterBody2D = dungeon.get_spawned_player()
	if player == null:
		return false

	var player_grid: Vector2i = dungeon.world_to_grid_coords(player.global_position)

	# Check if player is within any room's bounds
	for room_info in dungeon.room_infos:
		var room_rect: Rect2i = room_info["rect"]
		if room_rect.has_point(player_grid):
			return false

	# If not in any room, player is in a corridor
	return true

# ─────────────────────────────────────────────
# MODE SWITCHING
# ─────────────────────────────────────────────
func _switch_camera_mode(to_corridor: bool) -> void:
	if current_mode != null:
		current_mode.exit()
	
	current_mode = corridor_mode as CameraMode if to_corridor else room_mode as CameraMode
	
	if current_mode != null:
		current_mode.enter()


func _on_screen_shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_timer = max(_shake_timer, duration)

func _process(_delta: float) -> void:
	if dungeon == null:
		return

	if dungeon.active_room_id < 0:
		return

	var player: CharacterBody2D = dungeon.get_spawned_player()
	if player == null:
		return

	var node: Node = player.get_node_or_null("Camera2D")
	if node == null:
		return

	var camera: Camera2D = node as Camera2D
	if camera == null:
		return

	# Detect current location (room or corridor)
	var in_corridor: bool = _is_player_in_corridor()
	
	# Switch modes if needed
	if in_corridor != _last_was_corridor:
		_switch_camera_mode(in_corridor)
		_last_was_corridor = in_corridor
	
	# Update camera via current mode
	if current_mode != null:
		current_mode.update_camera(player, camera, dungeon, _delta)

	# Apply screen shake overlay (subtle)
	if _shake_timer > 0.0:
		var shake_offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_intensity
		camera.global_position += shake_offset
		_shake_timer = max(0.0, _shake_timer - _delta)

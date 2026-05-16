extends Node
class_name RoomCameraController

@export var move_duration: float = 0.35
@export var initial_delay: float = 0.08
@export var margin_factor: float = 0.9
@export var min_zoom: float = 0.6
@export var max_zoom: float = 2.5
@export var room_margin_tiles: float = 3.0
@export var corridor_margin_tiles: float = 10.0

var dungeon: DungeonGenerator = null
var active_tween: Tween = null
var _has_initialized: bool = false

# ─────────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────────
func setup(dg: DungeonGenerator) -> void:
	dungeon = dg

	if dungeon != null and not dungeon.room_changed.is_connected(_on_room_changed):
		dungeon.room_changed.connect(_on_room_changed)

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

	var corridor_margin: float = dungeon.tile_size * 3.0
	var room_world_pos: Vector2 = dungeon.grid_to_world_coords(room_rect.position)
	var room_world_end: Vector2 = dungeon.grid_to_world_coords(room_rect.end)

	camera.limit_left = int(room_world_pos.x - corridor_margin)
	camera.limit_top = int(room_world_pos.y - corridor_margin)
	camera.limit_right = int(room_world_end.x + corridor_margin)
	camera.limit_bottom = int(room_world_end.y + corridor_margin)
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

	# Update camera bounds dynamically based on player location
	var room_info: Dictionary = dungeon.get_room_info(dungeon.active_room_id)
	if room_info.is_empty():
		return

	var room_rect: Rect2i = room_info["rect"]
	var room_world_pos: Vector2 = dungeon.grid_to_world_coords(room_rect.position)
	var room_world_end: Vector2 = dungeon.grid_to_world_coords(room_rect.end)

	var in_corridor: bool = _is_player_in_corridor()
	var margin: float = corridor_margin_tiles if in_corridor else room_margin_tiles
	var margin_px: float = margin * dungeon.tile_size

	camera.limit_left = int(room_world_pos.x - margin_px)
	camera.limit_top = int(room_world_pos.y - margin_px)
	camera.limit_right = int(room_world_end.x + margin_px)
	camera.limit_bottom = int(room_world_end.y + margin_px)

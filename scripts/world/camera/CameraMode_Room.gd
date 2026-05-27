extends CameraMode
class_name CameraMode_Room

## Room-focused camera mode: tight margins, gentle follow, room-centered framing
## Used when player is inside a room (detected via room bounds containment)

@export var base_margin_tiles: float = 3.0              ## Margin around room bounds (48px at 16px/tile)
@export var follow_smoothing_factor: float = 0.8        ## Multiplier on Camera2D smoothing speed (0.8 = 80% of default)
@export var margin_factor: float = 0.9                  ## Applied to calculated zoom
@export var min_zoom: float = 0.6
@export var max_zoom: float = 2.5

var dungeon: DungeonGenerator
var last_room_id: int = -1
var _was_camera_centered: bool = false


func _init(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon


func enter() -> void:
	## Entering room mode: reduce smoothing for more stable framing
	pass


func exit() -> void:
	## Leaving room mode
	pass


func update_camera(
	player: CharacterBody2D,
	camera: Camera2D,
	dg: DungeonGenerator,
	delta: float
) -> bool:
	if dg == null or player == null or camera == null:
		return false
	
	var room_id: int = dg.active_room_id
	if room_id < 0:
		return false
	
	var room_info: Dictionary = dg.get_room_layout_info(room_id)
	if room_info.is_empty():
		return false
	
	# ──── ROOM GEOMETRY ────
	var room_rect: Rect2i = room_info["rect"]
	var center_cell: Vector2i = room_info["center_cell"]
	var target_pos: Vector2 = dg.grid_to_world_coords(center_cell)
	
	# ──── ZOOM CALCULATION ────
	var room_size_px: Vector2 = Vector2(room_rect.size) * dg.tile_size
	if room_size_px.x <= 0.0 or room_size_px.y <= 0.0:
		return false
	
	var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
	var viewport_size: Vector2 = viewport_rect.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	
	# Average zoom of x and y to fit room
	var zoom_x: float = viewport_size.x / room_size_px.x
	var zoom_y: float = viewport_size.y / room_size_px.y
	var base_zoom: float = (zoom_x + zoom_y) * 0.5
	var target_zoom_value: float = clamp(base_zoom * margin_factor, min_zoom, max_zoom)
	var zoom_vec: Vector2 = Vector2(target_zoom_value, target_zoom_value)
	
	# ──── CAMERA LIMITS (Bounds) ────
	var margin_px: float = base_margin_tiles * dg.tile_size
	var room_world_pos: Vector2 = dg.grid_to_world_coords(room_rect.position)
	var room_world_end: Vector2 = dg.grid_to_world_coords(room_rect.end)
	
	camera.limit_left = int(room_world_pos.x - margin_px)
	camera.limit_top = int(room_world_pos.y - margin_px)
	camera.limit_right = int(room_world_end.x + margin_px)
	camera.limit_bottom = int(room_world_end.y + margin_px)
	camera.limit_smoothed = true
	
	# Room mode doesn't modify position/zoom per-frame (animation handled by controller)
	# Just ensures bounds stay tight around room center
	last_room_id = room_id
	return true

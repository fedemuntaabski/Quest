extends CameraMode
class_name CameraMode_Corridor

## Corridor-focused camera mode: expanded margins, active follow, prioritizes player visibility
## Used when player is traversing corridors between rooms

@export var base_margin_tiles: float = 10.0             ## Base margin for corridors
@export var margin_expansion_factor: float = 2.5        ## Multiplier applied to margin in corridors
@export var follow_smoothing_factor: float = 1.2        ## Multiplier on Camera2D smoothing speed (1.2 = 120% more responsive)
@export var margin_factor: float = 0.9                  ## Applied to calculated zoom
@export var min_zoom: float = 0.6
@export var max_zoom: float = 2.5

var dungeon: DungeonGenerator


func _init(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon


func enter() -> void:
	## Entering corridor mode: increase smoothing for active player follow
	pass


func exit() -> void:
	## Leaving corridor mode
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
	
	# In corridor mode, we expand bounds significantly around the adjacent room
	# to show more context while player traverses
	var room_rect: Rect2i = room_info["rect"]
	
	# ──── EXPANDED CORRIDOR BOUNDS ────
	var expanded_margin_px: float = base_margin_tiles * margin_expansion_factor * dg.tile_size
	var room_world_pos: Vector2 = dg.grid_to_world_coords(room_rect.position)
	var room_world_end: Vector2 = dg.grid_to_world_coords(room_rect.end)
	
	camera.limit_left = int(room_world_pos.x - expanded_margin_px)
	camera.limit_top = int(room_world_pos.y - expanded_margin_px)
	camera.limit_right = int(room_world_end.x + expanded_margin_px)
	camera.limit_bottom = int(room_world_end.y + expanded_margin_px)
	camera.limit_smoothed = true
	
	# Corridor mode: let Camera2D.position_smoothing follow player naturally
	# (player is already being followed by position_smoothing in Player scene)
	# We just ensure bounds are wide enough for comfortable traversal
	return true

extends CharacterBody2D
class_name PlayerMovement

# ─────────────────────────────────────────────
# GRID
# ─────────────────────────────────────────────
@export var tile_size: int = 16
@export var step_time: float = 0.12

var grid_pos: Vector2i
var target_world_pos: Vector2
var _start_pos: Vector2

var is_moving_step: bool = false
var step_timer: float = 0.0

var map_manager: MapManager
# ─────────────────────────────────────────────
# REFERENCES
# ─────────────────────────────────────────────
@onready var action_controller := $PlayerActionController

# ─────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")

	map_manager = get_parent() as MapManager
	if map_manager == null:
		push_error("PlayerMovement: el padre no es MapManager")
		return

	if action_controller:
		action_controller.setup(self, map_manager)


# ─────────────────────────────────────────────
# PUBLIC API (llamado por TurnManager)
# ─────────────────────────────────────────────
func request_move(dir: Vector2i) -> bool:
	if is_moving_step:
		return false

	if map_manager == null:
		return false

	var next := grid_pos + dir

	if not map_manager.is_walkable_cell(next):
		return false

	_start_move_to(next)
	return true

	print("PLAYER GRID:", grid_pos)
	print("NEXT CELL:", next)
	print("WALKABLE:", map_manager.is_walkable_cell(next))


# ─────────────────────────────────────────────
func _start_move_to(next: Vector2i) -> void:
	_start_pos = global_position
	grid_pos = next
	target_world_pos = map_manager.grid_to_world(next)

	is_moving_step = true
	step_timer = 0.0


# ─────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if action_controller:
		action_controller.process_input()

	_process_step_move(delta)


func _process_step_move(delta: float) -> void:
	if not is_moving_step:
		return

	step_timer += delta
	var t := step_timer / step_time
	t = clamp(t, 0.0, 1.0)

	global_position = _start_pos.lerp(target_world_pos, t)

	if t >= 1.0:
		global_position = target_world_pos
		is_moving_step = false

func sync_to_grid() -> void:
	if map_manager == null:
		map_manager = get_parent() as MapManager
	if map_manager == null:
		return

	grid_pos = map_manager.world_to_grid_coords(global_position)
	target_world_pos = global_position
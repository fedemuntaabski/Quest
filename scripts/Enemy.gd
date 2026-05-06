extends CharacterBody2D
class_name Enemy

signal enemy_defeated(enemy)

var map_manager: MapManager
var player: PlayerMovement
var grid_pos: Vector2i
var player_torch: PointLight2D 
var my_room_id: int = -1
var dungeon_generator: DungeonGenerator

var is_moving_step: bool = false
var step_timer: float = 0.0
var step_time: float = 0.12

var _start_pos: Vector2
var target_world_pos: Vector2

@onready var stats: CharacterStats = $Stats

func _ready():
	stats.died.connect(_on_died)

func setup(p_map: MapManager, p_player: PlayerMovement):
	map_manager = p_map
	player = p_player
	sync_to_grid()

func sync_to_grid():
	if map_manager:
		grid_pos = map_manager.world_to_grid_coords(global_position)

func take_turn(turn_manager):
	if map_manager == null or player == null:
		turn_manager.end_turn()
		return

	sync_to_grid()

	var path: Array[Vector2i] = map_manager.find_path(grid_pos, player.grid_pos)

	if path.size() > 1:
		var next_cell = path[1]
		_start_move_to(next_cell)

		await _wait_for_step()

	turn_manager.end_turn()

func _start_move_to(next: Vector2i) -> void:
	_start_pos = global_position
	grid_pos = next
	target_world_pos = map_manager.grid_to_world_coords(next)

	is_moving_step = true
	step_timer = 0.0

func _physics_process(delta: float) -> void:
	if not is_moving_step:
		return

	step_timer += delta
	var t := step_timer / step_time
	t = clamp(t, 0.0, 1.0)

	global_position = _start_pos.lerp(target_world_pos, t)

	if t >= 1.0:
		global_position = target_world_pos
		is_moving_step = false

func _wait_for_step() -> void:
	while is_moving_step:
		await get_tree().process_frame

func _on_died():
	enemy_defeated.emit(self)
	queue_free()
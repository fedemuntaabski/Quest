extends CharacterBody2D
class_name PlayerMovement

const BaseAction = preload("res://scripts/BaseAction.gd")
const MoveAction = preload("res://scripts/MoveAction.gd")
const CombatComponent = preload("res://scripts/CombatComponent.gd")

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
var current_path: Array[Vector2i] = []

var my_turn: bool = false
var turn_manager: TurnManager
var combat_component: CombatComponent

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
		action_controller.set_process_input(true)

	sync_to_grid()
	if map_manager:
		map_manager.register_actor(self, grid_pos, true)

	_ensure_combat_component()

	var player_stats := get_node_or_null("/root/PlayerStats") as PlayerStats
	var stats := get_node_or_null("Stats") as CharacterStats
	if player_stats and stats:
		player_stats.register(stats)

func _ensure_combat_component() -> void:
	var comp := get_node_or_null("CombatComponent") as CombatComponent
	if comp == null:
		comp = CombatComponent.new()
		comp.name = "CombatComponent"
		add_child(comp)

	var stats := get_node_or_null("Stats") as CharacterStats
	comp.setup(self, stats, map_manager)
	combat_component = comp


# ─────────────────────────────────────────────
# PUBLIC API (llamado por TurnManager)
# ─────────────────────────────────────────────
func request_move(dir: Vector2i) -> bool:
	if not my_turn:
		return false

	if is_moving_step:
		return false

	if map_manager == null:
		return false

	var next := grid_pos + dir

	var walkable := map_manager.is_walkable_cell(next)

	if not walkable:
		return false

	if turn_manager == null or turn_manager.action_queue == null:
		return false

	var action: BaseAction = MoveAction.new(self, map_manager, next, true)
	turn_manager.action_queue.queue_action(action)
	my_turn = false
	return true

# ─────────────────────────────────────────────
func _start_move_to(next: Vector2i) -> void:
	_start_pos = global_position
	grid_pos = next
	target_world_pos = map_manager.grid_to_world(next)

	is_moving_step = true
	step_timer = 0.0


# ─────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_process_step_move(delta)

	# 🔥 SOLO si es tu turno
	if my_turn and not is_moving_step and current_path.size() > 0:
		var next_cell: Vector2i = current_path.pop_front()
		var dir := next_cell - grid_pos
		request_move(dir)


		
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
	map_manager.update_actor_cell(self, grid_pos)

func set_path(path: Array[Vector2i]) -> void:
	current_path = path.duplicate()

	# remover el primer nodo si es la celda actual
	if current_path.size() > 0 and current_path[0] == grid_pos:
		current_path.pop_front()

func cancel_movement() -> void:
	current_path.clear()

func begin_turn(tm: TurnManager) -> void:
	turn_manager = tm
	my_turn = true

func begin_step_move(next: Vector2i) -> void:
	_start_move_to(next)

func wait_for_step() -> void:
	while is_moving_step:
		await get_tree().process_frame
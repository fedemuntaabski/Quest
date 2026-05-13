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

var turn_manager: TurnManager
var combat_component: CombatComponent
var _is_dead: bool = false

# ─────────────────────────────────────────────
# REFERENCES
# ─────────────────────────────────────────────
@onready var action_controller := $PlayerActionController
@onready var sprite: Sprite2D = $Sprite2D
@onready var stats: CharacterStats = $Stats
# ─────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")

	map_manager = get_parent() as MapManager
	if map_manager == null:
		push_error("PlayerMovement: el padre no es MapManager")
		return

	sync_to_grid()
	if map_manager:
		map_manager.register_actor(self, grid_pos, true)

	_ensure_combat_component()

	if action_controller:
		action_controller.setup(self, map_manager)
		action_controller.set_process_input(true)

	var player_stats := get_node_or_null("/root/PlayerStats") as PlayerStats
	var stats := get_node_or_null("Stats") as CharacterStats
	if player_stats and stats:
		player_stats.register(stats)

	_connect_game_state()

func _connect_game_state() -> void:
	var gsm := get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if gsm == null:
		call_deferred("_connect_game_state")
		return
	if not gsm.state_changed.is_connected(_on_game_state_changed):
		gsm.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: int, _old_state: int) -> void:
	if new_state != GameStateManager.State.ACTIVE:
		cancel_movement()

func _ensure_combat_component() -> void:
	var comp := get_node_or_null("CombatComponent") as CombatComponent
	if comp == null:
		comp = CombatComponent.new()
		comp.name = "CombatComponent"
		add_child(comp)

	var stats := get_node_or_null("Stats") as CharacterStats
	if stats == null:
		push_warning("PlayerMovement: Stats node missing during combat setup")
	comp.setup(self, stats, map_manager)
	combat_component = comp

func get_combat_component() -> CombatComponent:
	return combat_component


# ─────────────────────────────────────────────
# PUBLIC API (llamado por TurnManager)
# ─────────────────────────────────────────────
func request_move(dir: Vector2i) -> bool:
	if not can_accept_input():
		return false

	if is_moving_step:
		return false

	if map_manager == null:
		return false

	var next := grid_pos + dir

	var walkable := map_manager.is_walkable_cell_for_actor(next, self)

	if not walkable:
		return false

	if turn_manager == null or turn_manager.action_queue == null:
		return false

	var action: BaseAction = MoveAction.new(self, map_manager, next, false)
	turn_manager.action_queue.queue_action(action)
	return true

# ─────────────────────────────────────────────
func _start_move_to(next: Vector2i) -> void:
	_start_pos = global_position
	grid_pos = next
	target_world_pos = map_manager.grid_to_world(next)

	is_moving_step = true
	step_timer = 0.0
	
	# Safety timeout to prevent infinite hang if tween gets stuck
	var safety_tween := create_tween()
	safety_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	safety_tween.tween_callback(_force_step_complete).set_delay(step_time * 2.0)


# ─────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_process_step_move(delta)

	# 🔥 SOLO si es tu turno
	if can_accept_input() and not is_moving_step and current_path.size() > 0:
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
		_force_step_complete()

func _force_step_complete() -> void:
	if not is_moving_step:
		return
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

	var dungeon := map_manager.dungeon_generator if map_manager else null
	if dungeon and dungeon.room_system:
		dungeon.room_system.update_player_cell(grid_pos)

func set_path(path: Array[Vector2i]) -> void:
	current_path = path.duplicate()

	# remover el primer nodo si es la celda actual
	if current_path.size() > 0 and current_path[0] == grid_pos:
		current_path.pop_front()

func cancel_movement() -> void:
	current_path.clear()

func begin_turn(tm: TurnManager) -> void:
	turn_manager = tm
	if action_controller and action_controller.has_method("on_player_turn_started"):
		action_controller.on_player_turn_started()

func turn_interrupted() -> void:
	# Clear any pending movement when turn is interrupted (e.g., on death)
	cancel_movement()
	_is_dead = true

func is_turn_active() -> bool:
	if turn_manager == null:
		return false
	return turn_manager.current_actor == self

func can_accept_input() -> bool:
	var gsm := get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if gsm and not gsm.is_active():
		return false
	if not is_turn_active():
		return false
	if turn_manager and turn_manager.action_queue and turn_manager.action_queue.is_busy():
		return false
	return true

func begin_step_move(next: Vector2i) -> void:
	_start_move_to(next)

func show_damage(amount: int, crit: bool = false) -> void:
	_spawn_floating_text("-%d" % amount, Color(1, 0.4, 0.3), crit)

func show_miss() -> void:
	_spawn_floating_text("MISS", Color(0.9, 0.9, 0.9), false)

func _spawn_floating_text(text: String, color: Color, crit: bool) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 100
	label.position = Vector2(-12, -28)
	if crit:
		label.scale = Vector2(1.2, 1.2)
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -18), 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func wait_for_step() -> void:
	while is_moving_step:
		# Use a shorter timeout approach to prevent infinite hang
		await get_tree().create_timer(0.016, true, true).timeout
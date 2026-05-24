extends CharacterBody2D
class_name PlayerMovement

# Owns the player's grid movement, step animation, and turn-facing movement state.

# ─────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────
signal movement_started
signal movement_ended

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
var turn_bridge: PlayerMovementTurnBridge

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
	_ensure_turn_bridge()

	if action_controller:
		action_controller.setup(self, map_manager)
		action_controller.set_process_input(true)

	var player_stats := ManagerLocator.get_player_stats() as PlayerStats
	var player_stats_component := get_node_or_null("Stats") as CharacterStats
	if player_stats and player_stats_component:
		player_stats.register(player_stats_component)

	_connect_game_state()

func _ensure_turn_bridge() -> void:
	if turn_bridge == null:
		turn_bridge = PlayerMovementTurnBridge.new()
	turn_bridge.setup(self, map_manager)

func _connect_game_state() -> void:
	var gsm := get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if gsm == null:
		call_deferred("_connect_game_state")
		return
	if not gsm.state_changed.is_connected(_on_game_state_changed):
		gsm.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: int, _old_state: int) -> void:
	if turn_bridge:
		turn_bridge.on_game_state_changed(new_state, _old_state)

func _ensure_combat_component() -> void:
	var comp := get_node_or_null("CombatComponent") as CombatComponent
	if comp == null:
		comp = CombatComponent.new()
		comp.name = "CombatComponent"
		add_child(comp)

	var combat_stats := get_node_or_null("Stats") as CharacterStats
	if combat_stats == null:
		push_warning("PlayerMovement: Stats node missing during combat setup")
	comp.setup(self, combat_stats, map_manager)
	combat_component = comp

func get_combat_component() -> CombatComponent:
	return combat_component


# ─────────────────────────────────────────────
# PUBLIC API (llamado por TurnManager)
# ─────────────────────────────────────────────
func request_move(dir: Vector2i) -> bool:
	return turn_bridge.request_move(dir) if turn_bridge else false

# Path planning
func request_path_to_cell(target_cell: Vector2i) -> bool:
	if map_manager == null:
		return false

	var path: Array[Vector2i] = map_manager.find_path(grid_pos, target_cell, self)
	if path.is_empty():
		return false

	set_path(path)
	return true

func request_path_to_adjacent(target_cell: Vector2i) -> bool:
	if map_manager == null:
		return false

	var path: Array[Vector2i] = map_manager.find_path_to_adjacent(grid_pos, target_cell, self)
	if path.is_empty():
		return false

	set_path(path)
	return true

# ─────────────────────────────────────────────
func _start_move_to(next: Vector2i) -> void:
	_start_pos = global_position
	grid_pos = next
	target_world_pos = map_manager.grid_to_world(next)

	is_moving_step = true
	step_timer = 0.0
	
	# Emit signal: movement animation started
	movement_started.emit()
	
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
	if map_manager:
		map_manager.update_actor_cell(self, grid_pos)
	update_room_state_from_grid()
	
	# Emit signal: movement animation completed
	movement_ended.emit()

func sync_to_grid() -> void:
	if map_manager == null:
		map_manager = get_parent() as MapManager
	if map_manager == null:
		return

	grid_pos = map_manager.world_to_grid_coords(global_position)
	target_world_pos = global_position
	map_manager.update_actor_cell(self, grid_pos)

	update_room_state_from_grid()


func update_room_state_from_grid() -> void:
	if map_manager == null:
		return

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
	if turn_bridge:
		turn_bridge.begin_turn(tm)

func turn_interrupted() -> void:
	# Clear any pending movement when turn is interrupted (e.g., on death)
	cancel_movement()
	_is_dead = true

func is_turn_active() -> bool:
	if turn_manager == null:
		return false
	return turn_manager.current_actor == self

func can_accept_input() -> bool:
	return turn_bridge.can_accept_input() if turn_bridge else false

func begin_step_move(next: Vector2i) -> void:
	_start_move_to(next)

func show_damage(amount: int, crit: bool = false) -> void:
	_spawn_floating_text("-%d" % amount, QuestPalette.COMBAT_TEXT_DAMAGE, crit)

func show_miss() -> void:
	_spawn_floating_text("MISS", QuestPalette.COMBAT_TEXT_MISS, false)

func _spawn_floating_text(text: String, color: Color, crit: bool) -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text_from_host(self, text, color, crit, Vector2(-12, -28), 18.0, 0.5)
		return

	# If floating text manager is not available, skip creating ephemeral labels.
	# This enforces a single source of truth for floating text presentation.
	if not text_mgr:
		push_warning("FloatingTextManager not present - skipping floating text: %s" % text)
		return

func on_status_changed() -> void:
	var indicator := get_node_or_null("StatusIndicator")
	if indicator == null:
		return
	if not indicator.has_method("refresh_statuses"):
		return
	var status_component := get_node_or_null("StatusComponent") as StatusComponent
	var statuses := status_component.get_active_statuses() if status_component else {}
	indicator.refresh_statuses(statuses)

func wait_for_step() -> void:
	while is_moving_step:
		# Use a shorter timeout approach to prevent infinite hang
		await get_tree().create_timer(0.016, true, true).timeout

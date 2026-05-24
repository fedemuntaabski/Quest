extends CharacterBody2D
class_name Enemy

signal enemy_defeated(enemy)

@export var enemy_data: EnemyData

var map_manager: MapManager
var player: PlayerMovement
var grid_pos: Vector2i
var player_torch: PointLight2D 
var my_room_id: int = -1
var dungeon_generator: DungeonGenerator

var is_moving_step: bool = false
var step_timer: float = 0.0
var step_time: float = 0.12
var movement_points: int = 1

var _start_pos: Vector2
var target_world_pos: Vector2
var turn_manager: TurnManager
var combat_component: CombatComponent
var is_boss: bool = false


@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar


var _base_modulate: Color = Color(1, 1, 1, 1)
var stats: CharacterStats
var _target_tint: Color = QuestPalette.COMBAT_TARGET_TINT_DEFAULT
var is_tutorial_enemy: bool = false

const STANDARD_ENEMY_HP := 10
const STANDARD_ENEMY_STRENGTH := 1
const STANDARD_ENEMY_MAGIC := 0
const STANDARD_ENEMY_DEX := 0
const STANDARD_ENEMY_BASE_DAMAGE := 2

func _ready():
	stats = $Stats as CharacterStats

	stats.died.connect(_on_died)
	stats.hp_changed.connect(_on_hp_changed)
	if enemy_data:
		apply_enemy_data(enemy_data)
	else:
		_apply_standard_profile()

	if sprite:
		_base_modulate = sprite.modulate

	if health_bar:
		health_bar.visible = not is_tutorial_enemy
		health_bar.max_value = stats.max_hp
		health_bar.value = stats.current_hp

func setup(p_map: MapManager, p_player: PlayerMovement) -> void:
	map_manager = p_map
	player = p_player

	sync_to_grid()

	if map_manager:
		map_manager.register_actor(self, grid_pos, true)

	_ensure_combat_component()
	if enemy_data:
		_apply_combat_from_data(enemy_data)
	else:
		_apply_standard_combat_profile()

func _apply_standard_profile() -> void:
	EnemyProfileApplier.apply_standard_profile(stats)

func _apply_standard_combat_profile() -> void:
	EnemyProfileApplier.apply_standard_combat_profile(combat_component)

func _apply_combat_from_data(data: EnemyData) -> void:
	EnemyProfileApplier.apply_combat_from_data(combat_component, data)

func _ensure_combat_component() -> void:
	if stats == null:
		stats = get_node_or_null("Stats") as CharacterStats
		if stats == null:
			push_warning("Enemy: Stats node missing during combat setup")
			return

	var comp := get_node_or_null("CombatComponent") as CombatComponent
	if comp == null:
		comp = CombatComponent.new()
		comp.name = "CombatComponent"
		add_child(comp)

	comp.setup(self, stats, map_manager)
	combat_component = comp
	
	# Ensure StatusComponent exists
	_ensure_status_component()


func _ensure_status_component() -> void:
	var status_comp := get_node_or_null("StatusComponent") as StatusComponent
	if status_comp == null:
		status_comp = StatusComponent.new()
		status_comp.name = "StatusComponent"
		add_child(status_comp)
	
	if stats != null:
		status_comp.setup(stats)

func configure_profile(max_hp: int, base_damage: int, dex: int = 0, base_tint: Color = Color(0.7, 0.3, 0.9, 1.0), target_tint: Color = Color(1.0, 0.7, 1.0, 1.0)) -> void:
	# Public helper to customize enemy stats and visuals (used for special enemy types)
	if stats:
		stats.max_hp = max_hp
		stats.current_hp = max_hp
		stats.dexterity = dex
		stats.strength = 0
		stats.magic = 0
		stats.strength_mod = 0
		stats.magic_mod = 0
		stats.dexterity_mod = 0
		if health_bar:
			health_bar.max_value = stats.max_hp
			health_bar.value = stats.current_hp

	if combat_component:
		combat_component.base_damage = base_damage

	# Apply visual tint
	set_visual_tint(base_tint, target_tint)

func apply_enemy_data(data: EnemyData) -> void:
	enemy_data = data
	if enemy_data == null:
		return
	var applied := EnemyProfileApplier.apply_enemy_data(
		enemy_data,
		stats,
		sprite,
		health_bar,
		combat_component,
		Callable(self, "set_visual_tint"),
		Callable(self, "apply_tutorial_profile")
	)
	step_time = float(applied.get("step_time", step_time))
	movement_points = int(applied.get("movement_points", movement_points))

func get_reward_gold() -> int:
	if enemy_data:
		return max(0, enemy_data.reward_gold)
	return 5

func get_combat_component() -> CombatComponent:
	return combat_component

func sync_to_grid():
	if map_manager:
		grid_pos = map_manager.world_to_grid_coords(global_position)
		map_manager.update_actor_cell(self, grid_pos)

func begin_turn(tm: TurnManager) -> void:
	turn_manager = tm
	var decision := EnemyTurnPolicy.decide(self)
	match int(decision.get("decision", EnemyTurnPolicy.Decision.WAIT)):
		EnemyTurnPolicy.Decision.SKIP:
			_skip_turn(str(decision.get("reason", "")))
		EnemyTurnPolicy.Decision.ATTACK:
			var attack_target := decision.get("target", player) as Node
			_queue_attack_action(attack_target)
		EnemyTurnPolicy.Decision.MOVE:
			var next_cell := decision.get("next_cell", Vector2i.ZERO) as Vector2i
			_queue_move_action(next_cell)
		_:
			_queue_wait_action()

func _skip_turn(reason: String = "") -> void:
	if turn_manager == null:
		return
	print("[Enemy] _skip_turn: enemy=%s reason=%s" % [name, reason])
	# Defer to avoid nested turn-manager recursion within begin_turn()
	turn_manager.call_deferred("end_turn")

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

func wait_for_step() -> void:
	while is_moving_step:
		await get_tree().process_frame

func begin_step_move(next: Vector2i) -> void:
	_start_move_to(next)

func _queue_move_action(next_cell: Vector2i) -> void:
	if turn_manager == null or turn_manager.action_queue == null:
		return

	var snapshot: Dictionary = {}
	if map_manager and map_manager.occupancy_manager:
		snapshot["occ_version"] = map_manager.occupancy_manager.get_version()
	snapshot["owner_cell"] = grid_pos
	snapshot["target_cell"] = next_cell
	var action: BaseAction = MoveAction.new(self, map_manager, next_cell, false, snapshot)
	turn_manager.action_queue.queue_action(action)

func _queue_wait_action() -> void:
	if turn_manager == null or turn_manager.action_queue == null:
		return

	var action: BaseAction = WaitAction.new(self, null)
	turn_manager.action_queue.queue_action(action)

func _queue_attack_action(target: Node) -> void:
	if turn_manager == null or turn_manager.action_queue == null:
		return

	var snapshot: Dictionary = {}
	if map_manager and map_manager.occupancy_manager:
		snapshot["occ_version"] = map_manager.occupancy_manager.get_version()
	if map_manager:
		snapshot["target_cell"] = map_manager.get_actor_cell(target)
		snapshot["target_room_id"] = map_manager.get_actor_room_id(target)
	var action: BaseAction = AttackAction.new(combat_component, target, snapshot)
	turn_manager.action_queue.queue_action(action)

func _on_died():
	if map_manager:
		map_manager.unregister_actor(self)
	enemy_defeated.emit(self)
	queue_free()

func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	EnemyPresentationHelper.update_health_bar_on_hp_changed(health_bar, is_tutorial_enemy, current_hp, max_hp)

func set_targeted(active: bool) -> void:
	EnemyPresentationHelper.set_targeted_state(health_bar, sprite, active, _target_tint, _base_modulate)

func set_visual_tint(base_tint: Color, target_tint: Color = QuestPalette.COMBAT_TARGET_TINT_DEFAULT) -> void:
	_base_modulate = base_tint
	_target_tint = target_tint
	if sprite:
		sprite.modulate = _base_modulate

func apply_tutorial_profile() -> void:
	is_tutorial_enemy = true
	# Keep tutorial enemy in all default systems while making it forgiving.
	collision_layer = 4
	collision_mask = 0
	if health_bar:
		health_bar.visible = false

func show_damage(amount: int, crit: bool = false) -> void:
	EnemyPresentationHelper.show_damage_feedback(self, amount, crit)

func show_miss() -> void:
	EnemyPresentationHelper.show_miss_feedback(self)

func _spawn_floating_text(text: String, color: Color, crit: bool) -> void:
	EnemyPresentationHelper.spawn_floating_text(self, text, color, crit)

func on_status_changed() -> void:
	EnemyPresentationHelper.refresh_status_indicator(self)

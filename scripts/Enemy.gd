extends CharacterBody2D
class_name Enemy

const BaseAction = preload("res://scripts/BaseAction.gd")
const MoveAction = preload("res://scripts/MoveAction.gd")
const WaitAction = preload("res://scripts/WaitAction.gd")
const AttackAction = preload("res://scripts/AttackAction.gd")
const CombatComponent = preload("res://scripts/CombatComponent.gd")

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
var turn_manager: TurnManager
var combat_component: CombatComponent


@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar


var _base_modulate: Color = Color(1, 1, 1, 1)
var stats: CharacterStats

func _ready():
	stats = $Stats as CharacterStats

	stats.died.connect(_on_died)
	stats.hp_changed.connect(_on_hp_changed)

	if sprite:
		_base_modulate = sprite.modulate

	if health_bar:
		health_bar.visible = false
		health_bar.max_value = stats.max_hp
		health_bar.value = stats.current_hp

func setup(p_map: MapManager, p_player: PlayerMovement) -> void:
	await self.ready

	map_manager = p_map
	player = p_player

	sync_to_grid()

	if map_manager:
		map_manager.register_actor(self, grid_pos, true)

	_ensure_combat_component()

func _ensure_combat_component() -> void:
	print("ENEMY STATS ON SETUP: ", stats)
	var comp := get_node_or_null("CombatComponent") as CombatComponent
	if comp == null:
		comp = CombatComponent.new()
		comp.name = "CombatComponent"
		add_child(comp)

	if stats == null:
		stats = get_node_or_null("Stats") as CharacterStats
		if stats == null:
			push_warning("Enemy: Stats node missing during combat setup")

	comp.setup(self, stats, map_manager)
	combat_component = comp

func get_combat_component() -> CombatComponent:
	return combat_component

func sync_to_grid():
	if map_manager:
		grid_pos = map_manager.world_to_grid_coords(global_position)
		map_manager.update_actor_cell(self, grid_pos)

func begin_turn(tm: TurnManager) -> void:
	turn_manager = tm

	if map_manager == null or player == null:
		_queue_wait_action()
		return

	if dungeon_generator and dungeon_generator.active_room_id != my_room_id:
		_queue_wait_action()
		return

	sync_to_grid()

	if combat_component and combat_component.can_attack(player):
		_queue_attack_action(player)
		return

	var path: Array[Vector2i] = map_manager.find_path_to_adjacent(grid_pos, player.grid_pos, self)
	if path.size() > 1:
		var next_cell: Vector2i = path[1]
		_queue_move_action(next_cell)
		return

	_queue_wait_action()

func _start_move_to(next: Vector2i) -> void:
	_start_pos = global_position
	grid_pos = next
	target_world_pos = map_manager.grid_to_world_coords(next)

	is_moving_step = true
	step_timer = 0.0

func _physics_process(delta: float) -> void:
	if not is_moving_step:
		return
	print("ENEMY GRID: ", grid_pos)

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

	var action: BaseAction = MoveAction.new(self, map_manager, next_cell, true)
	turn_manager.action_queue.queue_action(action)

func _queue_wait_action() -> void:
	if turn_manager == null or turn_manager.action_queue == null:
		return

	var action: BaseAction = WaitAction.new(self, null)
	turn_manager.action_queue.queue_action(action)

func _queue_attack_action(target: Node) -> void:
	if turn_manager == null or turn_manager.action_queue == null:
		return

	var action: BaseAction = AttackAction.new(combat_component, target)
	turn_manager.action_queue.queue_action(action)

func _on_died():
	if map_manager:
		map_manager.unregister_actor(self)
	enemy_defeated.emit(self)
	queue_free()

func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
		health_bar.visible = true

func set_targeted(active: bool) -> void:
	if health_bar:
		health_bar.visible = active or health_bar.value < health_bar.max_value
	if sprite:
		if active:
			sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)
		else:
			sprite.modulate = _base_modulate

func show_damage(amount: int, crit: bool = false) -> void:
	_spawn_floating_text("-%d" % amount, Color(1, 0.2, 0.2), crit)

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

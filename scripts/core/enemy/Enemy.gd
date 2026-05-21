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

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar


var _base_modulate: Color = Color(1, 1, 1, 1)
var stats: CharacterStats
var _target_tint: Color = Color(1.0, 0.6, 0.6, 1.0)


func _ready():
	stats = get_node_or_null("Stats") as CharacterStats

	if stats == null:
		push_error("Enemy: Missing Stats node")
		return

	stats.died.connect(_on_died)
	stats.hp_changed.connect(_on_hp_changed)
	if enemy_data:
		apply_enemy_data(enemy_data)

	if sprite:
		_base_modulate = sprite.modulate

	if health_bar:
		health_bar.max_value = stats.max_hp
		health_bar.value = stats.current_hp

func setup(p_map: MapManager, p_player: PlayerMovement) -> void:
	map_manager = p_map
	player = p_player

	sync_to_grid()

	if map_manager:
		map_manager.register_actor(self, grid_pos, true)

	_ensure_combat_component()
	_hydrate_combat_from_data()

func get_enemy_data() -> EnemyData:
	return enemy_data

func _hydrate_combat_from_data() -> void:
	if combat_component == null or enemy_data == null:
		return

	if enemy_data.combat == null:
		return

	combat_component.base_damage = enemy_data.combat.base_damage
	combat_component.attack_range = max(1, enemy_data.combat.attack_range)
	combat_component.attack_stat = enemy_data.combat.attack_stat
	combat_component.forced_miss_chance = clampf(enemy_data.combat.forced_miss_chance, 0.0, 1.0)

func _hydrate_stats_from_data() -> void:
	if enemy_data == null or stats == null:
		return

	stats.character_name = enemy_data.enemy_name

	if enemy_data.stats == null:
		return

	stats.max_hp = max(1, enemy_data.stats.max_hp)
	stats.current_hp = stats.max_hp

	stats.strength = enemy_data.stats.strength
	stats.magic = enemy_data.stats.magic
	stats.dexterity = enemy_data.stats.dexterity

	stats.strength_mod = 0
	stats.magic_mod = 0
	stats.dexterity_mod = 0

	stats.hp_changed.emit(stats.current_hp, stats.max_hp)
	stats.stats_changed.emit()


func _hydrate_movement_from_data() -> void:
	if enemy_data == null:
		return

	if enemy_data.combat == null:
		return

	step_time = max(0.01, enemy_data.combat.move_step_time)
	movement_points = max(1, enemy_data.combat.movement)


func _hydrate_visuals_from_data() -> void:
	if enemy_data == null:
		return

	if enemy_data.visual == null:
		return

	if sprite and enemy_data.visual.sprite_texture:
		sprite.texture = enemy_data.visual.sprite_texture

	set_visual_tint(
		enemy_data.visual.base_tint,
		enemy_data.visual.target_tint
	)

	if health_bar and stats:
		health_bar.max_value = stats.max_hp
		health_bar.value = stats.current_hp

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

func apply_enemy_data(data: EnemyData) -> void:
	enemy_data = data

	if enemy_data == null:
		return

	_hydrate_stats_from_data()
	_hydrate_movement_from_data()
	_hydrate_visuals_from_data()
	_hydrate_combat_from_data()

func get_reward_gold() -> int:
	if enemy_data:
		return max(0, enemy_data.reward_gold)
	return 0
	
func is_boss_enemy() -> bool:
	return enemy_data != null and enemy_data.is_boss

func get_combat_component() -> CombatComponent:
	return combat_component

func sync_to_grid():
	if map_manager:
		grid_pos = map_manager.world_to_grid_coords(global_position)
		map_manager.update_actor_cell(self, grid_pos)

func begin_turn(tm: TurnManager) -> void:
	turn_manager = tm

	# Ensure canonical occupancy/room assignment before making decisions
	if map_manager and map_manager.core:
		map_manager.core.repair_actor_room(self)

	if stats and stats.is_alive():
		stats.process_runtime_modifiers_turn_start()
		var status_result := StatusRuntime.process_turn_start(self, stats)
		if status_result.get("can_act", true) != true:
			_queue_wait_action()
			return

	if map_manager == null or player == null:
		_queue_wait_action()
		return

	if combat_component == null or combat_component.stats == null:
		_queue_wait_action()
		return

	if dungeon_generator and dungeon_generator.active_room_id != my_room_id:
		_skip_turn("off_room")
		return

	sync_to_grid()

	if combat_component and combat_component.can_attack(player as Node):
		if map_manager and not map_manager.can_actors_engage(self, player as Node):
			_queue_wait_action()
			return
		_queue_attack_action(player as Node)
		return

	var path: Array[Vector2i] = map_manager.find_path_to_adjacent(grid_pos, player.grid_pos, self)
	if path.size() > 1:
		var next_cell: Vector2i = path[1]
		_queue_move_action(next_cell)
		return

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
	if health_bar == null:
		return	
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	health_bar.visible = true

func set_targeted(active: bool) -> void:
	if health_bar:
		health_bar.visible = active or health_bar.value < health_bar.max_value
	if sprite:
		if active:
			sprite.modulate = _target_tint
		else:
			sprite.modulate = _base_modulate

func set_visual_tint(base_tint: Color, target_tint: Color = Color(0.7, 1.0, 0.7, 1.0)) -> void:
	_base_modulate = base_tint
	_target_tint = target_tint
	if sprite:
		sprite.modulate = _base_modulate


func show_damage(amount: int, crit: bool = false) -> void:
	_spawn_floating_text("-%d" % amount, Color(1, 0.2, 0.2), crit)

	# Request visual feedback (damage flash, particles, hit pause, small shake)
	var vfs := get_tree().get_nodes_in_group("visual_feedback")
	if vfs.size() > 0:
		var vf := vfs[0]
		vf.request_damage_flash(self, Color(1, 0.9, 0.9), 0.12)
		vf.request_particles(global_position, Color(1.0, 0.6, 0.2), 6)
		vf.request_hit_pause(0.04, 0.18)
		vf.request_screen_shake(2.0, 0.12)

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

func on_status_changed() -> void:
	var indicator := get_node_or_null("StatusIndicator")
	if indicator and indicator.has_method("refresh_statuses"):
		var statuses := StatusRuntime._get_statuses(self)
		indicator.refresh_statuses(statuses)

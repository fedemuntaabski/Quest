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

# 🌟 NUEVO: Control de retraso para evitar que la animación de run se corte abruptamente
@export var idle_delay_time: float = 0.2
var _idle_delay_timer: float = 0.0

var _start_pos: Vector2
var target_world_pos: Vector2
var turn_manager: TurnManager
var combat_component: CombatComponent
var is_boss: bool = false

# 🌟 BÚSQUEDA INTELIGENTE: Asegura el enlace del nodo animado
@onready var sprite: AnimatedSprite2D = _find_animated_sprite()
@onready var health_bar: ProgressBar = $HealthBar

var _base_modulate: Color = Color(1, 1, 1, 1)
var stats: CharacterStats
var _target_tint: Color = QuestPalette.COMBAT_TARGET_TINT_DEFAULT
var is_tutorial_enemy: bool = false

# Estados internos de control para la máquina de animaciones
var _is_animating_attack: bool = false
var _is_dead: bool = false
var _is_targeted: bool = false
var _is_control_disabled: bool = false
var _is_brutal_cut_marked: bool = false

const CONTROL_DISABLED_TINT := Color(0.58, 0.76, 1.0, 1.0)
const BRUTAL_CUT_TINT := Color(0.95, 0.32, 0.42, 1.0)

const STANDARD_ENEMY_HP := 10
const STANDARD_ENEMY_STRENGTH := 1
const STANDARD_ENEMY_MAGIC := 0
const STANDARD_ENEMY_DEX := 0
const STANDARD_ENEMY_BASE_DAMAGE := 2

# Función auxiliar para forzar el enganche del AnimatedSprite2D en escenas heredadas
func _find_animated_sprite() -> AnimatedSprite2D:
	if has_node("AnimatedSprite2D"):
		return $AnimatedSprite2D as AnimatedSprite2D
	
	# Búsqueda de emergencia por tipo de clase en los nodos hijos
	for child in get_children():
		if child is AnimatedSprite2D:
			return child as AnimatedSprite2D
			
	push_warning("[Enemy Warning] No se detectó un nodo directo llamado 'AnimatedSprite2D' en: " + name)
	return null

func _ready():
	add_to_group("enemy")
	stats = $Stats as CharacterStats

	stats.died.connect(_on_died)
	stats.hp_changed.connect(_on_hp_changed)
	if enemy_data:
		apply_enemy_data(enemy_data)
	else:
		_apply_standard_profile()

	if sprite:
		_base_modulate = sprite.modulate
		# Conectamos la señal para saber cuándo termina un ataque o la muerte
		if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
			sprite.animation_finished.connect(_on_sprite_animation_finished)
		
		# 🌟 MODIFICADO: Forzar visibilidad y asegurar la reproducción inicial sin bucles
		sprite.visible = true
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.autoplay = "idle"
			sprite.play("idle")

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
	
	_ensure_status_component()

func _ensure_status_component() -> void:
	var status_comp := get_node_or_null("StatusComponent") as StatusComponent
	if status_comp == null:
		status_comp = StatusComponent.new()
		status_comp.name = "StatusComponent"
		add_child(status_comp)

	if status_comp and not status_comp.statuses_changed.is_connected(_on_statuses_changed):
		status_comp.statuses_changed.connect(_on_statuses_changed)

	_on_statuses_changed(status_comp.get_active_statuses())

func configure_profile(max_hp: int, base_damage: int, dex: int = 0, base_tint: Color = Color(0.7, 0.3, 0.9, 1.0), target_tint: Color = Color(1.0, 0.7, 1.0, 1.0)) -> void:
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
	if _is_dead: return 
	
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

func process_turn_end() -> void:
	if stats:
		stats.process_runtime_modifiers_turn_end()
	var status_component := get_node_or_null("StatusComponent") as StatusComponent
	if status_component != null and stats != null:
		status_component.process_turn_end()

func _skip_turn(reason: String = "") -> void:
	if turn_manager == null:
		return
	print("[Enemy] _skip_turn: enemy=%s reason=%s" % [name, reason])
	turn_manager.call_deferred("end_turn")

func _start_move_to(next: Vector2i) -> void:
	if sprite and next.x != grid_pos.x:
		if next.x < grid_pos.x:
			sprite.scale.x = -abs(sprite.scale.x)
			sprite.offset.x = enemy_data.extra_stats.get("offset_izq_idle", 4) if enemy_data else 4
		else:
			sprite.scale.x = abs(sprite.scale.x) 
			sprite.offset.x = 0

	_start_pos = global_position
	grid_pos = next
	target_world_pos = map_manager.grid_to_world_coords(next)

	is_moving_step = true
	step_timer = 0.0
	_idle_delay_timer = 0.0 # 🌟 RESET DELAY: Evita que se limpie la caminata a mitad de paso

func _physics_process(delta: float) -> void:
	# 🌟 MODIFICADO: Incremento consistente del temporizador si se frena
	if not is_moving_step:
		_idle_delay_timer += delta
	else:
		step_timer += delta
		var t := step_timer / step_time
		t = clamp(t, 0.0, 1.0)

		global_position = _start_pos.lerp(target_world_pos, t)

		if t >= 1.0:
			global_position = target_world_pos
			is_moving_step = false

	_update_animations()

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

# Protección de muerte contra nulos de sprite y recursos
func _on_died():
	if _is_dead: return
	_is_dead = true
	
	if map_manager:
		map_manager.unregister_actor(self)
	
	if health_bar:
		health_bar.visible = false
		
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		_finish_death_lifecycle()

# 🌟 MODIFICADO: Libera de forma segura la cola de acciones del TurnManager antes de destruirse
func _finish_death_lifecycle() -> void:
	if turn_manager:
		if turn_manager.has_method("end_turn"):
			turn_manager.call_deferred("end_turn")
			
	enemy_defeated.emit(self)
	queue_free()

func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	EnemyPresentationHelper.update_health_bar_on_hp_changed(health_bar, is_tutorial_enemy, current_hp, max_hp)

func set_targeted(active: bool) -> void:
	_is_targeted = active
	EnemyPresentationHelper.set_targeted_state(health_bar, sprite, active, _target_tint, _base_modulate)
	_refresh_visual_state()

func set_visual_tint(base_tint: Color, target_tint: Color = QuestPalette.COMBAT_TARGET_TINT_DEFAULT) -> void:
	# 🌟 MODIFICADO: Si el Alpha viene en 0 por error del archivo Resource (.tres), lo restauramos a visible
	if base_tint.a == 0:
		base_tint.a = 1.0
		
	_base_modulate = base_tint
	_target_tint = target_tint
	_refresh_visual_state()

func _on_statuses_changed(statuses: Dictionary) -> void:
	_is_control_disabled = false
	_is_brutal_cut_marked = false
	for status_id in statuses.keys():
		if str(status_id).to_lower() == "brutal_cut":
			_is_brutal_cut_marked = true
		if StatusComponent.status_skips_turn(str(status_id)):
			_is_control_disabled = true
			break

	_refresh_visual_state()

func _refresh_visual_state() -> void:
	if sprite == null:
		return

	var modulate_color := _base_modulate
	if _is_control_disabled:
		modulate_color = _base_modulate.lerp(CONTROL_DISABLED_TINT, 0.7)
	elif _is_brutal_cut_marked:
		modulate_color = _base_modulate.lerp(BRUTAL_CUT_TINT, 0.42)
	elif _is_targeted:
		modulate_color = _target_tint

	sprite.modulate = modulate_color
	sprite.visible = true

func apply_tutorial_profile() -> void:
	is_tutorial_enemy = true
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

# ─────────────────────────────────────────────
# 🌟 MÁQUINA DE ANIMACIONES PROTEGIDA DE EXCEPCIONES
# ─────────────────────────────────────────────
func _update_animations() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
		
	var frames: SpriteFrames = sprite.sprite_frames
		
	if _is_dead:
		if sprite.animation != "death" and frames.has_animation("death"):
			sprite.play("death")
		return
		
	if _is_animating_attack:
		if sprite.animation != "attack" and frames.has_animation("attack"):
			sprite.play("attack")
		return
		
	# 🌟 MODIFICADO: Control dinámico de caminata suavizada (Gracia de 0.5s)
	if is_moving_step:
		_idle_delay_timer = 0.0
		if sprite.animation != "run" and frames.has_animation("run"):
			sprite.play("run")
	else:
		if _idle_delay_timer >= idle_delay_time:
			if sprite.animation != "idle" and frames.has_animation("idle"):
				sprite.play("idle")
		else:
			# Conserva el estado dinámico "run" dentro de la ventana de amortiguación
			if sprite.animation != "run" and frames.has_animation("run"):
				sprite.play("run")

# Resguardos anti-null para la ejecución de ataques
func play_attack_animation() -> void:
	if _is_dead or sprite == null or sprite.sprite_frames == null: 
		return
		
	_is_animating_attack = true
	_idle_delay_timer = 0.0 # Reiniciamos el buffer al atacar
	if sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
		
		var frames_count = sprite.sprite_frames.get_frame_count("attack")
		var anim_fps = sprite.sprite_frames.get_animation_speed("attack")
		if anim_fps > 0:
			var duration = float(frames_count) / float(anim_fps)
			get_tree().create_timer(duration).timeout.connect(func():
				if sprite and sprite.animation == "attack":
					_is_animating_attack = false
			)
	else:
		_is_animating_attack = false

func _on_sprite_animation_finished() -> void:
	if sprite == null: return
	
	if sprite.animation == "attack":
		_is_animating_attack = false
	elif sprite.animation == "death":
		_finish_death_lifecycle()

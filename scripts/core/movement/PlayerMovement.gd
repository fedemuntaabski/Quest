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
# 🌟 CORRECCIÓN IDLE: Tiempo de espera para pasar a IDLE (0.5 segundos)
@export var idle_delay_time: float = 0.2 

var grid_pos: Vector2i
var target_world_pos: Vector2
var _start_pos: Vector2

var is_moving_step: bool = false
var step_timer: float = 0.0
# Temporizador interno para controlar el retraso del IDLE
var _idle_delay_timer: float = 0.0 

var map_manager: MapManager
var current_path: Array[Vector2i] = []

var turn_manager: TurnManager
var combat_component: CombatComponent
var _is_dead: bool = false
var turn_bridge: PlayerMovementTurnBridge

# 🌟 NUEVO: Estado interno para asegurar que la animación de ataque no sea interrumpida por idle/run
var _is_animating_attack: bool = false
var _is_control_disabled: bool = false
var _is_exposed_marked: bool = false
var _has_reflexes: bool = false
var _base_modulate: Color = Color(1, 1, 1, 1)

const CONTROL_DISABLED_TINT := Color(0.72, 0.76, 0.82, 1.0)
const EXPOSED_TINT := Color(1.0, 0.80, 0.38, 1.0)
const REFLEXES_TINT := Color(0.62, 0.76, 1.0, 1.0)

# ─────────────────────────────────────────────
# REFERENCES
# ─────────────────────────────────────────────
@onready var action_controller := $PlayerActionController
@onready var stats: CharacterStats = $Stats

# 🌟 REFERENCIA: Tu AnimatedSprite2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
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
	
	# 🌟 NUEVO: Conexión automática al sistema de salud para reproducir la muerte
	if stats:
		stats.died.connect(_on_player_died)
	
	# 🌟 NUEVO: Detectar cuándo termina el golpe o la muerte para devolver el control o congelar
	if sprite:
		_base_modulate = sprite.modulate
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	var status_component := get_node_or_null("StatusComponent") as StatusComponent
	if status_component and not status_component.statuses_changed.is_connected(_on_statuses_changed):
		status_component.statuses_changed.connect(_on_statuses_changed)
		_on_statuses_changed(status_component.get_active_statuses())

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
	if _is_dead: return false
	
	# 🌟 SOLUCIÓN ORIENTACIÓN Y DESFASE: Tu calibración manual mantenida de forma idéntica
	if sprite and dir.x != 0:
		if dir.x < 0:
			sprite.scale.x = -abs(sprite.scale.x) # Mira a la izquierda
			sprite.offset.x = 8                    # Tu desfase personalizado para centrar
		else:
			sprite.scale.x = abs(sprite.scale.x)  # Mira a la derecha
			sprite.offset.x = 0                     # Posición original
		
	return turn_bridge.request_move(dir) if turn_bridge else false

# Path planning
func request_path_to_cell(target_cell: Vector2i) -> bool:
	if _is_dead or map_manager == null:
		return false

	var path: Array[Vector2i] = map_manager.find_path(grid_pos, target_cell, self)
	if path.is_empty():
		return false

	set_path(path)
	return true

func request_path_to_adjacent(target_cell: Vector2i) -> bool:
	if _is_dead or map_manager == null:
		return false

	var path: Array[Vector2i] = map_manager.find_path_to_adjacent(grid_pos, target_cell, self)
	if path.is_empty():
		return false

	set_path(path)
	return true

# ─────────────────────────────────────────────
func _start_move_to(next: Vector2i) -> void:
	if _is_dead: return
	
	_start_pos = global_position
	grid_pos = next
	target_world_pos = map_manager.grid_to_world(next)

	is_moving_step = true
	step_timer = 0.0
	_idle_delay_timer = 0.0 
	
	# Emit signal: movement animation started
	movement_started.emit()
	
	# Safety timeout to prevent infinite hang if tween gets stuck
	var safety_tween := create_tween()
	safety_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	safety_tween.tween_callback(_force_step_complete).set_delay(step_time * 2.0)


# ─────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _is_dead:
		_update_animations(delta)
		return
		
	_process_step_move(delta)

	# 🔥 SOLO si es tu turno
	if can_accept_input() and not is_moving_step and current_path.size() > 0:
		var next_cell: Vector2i = current_path.pop_front()
		var dir := next_cell - grid_pos
		request_move(dir)

	# Control de animaciones con delta
	_update_animations(delta)


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
	if _is_dead: return
	current_path = path.duplicate()

	# remover el primer nodo si es la celda actual
	if current_path.size() > 0 and current_path[0] == grid_pos:
		current_path.pop_front()

func cancel_movement() -> void:
	current_path.clear()

func begin_turn(tm: TurnManager) -> void:
	if _is_dead: return
	if turn_bridge:
		turn_bridge.begin_turn(tm)

func process_turn_end() -> void:
	if stats:
		stats.process_runtime_modifiers_turn_end()
	var status_component := get_node_or_null("StatusComponent") as StatusComponent
	if status_component != null and stats != null:
		status_component.process_turn_end()

func _on_statuses_changed(statuses: Dictionary) -> void:
	_is_control_disabled = false
	_is_exposed_marked = false
	_has_reflexes = false
	for status_id in statuses.keys():
		if str(status_id).to_lower() == "exposed":
			_is_exposed_marked = true
		if str(status_id).to_lower() == "reflexes":
			_has_reflexes = true
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
	elif _is_exposed_marked:
		modulate_color = _base_modulate.lerp(EXPOSED_TINT, 0.42)
	elif _has_reflexes:
		modulate_color = _base_modulate.lerp(REFLEXES_TINT, 0.34)

	sprite.modulate = modulate_color
	sprite.visible = true

func turn_interrupted() -> void:
	cancel_movement()
	_is_dead = true

func is_turn_active() -> bool:
	if turn_manager == null:
		return false
	return turn_manager.current_actor == self

func can_accept_input() -> bool:
	if _is_dead: return false
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
		text_mgr.spawn_text_from_host(
	self,
	text,
	color,
	crit,
	Vector2(-12, -28),
	1.0
)
		return

	if not text_mgr:
		push_warning("FloatingTextManager not present - skipping floating text: %s" % text)
		return

func wait_for_step() -> void:
	while is_moving_step:
		await get_tree().create_timer(0.016, true, true).timeout

# 🌟 MODIFICADO: Escucha la muerte del nodo Stats o el colapso por tiempo
func _on_player_died() -> void:
	if _is_dead: return
	_is_dead = true
	
	cancel_movement()
	
	# Desactivamos controladores de inputs y físicas para congelar al PJ
	if action_controller:
		action_controller.set_process_input(false)
		
	# Desactivamos capas de colisión para evitar bloqueos/ataques fantasmas
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	
	# Forzamos la reproducción de muerte
	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")

# 🌟 CORREGIDO: Ejecuta el flujo seguro de muerte e inmovilización sin tocar variables de vida
func trigger_time_out_death() -> void:
	if _is_dead: return
	_on_player_died()

# ─────────────────────────────────────────────
# 🌟 SISTEMA DE ANIMACIONES CORREGIDO (CON SOPORTE DE ATAQUE Y MUERTE)
# ─────────────────────────────────────────────
func _update_animations(delta: float) -> void:
	if sprite == null:
		return
		
	# 0. Prioridad absoluta: Muerte
	if _is_dead:
		if sprite.animation != "death" and sprite.sprite_frames.has_animation("death"):
			sprite.play("death")
		return
		
	# 1. Si la acción de combate activó un ataque, congelamos el flujo aquí hasta que termine
	if _is_animating_attack:
		if sprite.animation != "attack":
			sprite.play("attack")
		return
		
	# 2. Control de movimiento y delay de quietud
	if is_moving_step:
		_idle_delay_timer = 0.0 
		if sprite.animation != "run":
			sprite.play("run")
	else:
		_idle_delay_timer += delta
		if _idle_delay_timer >= idle_delay_time:
			if sprite.animation != "idle":
				sprite.play("idle")
		else:
			# Mantiene la animación de run durante la ventana de espera de 0.5s
			if sprite.animation != "run":
				sprite.play("run")

# 🌟 MODIFICADO: Se ejecuta al finalizar el ataque o la animación de muerte (si loop está en false)
func _on_sprite_animation_finished() -> void:
	if sprite.animation == "attack":
		_is_animating_attack = false # Devuelve el control a los estados normales
	elif sprite.animation == "death":
		# Mantenemos el sprite congelado exactamente en el último frame de la caída
		sprite.stop()
		sprite.frame = sprite.sprite_frames.get_frame_count("death") - 1

# 🌟 NUEVO: Interfaz pública que llama AttackAction para iniciar la animación
func play_attack_animation() -> void:
	if _is_dead: return
	_is_animating_attack = true
	_idle_delay_timer = 0.0
	if sprite:
		sprite.play("attack")

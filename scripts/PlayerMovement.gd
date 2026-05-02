extends CharacterBody2D

class_name PlayerMovement

# ─────────────────────────────────────────────
# COMBAT / STATS
# ─────────────────────────────────────────────
@export var attack_damage: int = 3
@export var attack_cooldown: float = 0.5
@export var attack_range_px: float = 64.0
@export var shake_duration: float = 0.18
@export var shake_magnitude: float = 5.0


# ─────────────────────────────────────────────
# GRID SYSTEM
# ─────────────────────────────────────────────
var grid_pos: Vector2i
var target_world_pos: Vector2
var is_moving_step: bool = false
var step_timer: float = 0.0
var _start_pos: Vector2

@export var tile_size: int = 32
@export var step_time: float = 0.12

# ─────────────────────────────────────────────
# NODES
# ─────────────────────────────────────────────
@onready var camera: Camera2D = $Camera2D
@onready var attack_area: Area2D = $AttackArea
@onready var point_light: PointLight2D = $PointLight2D
@onready var player_stats = get_node("/root/PlayerStats")
@onready var map_manager: MapManager = get_node("/root/MapManager")

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────
var facing_direction: Vector2 = Vector2.RIGHT
var _attack_timer: float = 0.0
var _shake_timer: float = 0.0
var _shake_origin: Vector2 = Vector2.ZERO


# ─────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")

	if camera:
		_shake_origin = camera.offset

	# stats hook
	var stats_node := get_node_or_null("Stats") as CharacterStats
	if stats_node:
		var autoload = get_node_or_null("/root/PlayerStats")
		if autoload:
			if autoload.has_method("register"):
				autoload.register(stats_node)
			if not autoload.stats_changed.is_connected(_on_stats_changed):
				autoload.stats_changed.connect(_on_stats_changed)

	# init grid position
	grid_pos = Vector2i(
		int(global_position.x / tile_size),
		int(global_position.y / tile_size)
	)

	global_position = grid_pos * tile_size
	target_world_pos = global_position


# ─────────────────────────────────────────────
# GRID MOVEMENT (CALLED BY TURNMANAGER)
# ─────────────────────────────────────────────
func try_move(dir: Vector2i) -> void:
	
	if map_manager == null:
		return

	var next := grid_pos + dir

	if not map_manager.is_walkable_cell(next):
		return

	_start_pos = global_position

	grid_pos = next
	target_world_pos = map_manager.grid_to_world(next)

	is_moving_step = true
	step_timer = 0.0
	
	
# ─────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_process_step_move(delta)
	_process_shake(delta)


func _process_step_move(delta: float) -> void:
	if not is_moving_step:
		return

	step_timer += delta
	var t := step_timer / step_time
	t = clamp(t, 0.0, 1.0)

	var _start_pos: Vector2
	global_position = _start_pos.lerp(target_world_pos, t)
	

	if t >= 1.0:
		global_position = target_world_pos
		is_moving_step = false


# ─────────────────────────────────────────────
# ATTACK
# ─────────────────────────────────────────────
func _try_attack() -> void:
	if _attack_timer > 0.0:
		return
	_attack_timer = attack_cooldown

	if attack_area == null:
		return

	var overlapping := attack_area.get_overlapping_bodies()
	var hit_any := false
	var damage = attack_damage + GameManager.roll_dice_bonus()

	var hit_enemies := {}

	for body in overlapping:
		if body.is_in_group("enemy") and not hit_enemies.has(body):
			hit_enemies[body] = true

			if body.has_method("receive_hit"):
				body.receive_hit(damage)

			hit_any = true

	if hit_any:
		_trigger_screen_shake()

		# vampiric effect
		var autoload = player_stats
		if autoload:
			var heal_amount = 0
			for upg in autoload.active_upgrades:
				if upg.get("special", "") == "vampiric":
					heal_amount += 1

			if heal_amount > 0:
				var stats_node := get_node_or_null("Stats") as CharacterStats
				if stats_node:
					player_stats.apply_heal(heal_amount)


# ─────────────────────────────────────────────
# INPUT (AHORA SOLO ATAQUE → MOVIMIENTO LO MANEJA TURNMANAGER)
# ─────────────────────────────────────────────
func _handle_mouse_move(mouse_screen_pos: Vector2) -> void:
	if map_manager == null:
		return

	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var world_pos: Vector2 = cam.get_global_mouse_position()
	var target_cell: Vector2i = map_manager.world_to_grid(world_pos)

	var dir: Vector2i = target_cell - grid_pos

	# ToME style: solo 4 direcciones
	if abs(dir.x) > abs(dir.y):
		dir = Vector2i(sign(dir.x), 0)
	else:
		dir = Vector2i(0, sign(dir.y))

	if dir == Vector2i.ZERO:
		return

	var turn_manager := get_node_or_null("/root/TurnManager")
	if turn_manager:
		turn_manager.request_player_move(dir)
# ─────────────────────────────────────────────
# STATS
# ─────────────────────────────────────────────
func _on_stats_changed(_stats: CharacterStats) -> void:
	if not player_stats or not point_light:
		return

	var reach_count = 0
	for upg in player_stats.active_upgrades:
		if upg.get("special", "") == "arcane_reach":
			reach_count += 1

	point_light.texture_scale = 4.0 + (reach_count * 1.5)


# ─────────────────────────────────────────────
# SCREEN SHAKE
# ─────────────────────────────────────────────
func _trigger_screen_shake() -> void:
	_shake_timer = shake_duration


func _process_shake(delta: float) -> void:
	if camera == null:
		return

	if _shake_timer > 0.0:
		_shake_timer -= delta
		camera.offset = _shake_origin + Vector2(
			randf_range(-shake_magnitude, shake_magnitude),
			randf_range(-shake_magnitude, shake_magnitude)
		)
	else:
		camera.offset = _shake_origin
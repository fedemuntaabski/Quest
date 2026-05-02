extends CharacterBody2D

class_name PlayerMovement

@export var SPEED: float = 360.0
@export var attack_damage: int = 3
@export var attack_cooldown: float = 0.5
@export var attack_range_px: float = 64.0    # forward reach for hit detection
@export var shake_duration: float = 0.18
@export var shake_magnitude: float = 5.0

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var camera: Camera2D = $Camera2D
@onready var attack_area: Area2D = $AttackArea
@onready var point_light: PointLight2D = $PointLight2D
@onready var player_stats = get_node("/root/PlayerStats")

# ── Runtime ───────────────────────────────────────────────────────────────────
var facing_direction: Vector2 = Vector2.RIGHT
var _attack_timer: float = 0.0
var _shake_timer: float = 0.0
var _shake_origin: Vector2 = Vector2.ZERO

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	if camera:
		_shake_origin = camera.offset
	
	# Register stats with the autoload so UI can subscribe
	var stats_node := get_node_or_null("Stats") as CharacterStats
	if stats_node:
		var player_stats_autoload = get_node_or_null("/root/PlayerStats")
		if player_stats_autoload:
			if player_stats_autoload.has_method("register"):
				player_stats_autoload.register(stats_node)
			if not player_stats_autoload.stats_changed.is_connected(_on_stats_changed):
				player_stats_autoload.stats_changed.connect(_on_stats_changed)

func _on_stats_changed(_stats: CharacterStats) -> void:
	if not player_stats or not point_light:
		return
	
	var reach_count = 0
	for upg in player_stats.active_upgrades:
		if upg.get("special", "") == "arcane_reach":
			reach_count += 1
			
	point_light.texture_scale = 4.0 + (reach_count * 1.5)

# ─────────────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_process_movement()
	_process_shake(delta)

# ─────────────────────────────────────────────────────────────────────────────
func _process_movement() -> void:
	var input_direction := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_direction != Vector2.ZERO:
		velocity = input_direction.normalized() * SPEED
		facing_direction = input_direction.normalized()
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if is_on_wall() and get_slide_collision_count() > 0:
		var wall_collision := get_last_slide_collision()
		if wall_collision:
			velocity = velocity.slide(wall_collision.get_normal())

	# Reposition AttackArea in front of player
	if attack_area:
		attack_area.position = facing_direction * attack_range_px * 0.5

# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_try_attack()
		get_viewport().set_input_as_handled()

# ─────────────────────────────────────────────────────────────────────────────
func _try_attack() -> void:
	if _attack_timer > 0.0:
		return
	_attack_timer = attack_cooldown

	if attack_area == null:
		return

	var overlapping := attack_area.get_overlapping_bodies()
	var hit_any := false
	var damage = attack_damage + GameManager.roll_dice_bonus()


	if hit_any:
		_trigger_screen_shake()
		
		# Vampiric Strike logic
		var player_stats_autoload = player_stats
		if player_stats_autoload:
			var heal_amount = 0
			for upg in player_stats_autoload.active_upgrades:
				if upg.get("special", "") == "vampiric":
					heal_amount += 1
			if heal_amount > 0:
				var stats_node := get_node_or_null("Stats") as CharacterStats
				if stats_node:
					player_stats.apply_heal(heal_amount)
					

	var hit_enemies := {}

	for body in overlapping:
		if body.is_in_group("enemy") and not hit_enemies.has(body):
			hit_enemies[body] = true

			if body.has_method("receive_hit"):
				body.receive_hit(damage)

			hit_any = true

# ── Screen shake ──────────────────────────────────────────────────────────────
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

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
func _unhandled_input(event: InputEvent) -> void:
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

	for body in overlapping:
		if body is EnemyAI:
			var enemy := body as EnemyAI
			var is_backstab := _check_backstab(enemy)
			enemy.receive_hit(attack_damage + GameManager.roll_dice_bonus(), is_backstab)
			hit_any = true

	if hit_any:
		_trigger_screen_shake()

# ── Backstab detection ────────────────────────────────────────────────────────
# Returns true when player is behind the enemy (approaching from its rear)
func _check_backstab(enemy: EnemyAI) -> bool:
	# Enemy's facing is stored in enemy.facing_direction
	# If (player_pos - enemy_pos) is in the SAME direction as enemy_facing,
	# the player is behind the enemy (enemy is looking away).
	var to_player: Vector2 = (global_position - enemy.global_position).normalized()
	var dot: float = to_player.dot(enemy.facing_direction)
	return dot > 0.5   # player is roughly behind enemy

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

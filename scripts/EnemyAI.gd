extends CharacterBody2D

class_name EnemyAI

# ── Signals ──────────────────────────────────────────────────────────────────
signal enemy_defeated(enemy: EnemyAI)

# ── State machine ────────────────────────────────────────────────────────────
enum State { IDLE, CHASE, ATTACK }
var state: State = State.IDLE

# ── Exports ──────────────────────────────────────────────────────────────────
@export var move_speed: float = 110.0
@export var attack_damage: int = 2
@export var attack_cooldown: float = 1.2
@export var hearing_distance: float = 80.0
@export var nav_update_interval: float = 0.3

# ── Node references (resolved in _ready) ─────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var detection_range: Area2D = $DetectionRange
@onready var attack_range: Area2D = $AttackRange
@onready var health_bar: ProgressBar = $HealthBar
@onready var stats: CharacterStats = $Stats

# ── Runtime state ────────────────────────────────────────────────────────────
var player: CharacterBody2D = null          # set by DungeonGenerator after spawn
var player_torch: PointLight2D = null       # cached player torch node
var is_player_in_detection: bool = false
var is_player_in_attack: bool = false
var _attack_timer: float = 0.0
var _nav_timer: float = 0.0
var _dead: bool = false
var _original_modulate: Color = Color.WHITE
var facing_direction: Vector2 = Vector2.RIGHT   # track which way enemy faces
var _patrol_timer: float = 0.0

# ── Torch detection radius (world-space) ─────────────────────────────────────
# PointLight2D energy/texture_scale translates to roughly this world-unit radius
const TORCH_APPROX_RADIUS: float = 220.0

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemies")
	_original_modulate = sprite.modulate

	# Connect area signals
	detection_range.body_entered.connect(_on_detection_body_entered)
	detection_range.body_exited.connect(_on_detection_body_exited)
	attack_range.body_entered.connect(_on_attack_body_entered)
	attack_range.body_exited.connect(_on_attack_body_exited)

	# Health bar setup
	if health_bar:
		health_bar.min_value = 0
		health_bar.max_value = stats.max_hp if stats else 10
		health_bar.value = stats.current_hp if stats else 10
		health_bar.visible = false

	print("EnemyAI initialized: %s at %v" % [name, global_position])

# ─────────────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _dead:
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)

	match state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	# Sync health bar
	_sync_health_bar()

# ── IDLE / PATROL ─────────────────────────────────────────────────────────────
func _process_idle(delta: float) -> void:
	if _should_chase():
		_enter_state(State.CHASE)
		return
		
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_patrol_timer = randf_range(2.0, 5.0)
		# Pick a random patrol point nearby
		var random_offset = Vector2(randf_range(-150.0, 150.0), randf_range(-150.0, 150.0))
		nav_agent.target_position = global_position + random_offset

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		var next_pos: Vector2 = nav_agent.get_next_path_position()
		var direction: Vector2 = (next_pos - global_position)
		if direction.length_squared() > 1.0:
			direction = direction.normalized()
			facing_direction = direction
			velocity = direction * (move_speed * 0.4) # Walk slower when patrolling
		else:
			velocity = Vector2.ZERO

	move_and_slide()

# ── CHASE ─────────────────────────────────────────────────────────────────────
func _process_chase(delta: float) -> void:
	if not _should_chase():
		_enter_state(State.IDLE)
		return

	if is_player_in_attack:
		_enter_state(State.ATTACK)
		return

	if player == null:
		return

	# Update navigation target periodically
	_nav_timer -= delta
	if _nav_timer <= 0.0:
		_nav_timer = nav_update_interval
		nav_agent.target_position = player.global_position

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		var next_pos: Vector2 = nav_agent.get_next_path_position()
		var direction: Vector2 = (next_pos - global_position)
		if direction.length_squared() > 1.0:
			direction = direction.normalized()
			facing_direction = direction
			velocity = direction * move_speed
		else:
			velocity = Vector2.ZERO

	move_and_slide()

# ── ATTACK ────────────────────────────────────────────────────────────────────
func _process_attack(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

	if not is_player_in_attack:
		if _should_chase():
			_enter_state(State.CHASE)
		else:
			_enter_state(State.IDLE)
		return

	if _attack_timer <= 0.0:
		_do_attack()
		_attack_timer = attack_cooldown

# ─────────────────────────────────────────────────────────────────────────────
func _enter_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.CHASE:
			if health_bar:
				health_bar.visible = true
		State.IDLE:
			velocity = Vector2.ZERO

# ─────────────────────────────────────────────────────────────────────────────
# Stealth check: should enemy enter/remain in CHASE?
func _should_chase() -> bool:
	if player == null:
		return false

	# Hearing range — always triggers regardless of torch
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= hearing_distance:
		return true

	# Detection range + torch overlap check
	if is_player_in_detection and _is_torch_illuminating_self():
		return true

	return false

# Check if the player's torch light reaches this enemy
func _is_torch_illuminating_self() -> bool:
	if player_torch == null:
		return false
	if not is_instance_valid(player_torch):
		return false
	# Use torch energy as a proxy — if torch is off/very dim, no detection
	if player_torch.energy < 0.3:
		return false
	# Compare distance against approximate torch world radius
	var torch_world_pos: Vector2 = player_torch.global_position
	var dist: float = global_position.distance_to(torch_world_pos)
	var effective_radius: float = TORCH_APPROX_RADIUS * player_torch.texture_scale
	return dist <= effective_radius

# ─────────────────────────────────────────────────────────────────────────────
func _do_attack() -> void:
	if player == null or _dead:
		return
	var player_stats: CharacterStats = player.get_node_or_null("Stats") as CharacterStats
	if player_stats == null:
		return
		
	# Lunge animation (Tween)
	var original_pos = sprite.position
	var attack_dir = (player.global_position - global_position).normalized()
	
	var t = create_tween()
	t.tween_property(sprite, "position", original_pos + attack_dir * 20.0, 0.1).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func():
		if not _dead:
			player_stats.take_damage(attack_damage)
			print("EnemyAI [%s] lunges and attacks player for %d dmg. Player HP: %d/%d" % [
				name, attack_damage, player_stats.current_hp, player_stats.max_hp])
	)
	t.tween_property(sprite, "position", original_pos, 0.2).set_trans(Tween.TRANS_QUAD)

# ─────────────────────────────────────────────────────────────────────────────
## Called externally (from PlayerMovement) when this enemy is hit
func receive_hit(damage: int, is_backstab: bool) -> void:
	if _dead:
		return

	var final_damage := damage
	if is_backstab:
		final_damage = int(float(damage) * 1.5)
		print("EnemyAI [%s]: BACKSTAB! %d → %d dmg" % [name, damage, final_damage])
	else:
		print("EnemyAI [%s]: hit for %d dmg" % [name, final_damage])

	if stats:
		stats.take_damage(final_damage)

	# Always reveal health bar and show the enemy is hostile
	if health_bar:
		health_bar.visible = true

	# Flash white
	_flash_hit()

	# Aggro: switch to CHASE/ATTACK immediately
	if state == State.IDLE:
		_enter_state(State.CHASE)

	# Death check
	if stats and not stats.is_alive():
		_die()

# ─────────────────────────────────────────────────────────────────────────────
func _flash_hit() -> void:
	sprite.modulate = Color.WHITE
	var t := create_tween()
	t.tween_property(sprite, "modulate", _original_modulate, 0.12)

# ─────────────────────────────────────────────────────────────────────────────
func _die() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	if health_bar:
		health_bar.visible = false

	enemy_defeated.emit(self)
	print("EnemyAI [%s]: defeated." % name)

	# Shrink + fade out, then free
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK)
	t.tween_property(sprite, "modulate:a", 0.0, 0.30)
	t.chain().tween_callback(queue_free)

# ─────────────────────────────────────────────────────────────────────────────
func _sync_health_bar() -> void:
	if health_bar == null or stats == null:
		return
	health_bar.max_value = stats.max_hp
	health_bar.value = stats.current_hp

# ─────────────────────────────────────────────────────────────────────────────
# Area2D signal callbacks
func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_in_detection = true

func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_in_detection = false

func _on_attack_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_in_attack = true
		if state == State.CHASE:
			_enter_state(State.ATTACK)

func _on_attack_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_in_attack = false

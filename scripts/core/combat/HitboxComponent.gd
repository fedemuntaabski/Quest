extends Area2D
class_name HitboxComponent

## HitboxComponent: damages the HurtboxComponents overlapping it once per
## `hit_interval` seconds (DotE-style auto-combat — no aiming, no input).
## Targets are selected by collision_mask; with `single_target` (heroes since
## heroes-9) only the overlapping hurtbox nearest to the hitbox is hit, else all
## of them (enemy contact hits). `deliver` (optional) replaces the instant hit:
## ranged heroes use it to fire a Projectile that lands the hit on arrival.

signal hit_landed(target: HurtboxComponent, amount: int)

@export_group("Combat")
@export var damage: int = 1
@export var hit_interval: float = 1.0
## Hit only the nearest overlapping hurtbox per tick.
@export var single_target: bool = false

## func(hurtbox: HurtboxComponent, damage: int). When valid, called instead of
## receive_hit + hit_landed (the caller emits hit_landed itself on impact).
var deliver: Callable

@export_group("Feedback")
## Spawns a FloatingText over the target on every hit (via hit_landed).
@export var show_damage_numbers: bool = true
@export var damage_number_color: Color = Color(1.0, 0.85, 0.3, 1.0)
@export var damage_number_offset: Vector2 = Vector2(0, -28)

var _tick_timer: Timer = Timer.new()


func _ready() -> void:
	monitoring = true
	monitorable = false
	input_pickable = false
	_tick_timer.wait_time = hit_interval
	_tick_timer.one_shot = false
	_tick_timer.timeout.connect(_on_tick)
	if show_damage_numbers:
		hit_landed.connect(_on_hit_landed)
	add_child(_tick_timer)
	_tick_timer.start()


## Runtime (re)configuration from a data Resource/config after _ready().
func configure(p_damage: int, p_hit_interval: float) -> void:
	damage = p_damage
	hit_interval = maxf(p_hit_interval, 0.05)
	if is_node_ready():
		_tick_timer.wait_time = hit_interval


## Stops/resumes the attack ticks (a downed hero doesn't fight, heroes-9).
func set_active(active: bool) -> void:
	if active and _tick_timer.is_stopped():
		_tick_timer.start()
	elif not active:
		_tick_timer.stop()


func is_active() -> bool:
	return not _tick_timer.is_stopped()


func _on_tick() -> void:
	if not Net.is_authority():  # coop-12: damage is the host's
		return
	for hurtbox in pick_targets():
		if deliver.is_valid():
			deliver.call(hurtbox, damage)
			continue
		hurtbox.receive_hit(damage)
		hit_landed.emit(hurtbox, damage)


## Hurtboxes this tick will hit: every overlapping one, or only the nearest.
func pick_targets() -> Array[HurtboxComponent]:
	var targets: Array[HurtboxComponent] = []
	var best_dist := INF
	for area in get_overlapping_areas():
		var hurtbox := area as HurtboxComponent
		if hurtbox == null:
			continue
		if not single_target:
			targets.append(hurtbox)
			continue
		var dist := global_position.distance_squared_to(hurtbox.global_position)
		if dist < best_dist:
			best_dist = dist
			targets = [hurtbox]
	return targets


func _on_hit_landed(target: HurtboxComponent, amount: int) -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr and is_instance_valid(target):
		text_mgr.spawn_text(target.global_position + damage_number_offset, str(amount), damage_number_color)

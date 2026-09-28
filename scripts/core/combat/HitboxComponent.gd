extends Area2D
class_name HitboxComponent

## HitboxComponent: damages every HurtboxComponent overlapping it once per
## `hit_interval` seconds (DotE-style auto-combat — no aiming, no input).
## Targets are selected by collision_mask only; the hitbox never inspects
## what it hits beyond "is it a HurtboxComponent".

signal hit_landed(target: HurtboxComponent, amount: int)

@export_group("Combat")
@export var damage: int = 1
@export var hit_interval: float = 1.0

var _tick_timer: Timer = Timer.new()


func _ready() -> void:
	monitoring = true
	monitorable = false
	input_pickable = false
	_tick_timer.wait_time = hit_interval
	_tick_timer.one_shot = false
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	_tick_timer.start()


## Runtime (re)configuration from a data Resource/config after _ready().
func configure(p_damage: int, p_hit_interval: float) -> void:
	damage = p_damage
	hit_interval = maxf(p_hit_interval, 0.05)
	if is_node_ready():
		_tick_timer.wait_time = hit_interval


func _on_tick() -> void:
	for area in get_overlapping_areas():
		var hurtbox := area as HurtboxComponent
		if hurtbox == null:
			continue
		hurtbox.receive_hit(damage)
		hit_landed.emit(hurtbox, damage)

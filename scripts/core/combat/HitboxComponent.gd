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


func _on_tick() -> void:
	for area in get_overlapping_areas():
		var hurtbox := area as HurtboxComponent
		if hurtbox == null:
			continue
		hurtbox.receive_hit(damage)
		hit_landed.emit(hurtbox, damage)


func _on_hit_landed(target: HurtboxComponent, amount: int) -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr and is_instance_valid(target):
		text_mgr.spawn_text(target.global_position + damage_number_offset, str(amount), damage_number_color)

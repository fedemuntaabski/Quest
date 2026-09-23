extends Module
class_name TurretModule

## TurretModule: Minor module that shoots the first enemy inside its
## DetectionZone every `fire_rate` seconds. Enemies expose collision layer 2
## and the "enemies" group.

@export var damage: int = 15
@export var fire_rate: float = 1.0

@onready var detection_zone: Area2D = $DetectionZone
@onready var fire_timer: Timer = $FireTimer

var current_targets: Array[Node2D] = []


func _ready() -> void:
	super()
	detection_zone.body_entered.connect(_on_body_entered)
	detection_zone.body_exited.connect(_on_body_exited)
	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = false
	fire_timer.autostart = true
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	fire_timer.start()


func _on_body_entered(body: Node2D) -> void:
	if (body.is_in_group("enemies") or body.has_method("take_damage")) and not current_targets.has(body):
		current_targets.append(body)


func _on_body_exited(body: Node2D) -> void:
	current_targets.erase(body)


func _on_fire_timer_timeout() -> void:
	if not is_active:
		fire_timer.stop()
		return
	current_targets = current_targets.filter(func(t: Node2D) -> bool: return is_instance_valid(t))
	if current_targets.is_empty():
		return
	current_targets[0].take_damage(damage)

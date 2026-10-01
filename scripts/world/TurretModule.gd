extends Module
class_name TurretModule

## TurretModule: Minor module that shoots the first enemy inside its
## DetectionZone every `fire_rate` seconds. Enemies expose collision layer 2
## and the "enemies" group.

const TRAIL_COLOR := Color(0.7, 0.8, 1.0, 1.0)

@export var damage: int = 15
@export var fire_rate: float = 1.0

@onready var detection_zone: Area2D = $DetectionZone
@onready var fire_timer: Timer = $FireTimer

## Set by a hero ability (Sobrecarga de Módulo); 1.0 = none.
var damage_mult: float = 1.0
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


## Module.CATALOG is the single source for damage / fire rate (the exports are
## only fallbacks for a turret placed without configure()).
func configure(p_zone_id: String, p_module_type: ModuleType) -> void:
	super(p_zone_id, p_module_type)
	var cfg: Dictionary = CATALOG[p_module_type]
	damage = int(cfg["damage"])
	fire_rate = float(cfg["fire_rate"])
	fire_timer.wait_time = fire_rate


func _on_body_entered(body: Node2D) -> void:
	if (body.is_in_group("enemies") or body.has_method("take_damage")) and not current_targets.has(body):
		current_targets.append(body)


func _on_body_exited(body: Node2D) -> void:
	current_targets.erase(body)


func _on_fire_timer_timeout() -> void:
	if not is_working():
		fire_timer.stop()
		return
	current_targets = current_targets.filter(func(t: Node2D) -> bool: return is_instance_valid(t))
	if current_targets.is_empty():
		return
	var target := current_targets[0]
	var from := global_position
	var to := target.global_position
	target.take_damage(get_damage())
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"projectile_trail", from, TRAIL_COLOR, 0.0, to)
		vfx.play(&"hit_sparks", to, TRAIL_COLOR)


## Base damage + research bonus, read per shot (so it reaches built turrets).
func get_damage() -> int:
	var rm := ManagerLocator.get_resource_manager()
	return roundi((damage + (roundi(rm.get_bonus(ResearchEntry.Effect.TURRET_DAMAGE)) if rm else 0)) * damage_mult)

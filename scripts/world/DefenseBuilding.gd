extends Building
class_name DefenseBuilding

## DefenseBuilding: Minor building that shoots the first enemy inside its
## DetectionZone every `fire_rate` seconds. Enemies expose collision layer 2
## and the "enemies" group.

const TRAIL_COLOR := Color(0.7, 0.8, 1.0, 1.0)

@export var damage: int = 15
@export var fire_rate: float = 1.0

@onready var detection_zone: Area2D = $DetectionZone
@onready var fire_timer: Timer = $FireTimer

## Set by a hero ability (Bendición de las Obras); 1.0 = none.
var damage_mult: float = 1.0
## > 0 (Catapulta): the shot also hits enemies this close to the target.
var splash_radius: float = 0.0
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


## Building.CATALOG is the single source for damage / fire rate (the exports are
## only fallbacks for a defense placed without configure()).
func configure(p_zone_id: String, p_building_type: BuildingType) -> void:
	super(p_zone_id, p_building_type)
	var cfg: Dictionary = CATALOG[p_building_type]
	damage = int(cfg["damage"])
	fire_rate = float(cfg["fire_rate"])
	splash_radius = float(cfg.get("splash_radius", 0.0))
	fire_timer.wait_time = fire_rate


func _on_body_entered(body: Node2D) -> void:
	if (body.is_in_group("enemies") or body.has_method("take_damage")) and not current_targets.has(body):
		current_targets.append(body)


func _on_body_exited(body: Node2D) -> void:
	current_targets.erase(body)


func _on_fire_timer_timeout() -> void:
	if not is_working() or not Net.is_authority():
		return  # idle tick: the timer keeps running so re-lighting the room revives the defense
	current_targets = current_targets.filter(func(t: Variant) -> bool: return is_instance_valid(t))
	if current_targets.is_empty():
		return
	var target := current_targets[0]
	var from := global_position
	var to := target.global_position
	var hit := get_damage()
	_animate_shot(to)
	target.take_damage(hit)
	var audio := ManagerLocator.get_audio()
	if audio:
		audio.play_sfx(&"tower")
	if splash_radius > 0.0:
		for other in get_tree().get_nodes_in_group("enemies"):
			if other != target and is_instance_valid(other) and other.global_position.distance_to(to) <= splash_radius:
				other.take_damage(hit)
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"projectile_trail", from, TRAIL_COLOR, 0.0, to)
		vfx.play(&"hit_sparks", to, TRAIL_COLOR)


## personajes-46 (owner's request): the Defensa moves when it shoots, visual only (the art sprite of
## Building._apply_art): the Ballesta turns to the target (its art points up) and kicks back; the
## Catapulta winds its arm back and throws, facing the target. Host only, like the shot itself.
const AIM_SEC := 0.08
const KICK_PX := 4.0
var _shot_tween: Tween


func _animate_shot(to: Vector2) -> void:
	if art == null:
		return
	if _shot_tween and _shot_tween.is_valid():
		_shot_tween.kill()
	var dir := global_position.direction_to(to)
	var rest := Vector2(0.0, -10.0)
	art.position = rest
	_shot_tween = create_tween()
	if building_type == BuildingType.CATAPULTA:
		art.flip_h = dir.x < 0.0
		var side := -1.0 if art.flip_h else 1.0
		_shot_tween.tween_property(art, "rotation", -0.4 * side, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_shot_tween.tween_property(art, "rotation", 0.5 * side, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_shot_tween.tween_property(art, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		return
	var aim := wrapf(dir.angle() + PI * 0.5, art.rotation - PI, art.rotation + PI)  # shortest turn
	_shot_tween.tween_property(art, "rotation", aim, AIM_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shot_tween.tween_property(art, "position", rest - dir * KICK_PX, 0.04)
	_shot_tween.tween_property(art, "position", rest, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Base damage + research bonus, read per shot (so it reaches built defenses).
func get_damage() -> int:
	var rm := ManagerLocator.get_resource_manager()
	return roundi((damage + (roundi(rm.get_bonus(ResearchEntry.Effect.DEFENSE_DAMAGE)) if rm else 0)) * damage_mult)

extends Node2D
class_name VisualFeedback

signal screen_shake(intensity: float, duration: float)

const VisualParticleScene := preload("res://scenes/VisualParticle.tscn")

@export var particle_count: int = 6
@export var particle_lifetime: float = 0.45
@export var damage_flash_duration: float = 0.12
@export var hit_pause_duration: float = 0.04
@export var hit_pause_scale: float = 0.18

var _hit_pause_stack: int = 0
var _prev_time_scale: float = 1.0


func _ready() -> void:
	add_to_group("visual_feedback")


# =========================================================
# 💥 DAMAGE FLASH
# =========================================================
func request_damage_flash(target: Node, color: Color, duration: float = -1.0) -> void:
	if duration <= 0.0:
		duration = damage_flash_duration

	var sprite := _find_sprite(target)
	if sprite == null:
		return

	var original := sprite.modulate
	sprite.modulate = color

	var tw := create_tween()
	tw.tween_property(sprite, "modulate", original, duration)


# =========================================================
# ✨ PARTICLES (MEJORADAS)
# =========================================================
func request_particles(
	pos: Vector2,
	color: Color,
	count: int = -1,
	intensity: float = 1.0,
	direction: Vector2 = Vector2.ZERO
) -> void:

	if count <= 0:
		count = int(particle_count * intensity)

	for i in range(count):
		var particle := VisualParticleScene.instantiate() as VisualParticle
		if particle == null:
			continue

		var offset := Vector2(randf_range(-8, 8), randf_range(-8, 8))
		particle.position = pos + offset

		add_child(particle)

		var size := Vector2.ONE * randf_range(4, 10) * intensity

		particle.setup(
			color,
			size,
			particle_lifetime,
			0.0,
			intensity,
			direction
		)


# =========================================================
# 🧠 COMBAT EVENT ENTRY (CLAVE MEJORA)
# =========================================================
func request_combat_feedback(
	pos: Vector2,
	color: Color,
	damage: float = 1.0,
	is_crit: bool = false,
	element: String = "physical",
	direction: Vector2 = Vector2.ZERO
) -> void:

	var intensity = clamp(damage / 10.0, 0.5, 2.5)

	# Crit (tu sistema de dado)
	if is_crit:
		intensity *= 1.8
		request_screen_shake(4.0, 0.15)

	# Mapeo simple por “elemento/juego”
	match element:
		"ice":
			color = Color(0.4, 0.7, 1.0)
			intensity *= 0.9
		"bleed":
			color = Color(0.8, 0.1, 0.1)
			intensity *= 0.8
		"magic":
			color = Color(0.6, 0.3, 1.0)
		_:
			pass

	request_particles(pos, color, -1, intensity, direction)


# =========================================================
# ⏱️ HIT PAUSE
# =========================================================
func request_hit_pause(duration: float = -1.0, timescale: float = -1.0) -> void:
	if duration <= 0.0:
		duration = hit_pause_duration
	if timescale <= 0.0:
		timescale = hit_pause_scale

	if _hit_pause_stack == 0:
		_prev_time_scale = Engine.time_scale
		Engine.time_scale = timescale

	_hit_pause_stack += 1

	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(_on_hit_pause_restore)


func _on_hit_pause_restore() -> void:
	_hit_pause_stack -= 1
	if _hit_pause_stack <= 0:
		Engine.time_scale = _prev_time_scale
		_hit_pause_stack = 0


# =========================================================
# 📺 SCREEN SHAKE
# =========================================================
func request_screen_shake(intensity: float = 2.0, duration: float = 0.12) -> void:
	emit_signal("screen_shake", intensity, duration)


# =========================================================
# 🔍 SPRITE FINDER
# =========================================================
func _find_sprite(target: Node) -> CanvasItem:
	if target == null:
		return null

	if target is CanvasItem:
		var s := target.get_node_or_null("Sprite2D")
		if s and s is CanvasItem:
			return s

		for child in target.get_children():
			if child is CanvasItem:
				return child

		return target as CanvasItem

	return null

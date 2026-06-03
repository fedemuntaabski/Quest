extends Node2D
class_name VisualFeedback

signal screen_shake(intensity: float, duration: float)

const VisualParticleScene := preload("res://scenes/VisualParticle.tscn")

enum FeedbackType {
	HIT,
	CRIT,
	HEAL,
	EXPLOSION
}

@export var particle_count: int = 6
@export var particle_lifetime: float = 0.45

@export var hit_pause_duration: float = 0.03
@export var hit_pause_scale: float = 0.25

var _hit_pause_stack: int = 0
var _prev_time_scale: float = 1.0
var _shake_accum: float = 0.0


func _ready() -> void:
	add_to_group("visual_feedback")


# -------------------------
# DAMAGE FLASH
# -------------------------
func request_damage_flash(target: Node, color: Color, duration: float = 0.12) -> void:
	var sprite := _find_sprite(target)
	if sprite == null:
		return

	var original := sprite.modulate
	sprite.modulate = color

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate", original, duration)


# -------------------------
# PARTICLES
# -------------------------
func request_particles(pos: Vector2, color: Color, type: FeedbackType = FeedbackType.HIT, count: int = -1) -> void:
	if count <= 0:
		count = particle_count

	for i in range(count):
		var particle := VisualParticleScene.instantiate() as VisualParticle
		if particle == null:
			continue

		particle.position = pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		add_child(particle)

		var size := Vector2.ONE * randi_range(4, 10)

		match type:
			FeedbackType.HIT:
				particle.setup(Color(1, 0.2, 0.2), size, particle_lifetime, 6)

			FeedbackType.CRIT:
				particle.setup(Color(1, 0.1, 0.1), size * 1.3, particle_lifetime * 1.2, 14)

			FeedbackType.HEAL:
				particle.setup(Color(0.2, 1, 0.3), size, particle_lifetime, 10)

			FeedbackType.EXPLOSION:
				particle.setup(Color(1, 0.6, 0.1), size * 1.6, particle_lifetime * 0.8, 2)


# -------------------------
# HIT PAUSE (menos agresivo)
# -------------------------
func request_hit_pause(duration: float = -1.0, timescale: float = -1.0) -> void:
	if duration <= 0.0:
		duration = hit_pause_duration

	if timescale <= 0.0:
		timescale = hit_pause_scale

	if _hit_pause_stack == 0:
		_prev_time_scale = Engine.time_scale
		Engine.time_scale = timescale

	_hit_pause_stack += 1

	var timer := get_tree().create_timer(duration / max(Engine.time_scale, 0.01))
	timer.timeout.connect(_on_hit_pause_restore)


func _on_hit_pause_restore() -> void:
	_hit_pause_stack -= 1

	if _hit_pause_stack <= 0:
		Engine.time_scale = _prev_time_scale
		_hit_pause_stack = 0


# -------------------------
# SCREEN SHAKE
# -------------------------
func request_screen_shake(intensity: float = 2.0, duration: float = 0.12) -> void:
	_shake_accum += intensity
	emit_signal("screen_shake", _shake_accum, duration)

	var tw := create_tween()
	tw.tween_property(self, "_shake_accum", 0.0, duration)


# -------------------------
# SPRITE FINDER
# -------------------------
func _find_sprite(target: Node) -> CanvasItem:
	if target == null:
		return null

	if target is CanvasItem:
		for child in target.get_children():
			if child is Sprite2D or child is TextureRect:
				return child

		return target as CanvasItem

	return null
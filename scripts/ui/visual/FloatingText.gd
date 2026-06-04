extends Node2D
class_name FloatingText

@export var float_distance: float = 18.0
@export var float_time: float = 0.6
@export var base_scale: float = 1.0
@export var heal_float_time: float = 1.05
@export var heal_float_distance: float = 22.0

@onready var label: Label = $Label

var _is_healing: bool = false


func setup(
	text: String,
	color: Color,
	crit: bool = false,
	intensity: float = 1.0,
	healing: bool = false
) -> void:
	z_index = 100
	_is_healing = healing

	if label:
		label.text = text
		label.modulate = color

		if healing:
			label.scale = Vector2(1.12, 1.12)
		elif crit:
			label.scale = Vector2(1.25, 1.25)
		else:
			label.scale = Vector2.ONE

	var scale_multiplier := intensity
	if healing:
		scale_multiplier *= 1.15

	scale = Vector2.ONE * clamp(base_scale * scale_multiplier, 0.8, 2.5)

	_play_float_animation()


func _play_float_animation() -> void:
	var jitter := Vector2(randf_range(-4, 4), 0)
	var duration := heal_float_time if _is_healing else float_time
	var distance := heal_float_distance if _is_healing else float_distance
	var target_pos := global_position + Vector2(0, -distance) + jitter

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "global_position", target_pos, duration)

	if _is_healing:
		var fade_delay := duration * 0.35
		var fade_duration := duration - fade_delay
		tween.parallel().tween_property(label, "modulate:a", 0.0, fade_duration).set_delay(fade_delay)
		var end_scale := scale * 0.92
		tween.parallel().tween_property(self, "scale", end_scale, duration)
	else:
		tween.parallel().tween_property(label, "modulate:a", 0.0, duration)
		tween.parallel().tween_property(self, "scale", Vector2.ZERO, duration)

	tween.tween_callback(queue_free)
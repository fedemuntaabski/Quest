extends Node2D
class_name FloatingText

@export var float_distance: float = 18.0
@export var float_time: float = 0.6
@export var base_scale: float = 1.0

@onready var label: Label = $Label


func setup(text: String, color: Color, crit: bool = false, intensity: float = 1.0) -> void:
	z_index = 100

	if label:
		label.text = text
		label.modulate = color

		# Crit visual feedback
		if crit:
			label.scale = Vector2(1.25, 1.25)
		else:
			label.scale = Vector2.ONE

	# Global scaling based on intensity (damage size, gold, etc.)
	scale = Vector2.ONE * clamp(base_scale * intensity, 0.8, 2.5)

	_play_float_animation()


func _play_float_animation() -> void:
	var jitter := Vector2(randf_range(-6, 6), 0)

	var target_pos := global_position + Vector2(0, -float_distance) + jitter

	var tween := create_tween()

	# Movement
	tween.tween_property(self, "global_position", target_pos, float_time)

	# Fade
	tween.parallel().tween_property(label, "modulate:a", 0.0, float_time)

	# Slight shrink for readability
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, float_time)

	tween.tween_callback(queue_free)
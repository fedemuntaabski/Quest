extends Node2D
class_name VisualParticle

## VisualParticle owns a single short-lived impact particle.
## VisualFeedback spawns it and only provides position, color, and timing.

@export var float_time: float = 0.45
@export var rise_distance: float = 0.0

@onready var block: ColorRect = $ColorRect

func setup(color: Color, size: Vector2, lifetime: float, rise: float) -> void:
	float_time = lifetime
	rise_distance = rise
	if block:
		block.color = color
		block.size = size
	_play_animation()

func _play_animation() -> void:
	var tween := create_tween()
	if rise_distance != 0.0:
		tween.tween_property(self, "position", position + Vector2(0, -rise_distance), float_time)
	else:
		tween.tween_property(self, "scale", Vector2.ZERO, float_time)
	if block:
		tween.parallel().tween_property(block, "modulate:a", 0.0, float_time)
	tween.tween_callback(queue_free)

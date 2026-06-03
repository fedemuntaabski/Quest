extends Node2D
class_name VisualParticle

@export var float_time: float = 0.45
@export var rise_distance: float = 0.0
@export var base_scale: float = 1.0

@onready var block: ColorRect = $ColorRect

func setup(
	color: Color,
	size: Vector2,
	lifetime: float,
	rise: float,
	intensity: float = 1.0,
	direction: Vector2 = Vector2.ZERO
) -> void:

	float_time = lifetime
	rise_distance = rise

	if block:
		block.color = color
		block.size = size

	base_scale = intensity
	scale = Vector2.ONE * base_scale

	_play_animation(direction)


func _play_animation(direction: Vector2) -> void:
	var tween := create_tween()

	if rise_distance != 0.0:
		tween.tween_property(self, "position", position + Vector2(0, -rise_distance), float_time)
	elif direction != Vector2.ZERO:
		tween.tween_property(self, "position", position + direction.normalized() * 10.0, float_time)
	else:
		tween.tween_property(self, "scale", Vector2.ZERO, float_time)

	if block:
		tween.parallel().tween_property(block, "modulate:a", 0.0, float_time)

	scale *= 1.15
	tween.tween_property(self, "scale", Vector2.ONE * base_scale, float_time * 0.2)

	tween.tween_callback(queue_free)
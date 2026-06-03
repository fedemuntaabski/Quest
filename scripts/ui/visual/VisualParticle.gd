extends Node2D
class_name VisualParticle

enum ParticleMode {
	FLOAT,
	SHRINK,
	RISE_AND_FADE
}

@export var float_time: float = 0.45
@export var rise_distance: float = 0.0

@onready var block: ColorRect = $ColorRect

func setup(color: Color, size: Vector2, lifetime: float, rise: float, mode: ParticleMode = ParticleMode.RISE_AND_FADE) -> void:
	float_time = lifetime
	rise_distance = rise

	if block:
		block.color = color
		block.size = size

	_play_animation(mode)


func _play_animation(mode: ParticleMode) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	match mode:
		ParticleMode.RISE_AND_FADE:
			tween.tween_property(self, "position", position + Vector2(0, -rise_distance), float_time)
			if block:
				tween.parallel().tween_property(block, "modulate:a", 0.0, float_time)

		ParticleMode.SHRINK:
			tween.tween_property(self, "scale", Vector2.ZERO, float_time)
			if block:
				tween.parallel().tween_property(block, "modulate:a", 0.0, float_time)

		ParticleMode.FLOAT:
			tween.tween_property(self, "position", position + Vector2(0, -rise_distance), float_time * 0.6)
			tween.tween_property(self, "position", position, float_time * 0.4)
			if block:
				tween.parallel().tween_property(block, "modulate:a", 0.0, float_time)

	tween.tween_callback(queue_free)
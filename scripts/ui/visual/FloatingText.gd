extends Node2D
class_name FloatingText

## FloatingText owns the short-lived visual node used for combat and gold popups.
## FloatingTextManager only instantiates the scene and provides text, color, and motion settings.

@export var float_distance: float = 18.0
@export var float_time: float = 0.6

@onready var label: Label = $Label

func setup(text: String, color: Color, crit: bool = false) -> void:
	z_index = 100
	if label:
		label.text = text
		label.modulate = color
		if crit:
			label.scale = Vector2(1.2, 1.2)
	_play_float_animation()

func _play_float_animation() -> void:
	var target_pos := global_position + Vector2(0, -float_distance)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, float_time)
	tween.parallel().tween_property(label, "modulate:a", 0.0, float_time)
	tween.tween_callback(queue_free)

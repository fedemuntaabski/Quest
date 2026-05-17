extends Node2D
class_name FloatingTextManager

@export var float_distance: float = 18.0
@export var float_time: float = 0.6

func _ready() -> void:
	add_to_group("floating_text_manager")

func spawn_text(world_pos: Vector2, text: String, color: Color, crit: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 100
	label.position = world_pos
	if crit:
		label.scale = Vector2(1.2, 1.2)
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position", world_pos + Vector2(0, -float_distance), float_time)
	tween.parallel().tween_property(label, "modulate:a", 0.0, float_time)
	tween.tween_callback(label.queue_free)

extends Node2D
class_name FloatingTextManager

@export var float_distance: float = 18.0
@export var float_time: float = 0.6

const FloatingTextScene := preload("res://scenes/FloatingText.tscn")

func _ready() -> void:
	add_to_group("floating_text_manager")

func spawn_text(world_pos: Vector2, text: String, color: Color, crit: bool = false) -> void:
	var floating_text = FloatingTextScene.instantiate() as FloatingText
	if floating_text == null:
		return
	floating_text.float_distance = float_distance
	floating_text.float_time = float_time
	floating_text.global_position = world_pos
	add_child(floating_text)
	floating_text.setup(text, color, crit)

func spawn_text_from_host(
	host: Node2D,
	text: String,
	color: Color,
	crit: bool = false,
	local_offset: Vector2 = Vector2(-12, -28),
	custom_float_distance: float = 18.0,
	custom_float_time: float = 0.5
) -> void:
	if host == null:
		return
	var floating_text = FloatingTextScene.instantiate() as FloatingText
	if floating_text == null:
		return
	floating_text.float_distance = custom_float_distance
	floating_text.float_time = custom_float_time
	floating_text.global_position = host.global_position + local_offset
	add_child(floating_text)
	floating_text.setup(text, color, crit)

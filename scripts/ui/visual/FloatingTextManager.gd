extends Node2D
class_name FloatingTextManager

@export var float_distance: float = 18.0
@export var float_time: float = 0.6

const FloatingTextScene := preload("res://scenes/vfx/FloatingText.tscn")

func _ready() -> void:
	add_to_group("floating_text_manager")


# =========================================================
# 🎯 SIMPLE SPAWN (WORLD POSITION)
# =========================================================
func spawn_text(world_pos: Vector2, text: String, color: Color, crit: bool = false, intensity: float = 1.0) -> void:
	var ft := _create_text()

	if ft == null:
		return

	ft.float_distance = float_distance
	ft.float_time = float_time
	ft.global_position = world_pos

	add_child(ft)

	ft.setup(text, color, crit, intensity)


# =========================================================
# 🧠 INTERNAL CREATION
# =========================================================
func _create_text() -> FloatingText:
	var instance := FloatingTextScene.instantiate()

	if instance is FloatingText:
		return instance

	return null

extends Node2D
class_name FloatingTextManager

const FloatingTextScene := preload("res://scenes/vfx/FloatingText.tscn")


func _ready() -> void:
	add_to_group("floating_text_manager")


## The one way to float a text: no-op when the floor has no manager (scene run alone, tests).
static func say(world_pos: Vector2, text: String, color: Color, crit: bool = false, intensity: float = 1.0) -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(world_pos, text, color, crit, intensity)


func spawn_text(world_pos: Vector2, text: String, color: Color, crit: bool = false, intensity: float = 1.0) -> void:
	var ft: FloatingText = FloatingTextScene.instantiate()
	ft.global_position = world_pos
	add_child(ft)
	ft.setup(text, color, crit, intensity)

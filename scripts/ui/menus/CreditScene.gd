extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var back_button: Button = $BackButton

var is_transitioning := false


func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	if is_transitioning:
		return

	is_transitioning = true

	# pequeño feedback visual opcional (no rompe nada si no querés animación)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)

	await tween.finished

	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE)

	if err != OK:
		push_error("CreditsScene: Failed to load MainMenu scene: " + str(err))
		is_transitioning = false

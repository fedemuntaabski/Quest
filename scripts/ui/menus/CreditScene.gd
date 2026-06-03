extends Control

const SCROLL_SPEED := 40.0
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var scroll_container: ScrollContainer = $CenterContainer/ScrollContainer
@onready var back_button: Button = $BackButton

func _ready() -> void:

	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

func _process(delta: float) -> void:

	scroll_container.scroll_vertical += int(
		SCROLL_SPEED * delta
	)

func _on_back_pressed() -> void:

	get_tree().change_scene_to_file(
		MAIN_MENU_SCENE
	)


func _on_back_button_pressed() -> void:
	pass # Replace with function body.

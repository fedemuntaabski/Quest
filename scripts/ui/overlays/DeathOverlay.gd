class_name DeathOverlay
extends EndScreenOverlay

## Run-over screen: Retry (new run) / Exit (main menu).

signal retry_requested
signal exit_requested

@onready var _retry_button: Button = $CenterContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var _exit_button: Button = $CenterContainer/VBoxContainer/ButtonsHBox/ExitButton


func _ready() -> void:
	_retry_button.pressed.connect(retry_requested.emit)
	_exit_button.pressed.connect(exit_requested.emit)

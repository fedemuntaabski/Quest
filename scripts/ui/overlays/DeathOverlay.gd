class_name DeathOverlay
extends EndScreenOverlay

## Run-over screen: run summary (RunSummary) + New run / main menu.

signal retry_requested
signal exit_requested

@onready var _retry_button: Button = $CenterContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var _exit_button: Button = $CenterContainer/VBoxContainer/ButtonsHBox/ExitButton

var summary: RunSummary


func _ready() -> void:
	_retry_button.pressed.connect(retry_requested.emit)
	_exit_button.pressed.connect(exit_requested.emit)
	summary = add_summary($CenterContainer/VBoxContainer, $CenterContainer/VBoxContainer/ButtonsHBox)


## coop-12: the host left mid-run. Same summary, other title, no retry (there is
## nobody to retry with).
func show_host_lost() -> void:
	var label := get_node_or_null("CenterContainer/VBoxContainer/DeathLabel") as Label
	if label:
		label.text = "El anfitrión abandonó la partida"
	_retry_button.visible = false

extends CanvasLayer
class_name VictoryOverlay

signal retry_requested
signal exit_requested

## Scene-owned victory overlay for the boss defeat flow.
## Main2d supplies the run summary; this node owns presentation and button signals.
var _pending_enemies_killed: int = 0
var _pending_rooms_cleared: int = 0
var _pending_gold_earned: int = 0

@onready var victory_label: Label = $Control/CenterContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/VictoryLabel
@onready var summary_label: Label = $Control/CenterContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/SummaryLabel
@onready var gold_label: Label = $Control/CenterContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/GoldLabel
@onready var credits_label: RichTextLabel = $Control/CenterContainer/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/CreditsLabel
@onready var retry_button: Button = $Control/CenterContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var exit_button: Button = $Control/CenterContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/ButtonsHBox/ExitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Start hidden; Main2d only triggers this scene when the boss fight is over.
	hide_victory()
	if retry_button and not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)
	if exit_button and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)

## Populates the scene with the current run summary and shows it.
func show_victory(enemies_killed: int, rooms_cleared: int, gold_earned: int = 0) -> void:
	_pending_enemies_killed = enemies_killed
	_pending_rooms_cleared = rooms_cleared
	_pending_gold_earned = gold_earned
	_refresh_labels()

	visible = true

## Hides the overlay without mutating the stored run summary.
func hide_victory() -> void:
	visible = false


## Refreshes the visible copy of the run summary inside the overlay scene.
func _refresh_labels() -> void:
	if victory_label:
		victory_label.text = "¡Victoria!"
	if summary_label:
		summary_label.text = "Contrato completado!.\nEnemigos derrotados: %d\nHabitaciones limpiadas: %d\n" % [_pending_enemies_killed, _pending_rooms_cleared]
	if gold_label:
		gold_label.text = "Oro ganado en esta partida: %d" % _pending_gold_earned


func _on_retry_pressed() -> void:
	retry_requested.emit()

func _on_exit_pressed() -> void:
	exit_requested.emit()

extends CanvasLayer
class_name VictoryOverlay

signal retry_requested
signal exit_requested

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
	# Start hidden; Main2d is responsible for calling `show_victory(...)`.
	hide_victory()
	if retry_button and not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)
	if exit_button and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)

func show_victory(enemies_killed: int, rooms_cleared: int, gold_earned: int = 0) -> void:
	_pending_enemies_killed = enemies_killed
	_pending_rooms_cleared = rooms_cleared
	_pending_gold_earned = gold_earned
	if victory_label:
		victory_label.text = "¡Victoria!"
	if summary_label:
		summary_label.text = "Contrato completado!.\nEnemigos derrotados: %d\nHabitaciones limpiadas: %d\n" % [enemies_killed, rooms_cleared]
	if gold_label:
		gold_label.text = "Oro ganado en esta partida: %d" % gold_earned

	visible = true

func hide_victory() -> void:
	visible = false



func _on_retry_pressed() -> void:
	retry_requested.emit()

func _on_exit_pressed() -> void:
	exit_requested.emit()

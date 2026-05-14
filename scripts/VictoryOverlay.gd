extends CanvasLayer
class_name VictoryOverlay

signal retry_requested
signal exit_requested

@onready var victory_label: Label = $Control/CenterContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/VictoryLabel
@onready var summary_label: Label = $Control/CenterContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/SummaryLabel
@onready var credits_label: RichTextLabel = $Control/CenterContainer/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/CreditsLabel
@onready var retry_button: Button = $Control/CenterContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var exit_button: Button = $Control/CenterContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/ButtonsHBox/ExitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_victory()
	if retry_button and not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)
	if exit_button and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)

func show_victory(enemies_killed: int, rooms_cleared: int, gold_earned: int = 0) -> void:
	if victory_label:
		victory_label.text = "¡Victoria!"
	if summary_label:
		summary_label.text = "El jefe púrpura ha caído.\nEnemigos derrotados: %d\nHabitaciones limpiadas: %d\nOro ganado: %d" % [enemies_killed, rooms_cleared, gold_earned]
	if credits_label:
		credits_label.text = "[center][b]Créditos[/b][/center]\n\nQuest Team\nDiseño y sistemas\nCódigo y combate\nArte / UI\n\nGodot 4.6"
	visible = true

func hide_victory() -> void:
	visible = false

func _on_retry_pressed() -> void:
	retry_requested.emit()

func _on_exit_pressed() -> void:
	exit_requested.emit()

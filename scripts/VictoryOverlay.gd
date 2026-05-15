extends CanvasLayer
class_name VictoryOverlay

signal retry_requested
signal exit_requested

const MAIN_GAME_SCENE := "res://scenes/Main2d.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

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
	if get_tree() and get_tree().current_scene == self:
		_read_victory_summary_from_tree()
		show_victory(_pending_enemies_killed, _pending_rooms_cleared, _pending_gold_earned)
	else:
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
		summary_label.text = "El jefe púrpura ha caído.\nEnemigos derrotados: %d\nHabitaciones limpiadas: %d\nOro ganado: %d" % [enemies_killed, rooms_cleared, gold_earned]
	if gold_label:
		gold_label.text = "Oro ganado en esta partida: %d" % gold_earned
	if credits_label:
		credits_label.text = "[center][b]Créditos[/b][/center]\n\nQuest Team\nDiseño y sistemas\nCódigo y combate\nArte / UI\n\nGodot 4.6"
	visible = true

func hide_victory() -> void:
	visible = false


func _read_victory_summary_from_tree() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_pending_enemies_killed = int(tree.get_meta("victory_enemies_killed", 0))
	_pending_rooms_cleared = int(tree.get_meta("victory_rooms_cleared", 0))
	_pending_gold_earned = int(tree.get_meta("victory_gold_earned", 0))
	if tree.has_meta("victory_enemies_killed"):
		tree.remove_meta("victory_enemies_killed")
	if tree.has_meta("victory_rooms_cleared"):
		tree.remove_meta("victory_rooms_cleared")
	if tree.has_meta("victory_gold_earned"):
		tree.remove_meta("victory_gold_earned")
	if tree.has_meta("victory_from_gameplay_scene"):
		tree.remove_meta("victory_from_gameplay_scene")

func _on_retry_pressed() -> void:
	retry_requested.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_GAME_SCENE)

func _on_exit_pressed() -> void:
	exit_requested.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

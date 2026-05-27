extends CanvasLayer
class_name PostVictoryPopup

signal continue_pressed

@onready var title_label: Label = $Control/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $Control/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyLabel
@onready var continue_button: Button = $Control/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if continue_button and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)

func show_popup(run_cycle: int) -> void:
	visible = true
	if title_label:
		title_label.text = "Contrato renovado."
	if body_label:
		body_label.text = "Jefe neutralizado en run anterior.\nNuevo contrato iniciado.\nNivel de amenaza aumentado: Ciclo %d." % max(0, run_cycle)
	if continue_button:
		continue_button.grab_focus()

func _on_continue_pressed() -> void:
	continue_pressed.emit()

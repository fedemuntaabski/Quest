class_name VictoryOverlay
extends EndScreenOverlay

## Floor-cleared / run-won screen: next floor (unless it was the last) or, after
## the final floor, the run summary (RunSummary) + New run / main menu.

signal next_floor_requested
signal return_requested
signal new_run_requested

@onready var _title: Label = $CenterContainer/VBoxContainer/VictoryLabel
@onready var _next_floor_button: Button = $CenterContainer/VBoxContainer/NextFloorButton
@onready var _new_run_button: Button = $CenterContainer/VBoxContainer/NewRunButton
@onready var _return_button: Button = $CenterContainer/VBoxContainer/ReturnButton

var summary: RunSummary


func _ready() -> void:
	_next_floor_button.pressed.connect(next_floor_requested.emit)
	_new_run_button.pressed.connect(new_run_requested.emit)
	_return_button.pressed.connect(return_requested.emit)
	summary = add_summary($CenterContainer/VBoxContainer, _next_floor_button)
	summary.visible = false


## Called when the floor is completed, before the overlay is shown.
func set_floor_result(completed_floor: int, has_next_floor: bool) -> void:
	_next_floor_button.visible = has_next_floor
	_new_run_button.visible = not has_next_floor
	_next_floor_button.text = "Descender al piso %d" % (completed_floor + 1)
	if has_next_floor:
		_title.text = "¡Piso %d superado!" % completed_floor

class_name VictoryOverlay
extends EndScreenOverlay

## Floor-cleared / run-won screen: next floor (unless it was the last) or main menu.

signal next_floor_requested
signal return_requested

@onready var _title: Label = $CenterContainer/VBoxContainer/VictoryLabel
@onready var _next_floor_button: Button = $CenterContainer/VBoxContainer/NextFloorButton
@onready var _return_button: Button = $CenterContainer/VBoxContainer/ReturnButton


func _ready() -> void:
	_next_floor_button.pressed.connect(next_floor_requested.emit)
	_return_button.pressed.connect(return_requested.emit)


## Called when the floor is completed, before the overlay is shown.
func set_floor_result(completed_floor: int, has_next_floor: bool) -> void:
	_next_floor_button.visible = has_next_floor
	_next_floor_button.text = "Descender al piso %d" % (completed_floor + 1)
	if has_next_floor:
		_title.text = "¡Piso %d superado!" % completed_floor

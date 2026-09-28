extends Area2D
class_name EnergyButton

## EnergyButton: "Clic central: encender (10 Polvo)" prompt shown on a revealed,
## unpowered RoomZone. Passive hint since session 7 (RoomZone keeps it
## non-pickable; lighting is RoomZone.toggle_power on middle-click). The click
## plumbing below is kept for the signal contract.

signal energy_button_clicked(zone_id: String)

func _ready() -> void:
	z_index = 2
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	var zone := get_parent() as RoomZone
	energy_button_clicked.emit(zone.zone_id if zone else "")
	get_viewport().set_input_as_handled()

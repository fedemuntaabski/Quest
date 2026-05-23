extends Control
class_name TimerUI

## Presentation-only timer label used by the HUD.
## HUDController owns the data flow and pushes formatted time/color here.
@onready var timer_label: Label = $TimerLabel

## Updates the visible room timer without owning timer state.
func set_time(remaining_seconds: float, color: Color) -> void:
	var t := maxf(0.0, remaining_seconds)
	var m := int(t / 60.0)
	var s := int(t) % 60

	timer_label.text = "%02d:%02d" % [m, s]
	timer_label.modulate = color

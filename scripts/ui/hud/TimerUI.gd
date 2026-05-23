extends Control
class_name TimerUI

## Presentation-only timer label used by the HUD.
## HUDController owns the data flow and pushes formatted time/color here.
@onready var timer_label: Label = $TimerLabel

## Updates the visible room timer without owning timer state.
func set_time(remaining_seconds: float, color: Color) -> void:
	if timer_label == null:
		return

	var t := maxf(0.0, remaining_seconds)
	timer_label.text = _format_time_label(t)
	timer_label.modulate = color

## Formats the timer display as MM:SS for HUD presentation.
func _format_time_label(total_seconds: float) -> String:
	var m := int(total_seconds / 60.0)
	var s := int(total_seconds) % 60
	return "%02d:%02d" % [m, s]

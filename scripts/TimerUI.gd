extends Control
class_name TimerUI

@onready var timer_label: Label = $TimerLabel

func set_time(remaining_seconds: float, color: Color) -> void:
	var t = maxf(0.0, remaining_seconds)
	var m = int(t / 60.0)
	var s = int(t) % 60

	timer_label.text = "Time: %02d:%02d" % [m, s]
	timer_label.modulate = color
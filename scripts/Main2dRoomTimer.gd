extends RefCounted
class_name Main2dRoomTimer

const ROOM_TIMER_SECONDS: float = 120.0
const WARNING_SECONDS: float = 60.0
const CRITICAL_SECONDS: float = 15.0

var remaining: float = ROOM_TIMER_SECONDS
var expired_logged: bool = false

func reset() -> void:
	remaining = ROOM_TIMER_SECONDS
	expired_logged = false

func tick(delta: float) -> Dictionary:
	remaining = maxf(0.0, remaining - delta)

	var expired := false
	if remaining <= 0.0 and not expired_logged:
		expired_logged = true
		expired = true

	return {
		"remaining": remaining,
		"expired": expired,
		"color": _get_timer_color()
	}

func _get_timer_color() -> Color:
	if remaining <= CRITICAL_SECONDS:
		return Color(1, 0.24, 0.2)
	elif remaining <= WARNING_SECONDS:
		return Color(1, 0.85, 0.2)
	return Color.WHITE

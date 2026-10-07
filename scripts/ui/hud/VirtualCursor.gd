extends Node
class_name VirtualCursor

## VirtualCursor (calidad-13): gamepad play without touching gameplay code.
## The right stick moves the real mouse pointer and A / B / X are turned into
## left / right / middle mouse buttons at the pointer (Input.parse_input_event),
## so the existing Area2D picking (rooms, doors, heroes, slots) and the HUD
## buttons work unchanged. Lives in the HUD and pauses with the tree, so in the
## Esc menu A/B go back to plain focus navigation (ui_accept / ui_cancel).

const SPEED_PX := 900.0
const FAST_MULT := 2.2
const DEADZONE := 0.2

var _last_usec: int = 0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := 0.0 if _last_usec == 0 else minf((now - _last_usec) / 1000000.0, 0.1)
	_last_usec = now  # real time: the tactical pause sets Engine.time_scale to 0
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() < DEADZONE:
		return
	var viewport := get_viewport()
	var speed := SPEED_PX * (FAST_MULT if stick.length() > 0.95 else 1.0)
	var pos := viewport.get_mouse_position() + stick * speed * dt
	viewport.warp_mouse(pos.clamp(Vector2.ZERO, viewport.get_visible_rect().size - Vector2.ONE))


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton) or not InputBindings.CURSOR_BUTTONS.has(event.button_index):
		return
	get_viewport().set_input_as_handled()
	Input.parse_input_event(to_mouse(event as InputEventJoypadButton, get_viewport()))


## The mouse button event a cursor button press/release becomes (window coords).
static func to_mouse(event: InputEventJoypadButton, viewport: Viewport) -> InputEventMouseButton:
	var mb := InputEventMouseButton.new()
	mb.button_index = InputBindings.CURSOR_BUTTONS[event.button_index]
	mb.pressed = event.pressed
	var screen_pos: Vector2 = viewport.get_screen_transform() * viewport.get_mouse_position()
	mb.position = screen_pos
	mb.global_position = screen_pos
	mb.button_mask = (1 << (mb.button_index - 1)) if event.pressed else 0
	return mb

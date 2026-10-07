class_name InputBindings
extends RefCounted

## InputBindings (calidad-13): the remappable actions, their gamepad defaults and
## the compact text encoding SettingsManager persists in settings.cfg [input].
## Keyboard defaults live in project.godot; the actions added here (gamepad
## buttons, the build/chat/help keys that used to be hard-coded) are created by
## ensure_defaults() at startup, before the player's overrides are applied.

## Action -> name shown in Opciones > Controles and in the help screen (order kept).
const REMAPPABLE := {
	"move_up": "Cámara arriba",
	"move_down": "Cámara abajo",
	"move_left": "Cámara izquierda",
	"move_right": "Cámara derecha",
	"camera_recenter": "Centrar cámara",
	"tactical_pause": "Pausa táctica",
	"game_speed": "Velocidad 1x/2x",
	"hero_ability": "Habilidad del héroe",
	"hero_cycle": "Siguiente héroe",
	"hero_cycle_prev": "Héroe anterior",
	"select_hero_1": "Seleccionar héroe 1",
	"select_hero_2": "Seleccionar héroe 2",
	"select_hero_3": "Seleccionar héroe 3",
	"select_hero_4": "Seleccionar héroe 4",
	"group_select_1": "Grupo 1",
	"group_select_2": "Grupo 2",
	"group_select_3": "Grupo 3",
	"group_assign_1": "Asignar grupo 1",
	"group_assign_2": "Asignar grupo 2",
	"group_assign_3": "Asignar grupo 3",
	"build_major": "Construir: Mayores",
	"build_minor": "Construir: Menores",
	"build_research": "Investigación",
	"chat": "Chat (en línea)",
	"show_help": "Ayuda de controles",
}

## Fixed mouse/gamepad-cursor actions, listed (not remappable) in the help screen.
const MOUSE_HELP := [
	["Clic izquierdo", "Seleccionar héroe / abrir puerta / interactuar"],
	["Ctrl + clic izquierdo", "Añadir héroe a la selección"],
	["Clic derecho", "Mover la selección a la sala"],
	["Clic central", "Encender / apagar la sala (Polvo)"],
	["Arrastrar con botón central", "Mover la cámara"],
	["Rueda", "Zoom"],
	["Alt + clic izquierdo", "Marca en el mapa (en línea)"],
	["Esc", "Cerrar / menú de pausa"],
	["1-9 con el menú abierto", "Elegir tarjeta de construcción"],
]

const GAMEPAD_HELP := [
	["Stick derecho", "Cursor virtual"],
	["A / B / X", "Clic izquierdo / derecho / central del cursor"],
	["Stick izquierdo / cruceta", "Mover la cámara"],
]

## Defaults added by code: keys that were hard-coded before calidad-13, new
## actions and every gamepad binding. Each entry: action -> encoded events.
const CODE_DEFAULTS := {
	"move_up": ["ja:1:-1", "jb:11"],
	"move_down": ["ja:1:1", "jb:12"],
	"move_left": ["ja:0:-1", "jb:13"],
	"move_right": ["ja:0:1", "jb:14"],
	"camera_recenter": ["jb:8"],
	"tactical_pause": ["jb:6"],
	"hero_ability": ["jb:3"],
	"hero_cycle": ["jb:10", "ja:5:1"],
	"hero_cycle_prev": ["k:4194306:0s", "jb:9", "ja:4:1"],  # Shift+Tab, LB, LT
	"build_major": ["k:66:0"],  # B
	"build_minor": ["k:86:0"],  # V
	"build_research": ["k:82:0"],  # R
	"chat": ["k:84:0"],  # T
	"show_help": ["k:72:0"],  # H (gamepad: Back -> pause menu -> Controles)
	"ui_cancel": ["jb:4"],  # Back opens/closes the pause menu (B is the cursor's right click in game)
}

## Gamepad buttons that drive the virtual cursor (VirtualCursor): A, B, X.
const CURSOR_BUTTONS := {JOY_BUTTON_A: MOUSE_BUTTON_LEFT, JOY_BUTTON_B: MOUSE_BUTTON_RIGHT, JOY_BUTTON_X: MOUSE_BUTTON_MIDDLE}

## Keyboard/mouse events of every action as project.godot left them (for reset).
static var _project_events: Dictionary = {}


## Creates the code-defined actions and adds the gamepad defaults. Idempotent.
static func ensure_defaults() -> void:
	for action in CODE_DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		elif InputMap.action_get_deadzone(action) < 0.2:
			InputMap.action_set_deadzone(action, 0.2)  # move_* had 0: stick drift would pan the camera
		for code in CODE_DEFAULTS[action]:
			var ev := decode(code)
			if ev and not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
	if _project_events.is_empty():
		for action in REMAPPABLE:
			_project_events[action] = InputMap.action_get_events(action).duplicate()


## The default events of `action` (project.godot + CODE_DEFAULTS).
static func default_events(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	out.assign(_project_events.get(action, []))
	return out


## Replaces `action`'s keyboard (or gamepad, `gamepad` = true) binding with `ev`,
## keeping the other device's events.
static func rebind(action: String, ev: InputEvent, gamepad: bool) -> void:
	for old in InputMap.action_get_events(action):
		if is_gamepad(old) == gamepad:
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, ev)


static func reset(action: String) -> void:
	InputMap.action_erase_events(action)
	for ev in default_events(action):
		InputMap.action_add_event(action, ev)


static func reset_all() -> void:
	for action in REMAPPABLE:
		reset(action)


## Actions (other than `action`) already using an event equal to `ev`.
static func conflicts(action: String, ev: InputEvent) -> Array[String]:
	var out: Array[String] = []
	for other in REMAPPABLE:
		if other != action and InputMap.action_has_event(other, ev):
			out.append(other)
	return out


## {action: [codes]} of every remappable action that differs from its defaults.
static func overrides() -> Dictionary:
	var out := {}
	for action in REMAPPABLE:
		var now := encode_all(InputMap.action_get_events(action))
		if now != encode_all(default_events(action)):
			out[action] = now
	return out


static func apply_overrides(data: Dictionary) -> void:
	for action in data:
		if not REMAPPABLE.has(action) or not (data[action] is Array):
			continue
		InputMap.action_erase_events(action)
		for code in data[action]:
			var ev := decode(str(code))
			if ev:
				InputMap.action_add_event(action, ev)


static func encode_all(events: Array) -> Array[String]:
	var out: Array[String] = []
	for ev in events:
		var code := encode(ev)
		if code != "":
			out.append(code)
	return out


## "k:<keycode>:<physical>[c][s][a]" | "jb:<button>" | "ja:<axis>:<-1|1>" | "mb:<button>".
static func encode(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var mods := ("c" if ev.ctrl_pressed else "") + ("s" if ev.shift_pressed else "") + ("a" if ev.alt_pressed else "")
		return "k:%d:%d%s" % [ev.keycode, ev.physical_keycode, mods]
	if ev is InputEventJoypadButton:
		return "jb:%d" % ev.button_index
	if ev is InputEventJoypadMotion:
		return "ja:%d:%d" % [ev.axis, 1 if ev.axis_value > 0 else -1]
	if ev is InputEventMouseButton:
		return "mb:%d" % ev.button_index
	return ""


static func decode(code: String) -> InputEvent:
	var parts := code.split(":")
	match parts[0]:
		"k":
			if parts.size() < 3:
				return null
			var ev := InputEventKey.new()
			ev.keycode = int(parts[1]) as Key
			var tail := parts[2]
			ev.physical_keycode = int(tail.rstrip("csa")) as Key
			ev.ctrl_pressed = tail.contains("c")
			ev.shift_pressed = tail.contains("s")
			ev.alt_pressed = tail.contains("a")
			return ev
		"jb":
			var ev := InputEventJoypadButton.new()
			ev.button_index = int(parts[1]) as JoyButton
			return ev
		"ja":
			if parts.size() < 3:
				return null
			var ev := InputEventJoypadMotion.new()
			ev.axis = int(parts[1]) as JoyAxis
			ev.axis_value = float(parts[2])
			return ev
		"mb":
			var ev := InputEventMouseButton.new()
			ev.button_index = int(parts[1]) as MouseButton
			return ev
	return null


static func is_gamepad(ev: InputEvent) -> bool:
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion


## Short label of the first keyboard (or gamepad) event of `action`, "—" if none.
static func label(action: String, gamepad: bool = false) -> String:
	if not InputMap.has_action(action):
		return "—"
	for ev in InputMap.action_get_events(action):
		if is_gamepad(ev) == gamepad:
			return event_label(ev)
	return "—"


static func event_label(ev: InputEvent) -> String:
	if ev is InputEventJoypadButton:
		return JOY_NAMES.get(ev.button_index, "Botón %d" % ev.button_index)
	if ev is InputEventJoypadMotion:
		var axis_name: String = AXIS_NAMES.get(ev.axis, "Eje %d" % ev.axis)
		if ev.axis >= JOY_AXIS_TRIGGER_LEFT:
			return axis_name
		return axis_name + ("+" if ev.axis_value > 0 else "-")
	if ev is InputEventKey:
		return ev.as_text_keycode() if ev.keycode != KEY_NONE else ev.as_text_physical_keycode()
	return ev.as_text()


const JOY_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Cruceta ↑", JOY_BUTTON_DPAD_DOWN: "Cruceta ↓", JOY_BUTTON_DPAD_LEFT: "Cruceta ←", JOY_BUTTON_DPAD_RIGHT: "Cruceta →",
}
const AXIS_NAMES := {
	JOY_AXIS_LEFT_X: "Stick izq. X", JOY_AXIS_LEFT_Y: "Stick izq. Y", JOY_AXIS_RIGHT_X: "Stick der. X", JOY_AXIS_RIGHT_Y: "Stick der. Y",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
}

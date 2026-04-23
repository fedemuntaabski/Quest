extends Node2D

const ROOM_TIMER_SECONDS: float = 120.0
const WARNING_SECONDS: float = 60.0
const CRITICAL_SECONDS: float = 15.0

@onready var dungeon_generator: DungeonGenerator = $MapManager/DungeonGenerator
@onready var hud: HUDController = $HUD
@onready var pause_menu: Node = $PauseMenu

var room_timer_remaining: float = ROOM_TIMER_SECONDS
var timer_expired_logged: bool = false
var visited_rooms: Array[int] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if dungeon_generator and not dungeon_generator.room_changed.is_connected(_on_room_changed):
		dungeon_generator.room_changed.connect(_on_room_changed)
	if pause_menu and pause_menu.has_method("close_menu"):
		pause_menu.close_menu()

	_reset_room_timer()
	_update_timer_ui()

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	room_timer_remaining = maxf(0.0, room_timer_remaining - delta)
	_update_timer_ui()

	if room_timer_remaining <= 0.0 and not timer_expired_logged:
		timer_expired_logged = true
		push_warning("Main2d: Room timer reached zero.")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_paused_state(not get_tree().paused)
		get_viewport().set_input_as_handled()

func _on_room_changed(room_id: int) -> void:
	if room_id not in visited_rooms:
		visited_rooms.append(room_id)
		_reset_room_timer()
	_update_timer_ui()

func _set_paused_state(paused_value: bool) -> void:
	if pause_menu:
		if paused_value:
			if pause_menu.has_method("open_menu"):
				pause_menu.open_menu()
		elif pause_menu.has_method("close_menu"):
			pause_menu.close_menu()

	get_tree().paused = paused_value

func _reset_room_timer() -> void:
	room_timer_remaining = ROOM_TIMER_SECONDS
	timer_expired_logged = false

func _update_timer_ui() -> void:
	var timer_color := Color(1, 1, 1, 1)
	if room_timer_remaining <= CRITICAL_SECONDS:
		timer_color = Color(1, 0.24, 0.2, 1)
	elif room_timer_remaining <= WARNING_SECONDS:
		timer_color = Color(1, 0.85, 0.2, 1)

	if hud:
		hud.update_room_timer(room_timer_remaining, ROOM_TIMER_SECONDS, timer_color)

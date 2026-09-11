extends Control
class_name BaseSubPanel

signal menu_opened
signal menu_closed

@export var pause_game_on_open: bool = false
@export var animate_transitions: bool = false
@export var fade_duration_in: float = 0.25
@export var fade_duration_out: float = 0.20

var is_open: bool = false

var _click_sfx: AudioStreamPlayer
var _hover_sfx: AudioStreamPlayer
var _tween: Tween
var _fade_targets: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_on_base_ready()


func _on_base_ready() -> void:
	pass


func _on_before_open() -> void:
	pass


func _on_before_close() -> void:
	pass


func set_audio_players(click: AudioStreamPlayer, hover: AudioStreamPlayer) -> void:
	_click_sfx = click
	_hover_sfx = hover


func play_click() -> void:
	if _click_sfx:
		_click_sfx.play()


func play_hover() -> void:
	if _hover_sfx:
		_hover_sfx.play()


func connect_button(btn: Button, on_press: Callable) -> void:
	if btn == null:
		return
	if not btn.pressed.is_connected(on_press):
		btn.pressed.connect(on_press)
	if not btn.mouse_entered.is_connected(play_hover):
		btn.mouse_entered.connect(play_hover)


func add_fade_target(node: CanvasItem, max_alpha: float = 1.0) -> void:
	_fade_targets.append({"node": node, "max_alpha": max_alpha})


func open() -> void:
	if is_open:
		return
	is_open = true
	_on_before_open()
	visible = true
	if pause_game_on_open:
		var gsm := ManagerLocator.get_game_state_manager()
		if gsm:
			gsm.request_pause()
	if animate_transitions:
		_play_fade_in()
	menu_opened.emit()


func close() -> void:
	if not is_open:
		return
	_on_before_close()
	if animate_transitions:
		await _play_fade_out()
	visible = false
	if pause_game_on_open:
		var gsm := ManagerLocator.get_game_state_manager()
		if gsm:
			gsm.request_resume()
	is_open = false
	menu_closed.emit()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _play_fade_in() -> void:
	if _fade_targets.is_empty():
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for entry in _fade_targets:
		var node: CanvasItem = entry["node"]
		node.modulate.a = 0.0
		_tween.tween_property(node, "modulate:a", entry["max_alpha"], fade_duration_in)


func _play_fade_out() -> void:
	if _fade_targets.is_empty():
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for entry in _fade_targets:
		_tween.tween_property(entry["node"], "modulate:a", 0.0, fade_duration_out)
	await _tween.finished

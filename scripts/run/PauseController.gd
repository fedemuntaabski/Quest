class_name PauseController
extends Node

## Tactical pause (Space): Engine.time_scale 0 (Tweens/Timers/physics delta stop,
## HUD/building still work). Kept across the Esc pause, which forces 1 while open
## (and death/victory run at 1: their overlays tween); back to ACTIVE restores it.
## Owns the global time_scale: it is reset to 1 when the floor leaves the tree.
## X (game_speed) toggles the running speed 1x/2x; the pause still wins (0).

const SPEEDS: Array[int] = [1, 2]

var _paused := false
var _speed_index := 0
var _state: GameStateManager


func setup(state: GameStateManager) -> void:
	_state = state
	_state.state_changed.connect(_on_state_changed)


func is_paused() -> bool:
	return _paused


## 1 or 2: the speed the game runs at when not paused.
func get_speed() -> int:
	return SPEEDS[_speed_index]


## Space pressed. Only while playing, so with the pause menu/overlays up Space
## stays ui_accept for their buttons. true = consumed.
func toggle() -> bool:
	if not _state.is_active():
		return false
	_paused = not _paused
	_apply()
	return true


## X pressed: 1x <-> 2x. Only while playing, like toggle(). true = consumed.
func toggle_speed() -> bool:
	if not _state.is_active():
		return false
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_apply()
	return true


func _on_state_changed(_new_state: int, _old_state: int) -> void:
	_apply()


## Esc pause / death / victory run at 1 (their overlays tween); only ACTIVE uses the chosen speed.
func _apply() -> void:
	var frozen := _paused and _state.is_active()
	var speed := get_speed() if _state.is_active() else 1
	Engine.time_scale = 0.0 if frozen else float(speed)
	var hud := ManagerLocator.get_hud()
	if hud:
		hud.set_pause_label(frozen, speed)


func _exit_tree() -> void:
	Engine.time_scale = 1.0

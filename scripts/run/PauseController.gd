class_name PauseController
extends Node

## Tactical pause (Space): Engine.time_scale 0 (Tweens/Timers/physics delta stop,
## HUD/building still work). Kept across the Esc pause, which forces 1 while open
## (and death/victory run at 1: their overlays tween); back to ACTIVE restores it.
## Owns the global time_scale: it is reset to 1 when the floor leaves the tree.

var _paused := false
var _state: GameStateManager


func setup(state: GameStateManager) -> void:
	_state = state
	_state.state_changed.connect(_on_state_changed)


func is_paused() -> bool:
	return _paused


## Space pressed. Only while playing, so with the pause menu/overlays up Space
## stays ui_accept for their buttons. true = consumed.
func toggle() -> bool:
	if not _state.is_active():
		return false
	_paused = not _paused
	_apply()
	return true


func _on_state_changed(_new_state: int, _old_state: int) -> void:
	_apply()


func _apply() -> void:
	var frozen := _paused and _state.is_active()
	Engine.time_scale = 0.0 if frozen else 1.0
	var hud := ManagerLocator.get_hud()
	if hud:
		hud.set_pause_label(frozen)


func _exit_tree() -> void:
	Engine.time_scale = 1.0

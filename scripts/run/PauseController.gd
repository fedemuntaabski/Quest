class_name PauseController
extends Node

## Tactical pause (Space): Engine.time_scale 0 (Tweens/Timers/physics delta stop,
## HUD/building still work). Kept across the Esc pause, which forces 1 while open
## (and death/victory run at 1: their overlays tween); back to ACTIVE restores it.
## Owns the global time_scale: it is reset to 1 when the floor leaves the tree.
## X (game_speed) toggles the running speed 1x/2x; the pause still wins (0).
##
## coop-12, online: Space is a vote (NetCommands "pause_vote" -> vote() on the
## host). The pause flips with a simple majority of the players, or when
## NetConfig.pause_vote_window_sec runs out with at least one vote; a co-op pause
## ends by itself after NetConfig.max_pause_sec. Only the host changes the speed.
## Clients never decide: they mirror the host's time_scale from the snapshots
## (mirror_scale) and the vote count from a "pause_vote" event (show_vote).
## Vote clocks run on real time (time_scale is 0 while paused).
##
## Always processes: Main2d freezes with the tree, so this node keeps its two
## always-on jobs going on a paused tree: Esc and the run clock.

const SPEEDS: Array[int] = [1, 2]
const HOST_ONLY_SPEED := "Solo el anfitrión cambia la velocidad"

var _paused := false
var _speed_index := 0
var _state: GameStateManager
## Host, online: peer -> true for the players asking to flip the pause.
var _votes: Dictionary = {}
var _vote_started_ms := 0
var _paused_at_ms := 0
var _last_tick_usec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(state: GameStateManager) -> void:
	_state = state
	_state.state_changed.connect(_on_state_changed)
	add_to_group("pause_controller")


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
	if Net.is_online():
		ManagerLocator.get_net_commands().request("pause_vote")
		return true
	_paused = not _paused
	_apply()
	return true


## X pressed: 1x <-> 2x. Only while playing, like toggle(). true = consumed.
## Online only the host sets it (it travels in the snapshots).
func toggle_speed() -> bool:
	if not _state.is_active():
		return false
	if not Net.is_authority():
		var text_mgr := ManagerLocator.get_floating_text_manager()
		var hero := ManagerLocator.get_player()
		if text_mgr and hero:
			text_mgr.spawn_text(hero.global_position + Vector2(0, -56), HOST_ONLY_SPEED, QuestPalette.PARCHMENT)
		return true
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_apply()
	return true


# ─── co-op vote (host) ────────────────────────────────────────

## Players who must agree for an immediate flip: more than half.
func votes_needed() -> int:
	var s := Net.session()
	var n: int = maxi(1, s.players.size()) if s else 1
	return n / 2 + 1


func get_vote_count() -> int:
	return _votes.size()


## Host: `peer` asks to flip the pause. Voting again withdraws the vote.
## "" = counted, else why not.
func vote(peer: int) -> String:
	if not _state.is_active():
		return "Ahora no se puede pausar"
	if _votes.has(peer):
		_votes.erase(peer)
	else:
		if _votes.is_empty():
			_vote_started_ms = Time.get_ticks_msec()
		_votes[peer] = true
	if _votes.size() >= votes_needed():
		_flip()
	else:
		_broadcast_vote()
	return ""


func _flip() -> void:
	_votes.clear()
	_paused = not _paused
	_paused_at_ms = Time.get_ticks_msec()
	QuestLogger.info(QuestLogger.Category.NETWORK, "Tactical pause %s" % ("on" if _paused else "off"))
	_apply()
	_broadcast_vote()


## Real-time checks (time_scale may be 0): vote window and the co-op pause cap.
func _process(_delta: float) -> void:
	_tick_run_clock()
	if not (Net.is_online() and Net.is_authority()):
		return
	poll(Time.get_ticks_msec())


## progresion-10: run time = real time while the run is ACTIVE (the tactical pause
## counts, the Esc menu and the end screens don't).
func _tick_run_clock() -> void:
	var now := Time.get_ticks_usec()
	var session := ManagerLocator.get_game_session()
	if session and _last_tick_usec > 0 and _state and _state.is_active():
		session.run_stats["elapsed_sec"] = float(session.run_stats.get("elapsed_sec", 0.0)) + (now - _last_tick_usec) / 1000000.0
	_last_tick_usec = now


## Main2d takes its keys itself unless the tree is paused (then only Esc does anything).
func _input(event: InputEvent) -> void:
	if get_tree().paused:
		get_parent()._input(event)


## Host: closes an expired vote window / ends an over-long pause at `now_ms`.
func poll(now_ms: int) -> void:
	var s := Net.session()
	var cfg: NetConfig = s.config if s else null
	if cfg == null:
		return
	if not _votes.is_empty() and now_ms - _vote_started_ms >= int(cfg.pause_vote_window_sec * 1000.0):
		_flip()
	elif _paused and _votes.is_empty() and now_ms - _paused_at_ms >= int(cfg.max_pause_sec * 1000.0):
		_flip()


func _broadcast_vote() -> void:
	var data := {"votes": _votes.size(), "needed": votes_needed(), "paused": _paused}
	show_vote(data)
	var main2d := ManagerLocator.get_main2d()
	var sync: NetSync = main2d.get("net_sync") if main2d else null
	if sync != null:
		sync.send_event("pause_vote", data)


## Every peer: HUD line for an open vote ("PAUSA? 1/2" / "SEGUIR? 1/2").
func show_vote(data: Dictionary) -> void:
	var hud := ManagerLocator.get_hud()
	if hud == null:
		return
	if int(data.get("votes", 0)) > 0:
		hud.set_pause_vote(int(data.votes), int(data.needed), bool(data.get("paused", _paused)))
	else:
		hud.set_pause_label(_paused and _state.is_active(), get_speed())


## Client: the host's time_scale arrived in a snapshot.
func mirror_scale(scale: float) -> void:
	var was_paused := _paused
	var was_speed := _speed_index
	_paused = scale == 0.0
	if scale > 0.0:
		_speed_index = maxi(0, SPEEDS.find(int(round(scale))))
	if was_paused != _paused or was_speed != _speed_index:
		var hud := ManagerLocator.get_hud()
		if hud:
			hud.set_pause_label(_paused, get_speed())


func _on_state_changed(_new_state: int, _old_state: int) -> void:
	_apply()


## Esc pause / death / victory run at 1 (their overlays tween); only ACTIVE uses the chosen speed.
func _apply() -> void:
	var frozen := _paused and _state.is_active()
	var speed := get_speed() if _state.is_active() else 1
	if Net.is_authority():  # a client takes time_scale from the host's snapshots
		Engine.time_scale = 0.0 if frozen else float(speed)
	var hud := ManagerLocator.get_hud()
	if hud:
		hud.set_pause_label(frozen, speed)


func _exit_tree() -> void:
	Engine.time_scale = 1.0

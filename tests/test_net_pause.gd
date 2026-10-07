extends SceneTree

## coop-12 phase 5: co-op tactical pause by vote. Over a live Main2d + HUD with
## a co-op host of 3 players: one vote does not pause, a majority does, the vote
## window closes an unanswered vote in favour, a vote can be withdrawn, the pause
## ends by itself at max_pause_sec, a client can't change the speed and mirrors
## the host's time_scale, the Esc menu does not pause the world online, and
## offline Space still pauses at once.
##   godot --headless --path . --script res://tests/test_net_pause.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	var net := root.get_node("NetSession") as CoopSession
	var cmds := root.get_node("NetCommands") as CoopCommands
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.standalone_floor = 1
	root.add_child(main2d)
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	var pause: PauseController = main2d.pause_controller
	var cfg := net.config
	var window_ms := int(cfg.pause_vote_window_sec * 1000.0)

	net.mode = CoopSession.Mode.HOST
	net.players = {1: net._new_player("A", "t1", 0), 2: net._new_player("B", "t2", 1), 3: net._new_player("C", "t3", 2)}
	_expect(pause.votes_needed() == 2, "3 players: 2 votes needed")

	# One vote (Space on the host) does not pause yet.
	_expect(pause.toggle(), "Space consumed online")
	_expect(pause.get_vote_count() == 1 and not pause.is_paused(), "one vote: no pause yet")
	_expect(Engine.time_scale == 1.0, "still running")
	_expect(hud.pause_label.visible and hud.pause_label.text.begins_with("PAUSA? 1/2"), "HUD shows the vote: %s" % hud.pause_label.text)
	# A second player agrees: majority.
	_expect(await cmds.run_command(2, "pause_vote", {}) == "", "client vote accepted")
	_expect(pause.is_paused() and Engine.time_scale == 0.0, "majority pauses")
	_expect(pause.get_vote_count() == 0, "votes reset after the flip")

	# Resume: one vote, then the window runs out -> applied anyway.
	pause.vote(3)
	_expect(pause.is_paused(), "one resume vote: still paused")
	pause.poll(Time.get_ticks_msec() + window_ms + 10)
	_expect(not pause.is_paused() and Engine.time_scale == 1.0, "window expired: resumed")

	# Withdrawn vote.
	pause.vote(2)
	pause.vote(2)
	_expect(pause.get_vote_count() == 0, "voting twice withdraws")
	pause.poll(Time.get_ticks_msec() + window_ms + 10)
	_expect(not pause.is_paused(), "no vote left: nothing happens")

	# Max pause.
	pause.vote(1)
	pause.vote(2)
	_expect(pause.is_paused(), "paused again")
	pause.poll(Time.get_ticks_msec() + int(cfg.max_pause_sec * 1000.0) + 10)
	_expect(not pause.is_paused(), "pause ends at max_pause_sec")

	# Speed: host only.
	_expect(pause.toggle_speed() and pause.get_speed() == 2 and Engine.time_scale == 2.0, "host sets 2x")
	pause.toggle_speed()
	net.mode = CoopSession.Mode.CLIENT
	_expect(pause.toggle_speed() and pause.get_speed() == 1, "a client can't change the speed")
	pause.mirror_scale(0.0)
	_expect(pause.is_paused() and hud.pause_label.text == HUDController.PAUSE_TEXT, "client mirrors the host's pause")
	pause.mirror_scale(2.0)
	_expect(not pause.is_paused() and pause.get_speed() == 2, "client mirrors the host's speed")
	pause.mirror_scale(1.0)
	net.mode = CoopSession.Mode.HOST

	# Esc menu online: the world keeps running.
	var gsm: GameStateManager = main2d.game_state_manager
	main2d.pause_menu.open()
	_expect(gsm.is_active() and not paused, "online Esc menu doesn't pause the tree")
	await main2d.pause_menu.close()

	# Offline: Space pauses at once.
	net.mode = CoopSession.Mode.OFFLINE
	net.players.clear()
	pause.toggle()
	_expect(pause.is_paused() and Engine.time_scale == 0.0, "offline: immediate pause")
	pause.toggle()
	main2d.pause_menu.open()
	_expect(not gsm.is_active(), "offline Esc menu still pauses")
	await main2d.pause_menu.close()

	Engine.time_scale = 1.0
	paused = false
	hud.queue_free()
	main2d.queue_free()
	await process_frame
	for f in failures:
		printerr("FAIL: ", f)
	print("test_net_pause: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

extends SceneTree

## coop-12 phase 6 (in one process; the two-process reconnection is
## tests/test_net_sync.gd): a player dropping mid-run hands its heroes to the host
## (HOST_CONTROL) or leaves them ownerless (DEFENSIVE_AI) and is remembered by
## token for a rejoin; a new run forgets it; a client losing its host ends the run
## with the summary and no retry.
##   godot --headless --path . --script res://tests/test_net_robustness.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const OTHER := 2

var failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	var net := root.get_node("NetSession") as CoopSession
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	var ida: String = main2d.heroes[0].stats.hero_id
	var idb: String = main2d.heroes[1].stats.hero_id
	var cfg := net.config
	var mode_before := cfg.orphan_mode

	net.mode = CoopSession.Mode.HOST
	net.in_run = true
	for orphan_mode in [NetConfig.OrphanMode.HOST_CONTROL, NetConfig.OrphanMode.DEFENSIVE_AI]:
		cfg.orphan_mode = orphan_mode
		var gone := net._new_player("Otro", "tok2", 1)
		net.players = {1: net._new_player("Host", "tok1", 0)}
		net.hero_owner = {ida: 1, idb: OTHER}
		net._on_player_left_run(OTHER, gone)
		var expected := 1 if orphan_mode == NetConfig.OrphanMode.HOST_CONTROL else 0
		_expect(net.hero_owner[idb] == expected, "orphan mode %d: hero owner %d" % [orphan_mode, net.hero_owner[idb]])
		_expect(net.away.has("tok2") and net.away.tok2.heroes == [idb] and net.away.tok2.color == 1,
			"the dropped player is remembered by token: %s" % [net.away])
		_expect(net.hero_owner[ida] == 1, "the host keeps its own hero")
	_expect(net.owns(idb, 1) == false, "defensive AI: nobody owns the hero")
	cfg.orphan_mode = mode_before

	# Party for a rejoin = the heroes in play.
	var party: Array = [ida, idb]
	_expect(net.current_party_ids() == party, "rejoin party = heroes in play: %s" % [net.current_party_ids()])

	# A new run forgets the dropped players.
	net._reset("test")
	_expect(net.away.is_empty() and net.current_floor == 1 and not net.in_run, "reset clears away/floor/in_run")

	# Client losing the host: the run ends with the summary, no retry.
	main2d._on_session_ended("menu")
	_expect(not main2d.death_overlay.visible, "a normal leave does not end the run")
	main2d._on_session_ended("host_lost")
	_expect(main2d.death_overlay.visible, "host lost: end screen")
	_expect(not main2d.death_overlay._retry_button.visible, "host lost: no retry")
	var label := main2d.death_overlay.get_node("CenterContainer/VBoxContainer/DeathLabel") as Label
	_expect(label.text.contains("anfitrión"), "host lost title: %s" % label.text)

	paused = false
	Engine.time_scale = 1.0
	main2d.queue_free()
	await process_frame
	for f in failures:
		printerr("FAIL: ", f)
	print("test_net_robustness: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

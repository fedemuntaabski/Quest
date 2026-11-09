extends SceneTree

## coop-12 phase 4: per-player control. Over a live Main2d (fallback map) with a
## co-op host where hero A is ours (peer 1) and hero B belongs to peer 2:
## SelectionManager only selects own heroes (click, toggle, groups), an owner
## change re-filters the selection, Player/HeroPortrait show the owner's color,
## an ownerless (defensive AI) hero is grey, and offline everything is selectable.
##   godot --headless --path . --script res://tests/test_net_ownership.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const OTHER := 2

var failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	var net := root.get_node("NetSession") as CoopSession
	var sel := root.get_node("SelectionManager")
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()

	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var ida := a.stats.hero_id
	var idb := b.stats.hero_id
	var only_a: Array[String] = [ida]
	var both: Array[String] = [ida, idb]

	# Offline: both heroes are ours, no owner color.
	_expect(sel.select_only(idb), "offline: any hero is selectable")
	_expect(a.get_owner_color().a == 0.0, "offline: no owner ring")

	# Co-op host: B belongs to peer 2.
	net.mode = CoopSession.Mode.HOST
	net.players = {1: net._new_player("Host", "t1", 0), OTHER: net._new_player("Otro", "t2", 1)}
	net.hero_owner = {ida: 1, idb: OTHER}
	net.in_run = true
	net.lobby_changed.emit()
	_expect(net.is_online(), "host with the default peer counts as online")
	_expect(sel.get_selected_ids() == only_a,
		"owner change drops the other player's hero and selects an own one: %s" % [sel.get_selected_ids()])
	_expect(not sel.select_only(idb), "can't select another player's hero")
	_expect(not sel.toggle(idb), "can't add another player's hero")
	_expect(not sel.set_selection(both) or sel.get_selected_ids() == only_a,
		"set_selection keeps only own heroes")
	sel.groups[1] = [ida, idb]
	_expect(sel.get_group(1, true) == only_a, "live group members are own heroes only")
	sel.refresh_ownership()
	_expect(sel.groups[1] == [ida], "refresh_ownership drops foreign heroes from groups")

	_expect(a.get_owner_color() == net.config.color_for(0), "own hero ring = host color")
	_expect(b.get_owner_color() == net.config.color_for(1), "other hero ring = peer 2 color")
	net.hero_owner[idb] = 0  # defensive AI: nobody controls it
	_expect(b.get_owner_color() == Color(0.6, 0.6, 0.6), "ownerless hero is grey")

	# Peer 2 leaves, its hero goes to the host: now selectable.
	net.hero_owner[idb] = 1
	net.lobby_changed.emit()
	_expect(sel.toggle(idb), "a hero handed to the host becomes selectable")

	# juego-22: 4 players, 1 hero each (NetSession._enter_run -> GameSession.set_party):
	# every player's hero spawns (the single-player PartyConfig.party_size 2 cut players 3-4).
	var four: Array[String] = ["warrior", "mage", "rogue", "tank"]
	var session := root.get_node("GameSession")
	session.set_party(four)
	net.players = {1: net._new_player("Host", "t1", 0), 2: net._new_player("B", "t2", 1), 3: net._new_player("C", "t3", 2), 4: net._new_player("D", "t4", 3)}
	net.hero_owner = {"warrior": 1, "mage": 2, "rogue": 3, "tank": 4}
	var coop := (load(MAIN2D_PATH) as PackedScene).instantiate()
	coop.force_fallback_layout = true
	main2d.queue_free()
	await process_frame
	root.add_child(coop)
	await process_frame
	_expect(coop.heroes.size() == 4, "co-op party of 4 spawned %d heroes" % coop.heroes.size())
	session.clear()
	main2d = coop

	# Back offline.
	net.mode = CoopSession.Mode.OFFLINE
	net.in_run = false
	net.players.clear()
	net.hero_owner.clear()
	_expect(sel.select_only(idb), "offline again: everything selectable")
	sel.reset()
	main2d.queue_free()
	await process_frame
	for f in failures:
		printerr("FAIL: ", f)
	print("test_net_ownership: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

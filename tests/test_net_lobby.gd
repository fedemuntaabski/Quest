extends SceneTree

## coop-12 phase 2: lobby over local ENet with two NetSessions in one process
## (each in its own SceneMultiplayer branch, so RPC paths match). Register,
## roster sync, hero quota and "no repeats", ready/start rules, the shared start
## (same seed, same owners, same party on both), and clean leave/host-lost.
##   godot --headless --path . --script res://tests/test_net_lobby.gd

const PORT := 7795
const TIMEOUT := 5.0

var failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	var host := _session("HostBranch")
	var client := _session("ClientBranch")
	var t := EnetTransport.new(host.api)
	t.port = PORT
	_check(host.host(4, t) == OK, "host starts")
	_check(host.players.size() == 1 and host.heroes_per_player() == 2, "alone: 1 player, 2 heroes")
	_check(client.join("127.0.0.1:%d" % PORT, EnetTransport.new(client.api)) == OK, "client joins")
	_check(await _wait(func() -> bool: return host.players.size() == 2 and client.players.size() == 2), "roster synced to both")
	var cid := client.local_peer()
	_check(host.heroes_per_player() == 1 and client.heroes_per_player() == 1, "2 players: 1 hero each")
	_check(host.player_color(1) != host.player_color(cid), "players get different colors")

	host.request_pick("warrior")
	client.request_pick("warrior")  # taken: refused by the host
	client.request_pick("mage")
	_check(await _wait(func() -> bool: return client.players[cid].heroes == ["mage"]), "client pick synced")
	_check(host.players[1].heroes == ["warrior"], "host keeps warrior (no repeats)")
	_check(host.pick_block_reason(cid, "warrior") != "", "taken hero is refused")
	_check(host.pick_block_reason(cid, "rogue") != "", "quota refuses a 2nd hero")
	_check(host.pick_block_reason(1, "nope") == "Héroe desconocido", "unknown hero refused")

	_check(host.start_block_reason() != "", "cannot start before everyone is ready")
	host.request_set_ready(true)
	client.request_set_ready(true)
	_check(await _wait(func() -> bool: return host.start_block_reason() == ""), "everyone ready -> can start")
	_check(client.start_block_reason() != "" and not client.start_run(), "a client cannot start")

	_check(host.start_run(), "host starts the run")
	_check(await _wait(func() -> bool: return client.in_run), "client receives start_run")
	_check(host.run_seed == client.run_seed and host.run_seed != 0, "same seed on both")
	_check(host.hero_owner == {"warrior": 1, "mage": cid} and client.hero_owner == host.hero_owner, "same owners")
	_check(client.owns("mage") and not client.owns("warrior") and host.owns("warrior"), "owns() per peer")
	var gs := root.get_node("GameSession")
	_check(Array(gs.get_party_ids()) == ["warrior", "mage"], "party = both picks")

	var ended := [""]
	client.session_ended.connect(func(r: String) -> void: ended[0] = r)
	host.leave("test")
	_check(await _wait(func() -> bool: return ended[0] != ""), "client notices the host leaving (%s)" % ended[0])
	_check(not client.is_online() and client.players.is_empty(), "client back offline, roster cleared")

	print("test_net_lobby: %s (%d failures)" % ["OK" if failures.is_empty() else "FAIL", failures.size()])
	for f in failures:
		print("  - " + f)
	quit(0 if failures.is_empty() else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## A NetSession under its own SceneMultiplayer branch (RPC paths are relative to it).
func _session(branch_name: String) -> CoopSession:
	var branch := Node.new()
	branch.name = branch_name
	root.add_child(branch)
	var api := SceneMultiplayer.new()
	set_multiplayer(api, branch.get_path())
	var s := CoopSession.new()
	s.name = "NetSession"
	s.api = api
	branch.add_child(s)
	return s


func _wait(cond: Callable) -> bool:
	var t := 0.0
	while not cond.call() and t < TIMEOUT:
		await create_timer(1.0 / 60.0).timeout
		t += 1.0 / 60.0
	return cond.call()

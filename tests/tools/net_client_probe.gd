extends SceneTree

## coop-12: the client half of tests/test_net_sync.gd, launched by it as a second
## headless Godot. Joins the host over local ENet, picks a free hero, gets ready,
## plays the shared run (Main.tscn, like the real game) and reports what it saw
## to user://net_probe_<token>.json. `--leave-after=N`: drop the connection after
## the checks and rejoin N s later (reconnection test).
##   godot --headless --path . --script res://tests/tools/net_client_probe.gd -- --port=7801 --net-token=probe1

const TIMEOUT := 40.0

var report := {"ok": false, "step": "start"}
var net: CoopSession
var token := "probe"
var port := 7801
var leave_after := -1.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			port = int(a.substr(7))
		elif a.begins_with("--net-token="):
			token = a.substr(12)
		elif a.begins_with("--leave-after="):
			leave_after = float(a.substr(14))
	await process_frame
	root.add_child((load("res://scenes/Main.tscn") as PackedScene).instantiate())
	net = root.get_node("NetSession") as CoopSession
	net.lobby_changed.connect(_on_lobby)
	await _join()
	if not await _wait(func() -> bool: return _sync() != null and _sync().snapshots_received > 5, "snapshots"):
		return _finish()
	var main2d := ManagerLocator.get_main2d()
	report["map_seed"] = main2d.floor_manager.map_seed
	report["own_hero"] = _own_hero_id()
	# Wait for the host to open a door, then walk our hero there through a command.
	if not await _wait(func() -> bool: return _revealed_rooms(main2d).size() >= 2, "door opened by host"):
		return _finish()
	var target: String = _revealed_rooms(main2d)[1]
	report["move_target"] = target
	ManagerLocator.get_net_commands().request("move", {"heroes": [report.own_hero], "zone": target})
	if not await _wait(func() -> bool: return _hero(report.own_hero).current_zone_id == target, "own hero arrived (snapshots)"):
		return _finish()
	ManagerLocator.get_net_commands().request("move", {"heroes": [_other_hero_id()], "zone": target})
	await _wait(func() -> bool: return _sync().hash_checks >= 1, "a hash check")
	report["hash_checks"] = _sync().hash_checks
	report["desyncs"] = _sync().desyncs
	report["revealed"] = _revealed_rooms(main2d)
	report["dust"] = ManagerLocator.get_resource_manager().get_resource("dust")
	report["enemies_seen"] = main2d.enemy_manager.get_enemies().size()
	report["other_hero_zone"] = _hero(_other_hero_id()).current_zone_id
	if leave_after >= 0.0:
		report["step"] = "leaving"
		_write()
		net.leave("probe_leave")
		await create_timer(leave_after).timeout
		await _join()
		if not await _wait(func() -> bool: return _sync() != null and _sync().snapshots_received > 3, "snapshots after rejoin"):
			return _finish()
		report["rejoin_revealed"] = _revealed_rooms(ManagerLocator.get_main2d())
		report["rejoin_owns"] = net.owns(report.own_hero)
		report["rejoin_hero_zone"] = _hero(report.own_hero).current_zone_id
	report["ok"] = true
	report["step"] = "done"
	_finish()


func _join() -> void:
	var t := EnetTransport.new(net.api)
	net.join("127.0.0.1:%d" % port, t)
	await _wait(func() -> bool: return ManagerLocator.get_main2d() != null and _sync() != null, "run started")


func _on_lobby() -> void:
	if net.in_run or not net.players.has(net.local_peer()):
		return
	var me: Dictionary = net.players[net.local_peer()]
	if me.heroes.size() < net.heroes_per_player():
		for data in CharacterDatabase.get_all():
			if net.hero_taken_by(data.character_id) == 0:
				net.request_pick(data.character_id)
				return
	elif not me.ready:
		net.request_set_ready(true)


func _sync() -> NetSync:
	var main2d := ManagerLocator.get_main2d()
	return main2d.net_sync if main2d and is_instance_valid(main2d) else null


func _own_hero_id() -> String:
	for id in net.hero_owner:
		if net.hero_owner[id] == net.local_peer():
			return id
	return ""


func _other_hero_id() -> String:
	for id in net.hero_owner:
		if net.hero_owner[id] != net.local_peer():
			return id
	return ""


func _hero(id: String) -> Player:
	for hero in ManagerLocator.get_heroes():
		if hero.stats.hero_id == id:
			return hero
	return null


func _revealed_rooms(main2d: Node) -> Array:
	var out := []
	var rm: RoomManager = main2d.room_manager
	for zone_id in rm.get_zone_ids():
		if rm.get_zone_kind(zone_id) == "room" and rm.is_zone_revealed(zone_id):
			out.append(zone_id)
	out.sort()
	out.erase(rm.get_start_zone_id())
	out.push_front(rm.get_start_zone_id())
	return out


func _wait(cond: Callable, step: String) -> bool:
	report["step"] = step
	var t := 0.0
	while t < TIMEOUT:
		if cond.call():
			return true
		await create_timer(0.1).timeout
		t += 0.1
	report["error"] = "timeout: " + step
	return false


func _write() -> void:
	var f := FileAccess.open("user://net_probe_%s.json" % token, FileAccess.WRITE)
	f.store_string(JSON.stringify(report))
	f.close()


func _finish() -> void:
	_write()
	net.leave("probe_done")
	quit(0 if report.ok else 1)

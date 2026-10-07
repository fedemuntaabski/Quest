extends SceneTree

## coop-12: host-authoritative sync with two real processes over local ENet.
## This process hosts (Main.tscn, like the game); it launches
## tests/tools/net_client_probe.gd as a second headless Godot. Checked: the
## lobby flow and shared start (same map seed), snapshots reaching the client,
## a host-side door showing up on the client (RunState), a client move command
## executed by the host and seen back through snapshots, a refused command for a
## hero the client doesn't own, a clean desync hash, and reconnection (the
## client leaves and rejoins the run in progress, gets the state and its hero).
##   godot --headless --path . --script res://tests/test_net_sync.gd

const PORT := 7801
const TIMEOUT := 60.0
const TOKEN := "probe_sync"

var failures: Array[String] = []
var net: CoopSession


func _initialize() -> void:
	await process_frame
	root.add_child((load("res://scenes/Main.tscn") as PackedScene).instantiate())
	net = root.get_node("NetSession") as CoopSession
	var report_path := "user://net_probe_%s.json" % TOKEN
	if FileAccess.file_exists(report_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(report_path))
	var t := EnetTransport.new(net.api)
	t.port = PORT
	_expect(net.host(4, t) == OK, "host starts")
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/tools/net_client_probe.gd", "--", "--port=%d" % PORT, "--net-token=%s" % TOKEN,
		"--net-name=Sonda", "--leave-after=1.0"])
	_expect(pid > 0, "client process launched")

	if await _wait(func() -> bool: return net.players.size() == 2, "client joined the lobby"):
		net.request_pick(_free_hero())
		net.request_set_ready(true)
		if await _wait(func() -> bool: return net.start_block_reason() == "", "everyone ready"):
			_expect(net.start_run(), "run started")
			await _host_side()
	await _wait(func() -> bool: return not OS.is_process_running(pid), "client process exit")
	_check_report(report_path)

	net.leave("test_done")
	for f in failures:
		printerr("FAIL: ", f)
	print("test_net_sync: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _host_side() -> void:
	if not await _wait(func() -> bool: return ManagerLocator.get_main2d() != null and not net.ready_floor.is_empty(), "client loaded the floor"):
		return
	var main2d := ManagerLocator.get_main2d()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	var rm: RoomManager = main2d.room_manager
	var start := rm.get_start_zone_id()
	var my_hero := ""
	for id in net.hero_owner:
		if net.hero_owner[id] == 1:
			my_hero = id
	var door: Door = null
	for d in rm.get_all_doors():
		if d.get_target_room_for(start) != "" and not rm.is_group_revealed(d.target_room_id):
			door = d
	_expect(door != null, "a door next to the start room")
	if door:
		_expect(await ManagerLocator.get_net_commands().request("open_door", {"door": door.door_id, "heroes": [my_hero]}) == "", "host opens a door")
	# The client walks its own hero in through a command; the host must execute it.
	var client_hero := ""
	for id in net.hero_owner:
		if net.hero_owner[id] != 1:
			client_hero = id
	var hero: Player = null
	for h in ManagerLocator.get_heroes():
		if h.stats.hero_id == client_hero:
			hero = h
	await _wait(func() -> bool: return hero.current_zone_id != start, "host moved the client's hero")
	# Reconnection: the client leaves; its hero goes to the host; it comes back.
	await _wait(func() -> bool: return net.players.size() == 1, "client left mid-run")
	_expect(net.owns(client_hero, 1) or net.hero_owner.get(client_hero, 0) == 0, "orphan hero handed to the host (or ownerless)")
	await _wait(func() -> bool: return net.players.size() == 2, "client rejoined")
	await _wait(func() -> bool: return net.hero_owner.get(client_hero, 1) != 1, "hero given back to the returning player")


func _check_report(path: String) -> void:
	_expect(FileAccess.file_exists(path), "client report written")
	if not FileAccess.file_exists(path):
		return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	print("client report: ", report)
	_expect(report.get("ok", false), "client finished its checks (%s %s)" % [report.get("step"), report.get("error", "")])
	var main2d := ManagerLocator.get_main2d()
	if main2d:
		_expect(int(report.get("map_seed", 0)) == main2d.floor_manager.map_seed, "same map seed on both")
		var rm: RoomManager = main2d.room_manager
		var host_rooms := []
		for z in rm.get_zone_ids():
			if rm.get_zone_kind(z) == "room" and rm.is_zone_revealed(z):
				host_rooms.append(z)
		_expect((report.get("revealed", []) as Array).size() == host_rooms.size(), "client revealed what the host revealed")
	_expect(int(report.get("hash_checks", 0)) >= 1, "a desync hash was checked")
	_expect(int(report.get("desyncs", -1)) == 0, "no desync")
	_expect(report.get("other_hero_zone", "") != report.get("move_target", "x"), "the host refused moving a hero the client doesn't own")
	_expect(report.get("rejoin_owns", false), "after rejoining the client owns its hero again")
	_expect((report.get("rejoin_revealed", []) as Array).size() == (report.get("revealed", []) as Array).size(), "rejoin gets the discovered rooms")


func _free_hero() -> String:
	for data in CharacterDatabase.get_all():
		if net.hero_taken_by(data.character_id) == 0:
			return data.character_id
	return ""


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _wait(cond: Callable, step: String) -> bool:
	var t := 0.0
	while t < TIMEOUT:
		if cond.call():
			return true
		await create_timer(0.1).timeout
		t += 0.1
	failures.append("timeout: " + step)
	return false

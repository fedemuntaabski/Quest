extends SceneTree

## audio-18: no sound plays twice in co-op, with two real processes over local ENet.
## This process hosts (Main.tscn) and launches tests/tools/net_client_probe.gd with
## `--audio-keys`. The host opens a door, lights a room, builds a Forja (host-only
## events: AudioDirector.HOST_KEYS, played by the host and relayed as NetSync "sfx")
## and spawns a wave (alert: enemies_appeared already runs on every peer). Each key
## must fire once on the host (alert: once per spawn) and the same number of times on the client: the client's RunState apply (set_lit,
## BuildingSlot.build) must not add a second one.
##   godot --headless --path . --script res://tests/test_audio_net.gd

const PORT := 7803
const TIMEOUT := 60.0
const TOKEN := "probe_audio"
const KEYS := ["door", "light", "build", "alert"]

var failures: Array[String] = []
var net: CoopSession
var audio: Node


func _initialize() -> void:
	await process_frame
	root.add_child((load("res://scenes/Main.tscn") as PackedScene).instantiate())
	net = root.get_node("NetSession") as CoopSession
	audio = root.get_node("AudioDirector")
	var report_path := "user://net_probe_%s.json" % TOKEN
	if FileAccess.file_exists(report_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(report_path))
	var t := EnetTransport.new(net.api)
	t.port = PORT
	_expect(net.host(4, t) == OK, "host starts")
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--log-file", ProjectSettings.globalize_path("user://net_probe_audio_client.log"),
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/tools/net_client_probe.gd", "--", "--port=%d" % PORT, "--net-token=%s" % TOKEN,
		"--net-name=Sonda", "--audio-keys=%s" % ",".join(KEYS)])
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
	print("test_audio_net: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _host_side() -> void:
	if not await _wait(func() -> bool: return ManagerLocator.get_main2d() != null and not net.ready_floor.is_empty(), "client loaded the floor"):
		return
	await create_timer(0.5).timeout
	var main2d := ManagerLocator.get_main2d()
	var em: EnemyManager = main2d.enemy_manager
	for enemy in em.get_enemies():
		enemy.queue_free()
	audio.fired.clear()
	var cmds := ManagerLocator.get_net_commands()
	var rm: RoomManager = main2d.room_manager
	var start := rm.get_start_zone_id()
	var my_hero := ""
	for id in net.hero_owner:
		if net.hero_owner[id] == 1:
			my_hero = id
	var door: Door = null
	for d in rm.get_all_doors():
		if not d.is_secret and not d.is_opened() and rm.get_zone_kind(d.target_room_id) == "room" and d.get_target_room_for(start) != "":
			# guardado-19: a Rest/Prisoner room blocks spawns and the wave below needs it (seed flake)
			var spawnable := false
			for z in rm.get_group_zone_ids(d.target_room_id):
				if rm.get_zone_kind(z) == "room" and not em._spawns_blocked(z):
					spawnable = true
			if spawnable or door == null:
				door = d
	_expect(door != null, "a door next to the start room")
	if door == null:
		return
	var reason: String = await cmds.request("open_door", {"door": door.door_id, "heroes": [my_hero]})
	_expect(reason == "", "host opens the door: '%s'" % reason)
	await create_timer(0.3).timeout
	var room := ""
	for z in rm.get_group_zone_ids(door.target_room_id):
		if rm.get_zone_kind(z) == "room":
			room = z
	var res := ManagerLocator.get_resource_manager()
	res.add_resource("embers", 100)
	res.add_resource("iron", 200)
	reason = await cmds.request("toggle_light", {"zone": room})
	_expect(reason == "", "host lights %s: '%s'" % [room, reason])
	await create_timer(0.3).timeout
	reason = await cmds.request("build", {"zone": start, "slot": 0, "type": Building.BuildingType.FORJA})
	_expect(reason == "", "host builds a Forja: '%s'" % reason)
	await create_timer(0.3).timeout
	reason = await cmds.request("toggle_light", {"zone": room})  # off again (silent): a dark room for the wave
	_expect(reason == "", "host switches %s off: '%s'" % [room, reason])
	for enemy in em.get_enemies():
		enemy.queue_free()
	await process_frame
	_expect(em.spawn_wave(1) == 1, "host spawns a wave")
	await create_timer(0.5).timeout
	for k in ["door", "light", "build"]:
		_expect(int(audio.fired.get(StringName(k), 0)) == 1, "host: '%s' fired %d times (want 1)" % [k, int(audio.fired.get(StringName(k), 0))])
	# the door may also roll an invasion: one more alert, on both peers alike
	_expect(int(audio.fired.get(&"alert", 0)) >= 1, "host: the wave's alert fired")


func _check_report(path: String) -> void:
	_expect(FileAccess.file_exists(path), "client report written")
	if not FileAccess.file_exists(path):
		return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	print("client report: ", report)
	_expect(report.get("ok", false), "client finished (%s %s)" % [report.get("step"), report.get("error", "")])
	var fired: Dictionary = report.get("sfx_fired", {})
	for k in KEYS:
		var host_n := int(audio.fired.get(StringName(k), 0))
		_expect(int(fired.get(k, 0)) == host_n, "client: '%s' fired %d times, host %d" % [k, int(fired.get(k, 0)), host_n])
	_expect(str(report.get("music", "")).ends_with("floor_1.ogg"), "client plays the floor 1 theme (%s)" % report.get("music", ""))


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

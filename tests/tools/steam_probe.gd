extends SceneTree

## coop-12: real-Steam check (needs the Steam client open; not a test_* file, the
## runner skips it). Init, host a Friends Only lobby through SteamTransport, read
## the join code, close and verify nothing stays open.
##   godot --headless --path . --script res://tests/tools/steam_probe.gd

const TIMEOUT := 15.0

var failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	var steam := root.get_node("SteamManager") as SteamManager
	_check(steam.is_steam_available(), "Steam initialized (is the client open?)")
	if steam.is_steam_available():
		var t := SteamTransport.new(root.multiplayer, steam)
		var code := [""]
		var fail := [""]
		t.hosted.connect(func(c: String) -> void: code[0] = c)
		t.failed.connect(func(r: String) -> void: fail[0] = r)
		_check(t.host(4) == OK, "host() accepted")
		var waited := 0.0
		while code[0] == "" and fail[0] == "" and waited < TIMEOUT:
			await create_timer(0.1).timeout
			waited += 0.1
		print("steam_probe: lobby code=%s fail=%s name=%s token=%s" % [code[0], fail[0], t.get_display_name(), t.get_player_token()])
		_check(code[0].is_valid_int() and int(code[0]) != 0, "lobby created with an id")
		_check(root.multiplayer.multiplayer_peer != null and root.multiplayer.is_server(), "SteamMultiplayerPeer is the host")
		_check(t.get_join_code() == code[0], "join code = lobby id")
		t.close()
		_check(steam.lobby_manager.current_lobby_id == 0 and root.multiplayer.multiplayer_peer == null, "close leaves the lobby and the peer")
	print("steam_probe: %s (%d failures)" % ["OK" if failures.is_empty() else "FAIL", failures.size()])
	for f in failures:
		print("  - " + f)
	quit(0 if failures.is_empty() else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

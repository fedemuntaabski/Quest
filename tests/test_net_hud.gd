extends SceneTree

## coop-12 phase 7: co-op HUD over a live Main2d + HUD as a co-op host with a
## second player: the player list (color, host/you tags, ping), join/leave
## notices, the predefined chat (valid and refused indexes, the T key) and the
## map ping (refused on a hidden zone; minimap ring + world marker on a
## discovered one). Offline the co-op widgets are not built.
##   godot --headless --path . --script res://tests/test_net_hud.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"
const OTHER := 2

var failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	var net := root.get_node("NetSession") as CoopSession
	var cmds := root.get_node("NetCommands") as CoopCommands
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.standalone_floor = 1
	root.add_child(main2d)
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()

	# Offline HUD: no co-op widgets.
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	_expect(hud.player_list == null and hud.chat_panel == null, "offline: no player list / chat")
	hud.queue_free()
	await process_frame

	net.mode = CoopSession.Mode.HOST
	net.players = {1: net._new_player("Host", "t1", 0), OTHER: net._new_player("Otro", "t2", 1)}
	net.pings = {OTHER: 42}
	hud = (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	await process_frame

	# Player list.
	_expect(hud.player_list != null and hud.player_list.visible, "online: player list shown")
	if hud.player_list:
		_expect(hud.player_list.get_child_count() == 2, "one row per player")
		var host_row := hud.player_list.row_text(1)
		_expect(host_row.contains("Host") and host_row.contains("anfitrión") and host_row.contains("vos"), "host row: %s" % host_row)
		_expect(hud.player_list.row_text(OTHER).contains("42 ms"), "ping shown: %s" % hud.player_list.row_text(OTHER))

	# Join/leave notices.
	net.player_joined.emit(3, "Tercero")
	_expect(hud._hint_panel.visible and hud._hint_body.text.contains("Tercero se unió"), "join notice")
	net.player_left.emit(3, "Tercero")
	_expect(hud._hint_body.text.contains("Tercero salió"), "leave notice")

	# Chat.
	_expect(await _run(cmds, OTHER, "chat", {"i": 1}) == "", "chat accepted")
	var lines: Array[String] = hud.chat_panel.get_lines()
	_expect(lines.size() == 1 and lines[0] == "Otro: %s" % net.config.chat_messages[1], "chat line: %s" % [lines])
	_expect(await _run(cmds, OTHER, "chat", {"i": 99}) == CoopCommands.INVALID, "unknown chat message refused")
	_expect(await _run(cmds, OTHER, "chat", {"i": "x"}) == CoopCommands.INVALID, "chat index must be int")
	for i in 7:
		await _run(cmds, 1, "chat", {"i": 0})
	_expect(hud.chat_panel.get_lines().size() == ChatPanel.MAX_LINES, "chat keeps the last lines")
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	hud._unhandled_key_input(key)
	_expect(hud.chat_panel.is_menu_open(), "T opens the chat menu")
	hud._unhandled_key_input(key)
	_expect(not hud.chat_panel.is_menu_open(), "T closes it")

	# Map ping.
	var rm: RoomManager = main2d.room_manager
	var start := rm.get_start_zone_id()
	var hidden := ""
	for z in rm.get_zone_ids():
		if not rm.is_zone_revealed(z):
			hidden = z
	_expect(await _run(cmds, OTHER, "map_ping", {"zone": hidden}) == CoopCommands.INVALID, "no ping on a hidden zone")
	_expect(await _run(cmds, OTHER, "map_ping", {"zone": start}) == "", "ping on a discovered room")
	_expect(hud.minimap.has_map_ping(start), "minimap ring")
	var markers := rm.get_children().filter(func(n: Node) -> bool: return n is MapPingMarker)
	_expect(markers.size() == 1 and markers[0].color == net.player_color(OTHER), "world marker in the player's color")

	net.mode = CoopSession.Mode.OFFLINE
	net.players.clear()
	net.pings.clear()
	hud.queue_free()
	main2d.queue_free()
	await process_frame
	for f in failures:
		printerr("FAIL: ", f)
	print("test_net_hud: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _run(cmds: CoopCommands, sender: int, cmd: String, args: Dictionary) -> String:
	cmds._rate.clear()
	return await cmds.run_command(sender, cmd, args)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

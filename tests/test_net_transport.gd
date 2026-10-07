extends SceneTree

## coop-12 phase 1: NetworkTransport over local ENet, host and client in one
## process (two SceneMultiplayer branches). Connects, both sides see each other,
## the client leaves and the host notices; NetSession.leave() goes back offline.
##   godot --headless --path . --script res://tests/test_net_transport.gd

const PORT := 7791
const TIMEOUT := 5.0

var failures: Array[String] = []


func _initialize() -> void:
	await process_frame  # root enters the tree after _initialize starts
	_check_parse_code()
	await _check_enet_pair()
	await _check_session_api()
	print("test_net_transport: %s (%d failures)" % ["OK" if failures.is_empty() else "FAIL", failures.size()])
	for f in failures:
		print("  - " + f)
	quit(0 if failures.is_empty() else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _check_parse_code() -> void:
	_check(EnetTransport.parse_code("") == ["127.0.0.1", 7777], "empty code -> default")
	_check(EnetTransport.parse_code("10.0.0.2:9000") == ["10.0.0.2", 9000], "ip:port parsed")
	_check(EnetTransport.parse_code("myhost") == ["myhost", 7777], "host only -> default port")


## A node with its own SceneMultiplayer, so two peers live in one process.
func _branch(node_name: String) -> MultiplayerAPI:
	var n := Node.new()
	n.name = node_name
	root.add_child(n)
	var api := SceneMultiplayer.new()
	set_multiplayer(api, n.get_path())
	return api


func _wait(cond: Callable) -> bool:
	var t := 0.0
	while not cond.call() and t < TIMEOUT:
		await process_frame
		t += 1.0 / 60.0
		await create_timer(1.0 / 60.0).timeout
	return cond.call()


func _check_enet_pair() -> void:
	var host_api := _branch("HostBranch")
	var client_api := _branch("ClientBranch")
	var host := EnetTransport.new(host_api)
	host.port = PORT
	var hosted_code := [""]
	host.hosted.connect(func(code: String) -> void: hosted_code[0] = code)
	_check(host.host(4) == OK, "ENet host starts")
	_check(hosted_code[0] == "127.0.0.1:%d" % PORT, "hosted code is ip:port (%s)" % hosted_code[0])

	var seen := {"server": 0, "client": false, "left": 0}
	host_api.peer_connected.connect(func(id: int) -> void: seen.server = id)
	host_api.peer_disconnected.connect(func(id: int) -> void: seen.left = id)
	client_api.connected_to_server.connect(func() -> void: seen.client = true)
	var client := EnetTransport.new(client_api)
	_check(client.join(hosted_code[0]) == OK, "ENet client starts")
	_check(await _wait(func() -> bool: return seen.client and seen.server != 0), "client and host connect")
	_check(host_api.is_server() and not client_api.is_server(), "host is server, client is not")
	_check(client_api.get_unique_id() == seen.server, "host sees the client's peer id")

	client.close()
	_check(client_api.multiplayer_peer == null, "close() clears the client peer")
	_check(await _wait(func() -> bool: return seen.left != 0), "host notices the client leaving")
	host.close()
	_check(host_api.multiplayer_peer == null, "close() clears the host peer")


func _check_session_api() -> void:
	var api := _branch("SessionBranch")
	var session := CoopSession.new()
	session.api = api
	root.add_child(session)
	_check(not session.is_online() and session.is_authority(), "offline = local authority")
	var t := EnetTransport.new(api)
	t.port = PORT + 1
	var started := [false]
	session.session_started.connect(func(_m: int) -> void: started[0] = true)
	_check(session.host(4, t) == OK, "session hosts over an injected transport")
	_check(started[0] and session.is_online() and session.is_host(), "host session online")
	_check(session.get_join_code().ends_with(":%d" % (PORT + 1)), "join code exposed")
	var ended := [""]
	session.session_ended.connect(func(r: String) -> void: ended[0] = r)
	session.leave("test")
	_check(not session.is_online() and session.mode == CoopSession.Mode.OFFLINE, "leave -> offline")
	_check(ended[0] == "test" and api.multiplayer_peer == null, "leave closes the peer")
	session.queue_free()
	await process_frame

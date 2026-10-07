class_name EnetTransport
extends NetworkTransport

## EnetTransport (coop-12): plain ENet over IP for local tests and development
## without Steam. Join code = "ip:port" (default 127.0.0.1:7777).

const DEFAULT_PORT := 7777
const DEFAULT_ADDRESS := "127.0.0.1"

var port := DEFAULT_PORT
var _code := ""


func get_kind() -> String:
	return "enet"


func host(max_players: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, maxi(1, max_players - 1))
	if err != OK:
		failed.emit("enet_server:%d" % err)
		return err
	api.multiplayer_peer = peer
	_code = "%s:%d" % [DEFAULT_ADDRESS, port]
	QuestLogger.info(QuestLogger.Category.NETWORK, "ENet host listening on %d" % port)
	hosted.emit(_code)
	return OK


func join(code: String) -> Error:
	var parsed := parse_code(code)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(parsed[0], parsed[1])
	if err != OK:
		failed.emit("enet_client:%d" % err)
		return err
	api.multiplayer_peer = peer
	_code = "%s:%d" % parsed
	QuestLogger.info(QuestLogger.Category.NETWORK, "ENet joining %s" % _code)
	joining.emit(_code)
	return OK


func get_join_code() -> String:
	return _code


func get_player_token() -> String:
	return CoopSession.local_token()


## "host:port", "host" or "" -> [address, port].
static func parse_code(code: String) -> Array:
	var c := code.strip_edges()
	if c.is_empty():
		return [DEFAULT_ADDRESS, DEFAULT_PORT]
	var i := c.rfind(":")
	if i > 0 and c.substr(i + 1).is_valid_int():
		return [c.substr(0, i), int(c.substr(i + 1))]
	return [c, DEFAULT_PORT]

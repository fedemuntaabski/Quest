class_name NetworkTransport
extends RefCounted

## NetworkTransport (coop-12): opens/closes the MultiplayerPeer of a co-op session.
## Two implementations: SteamTransport (production, lobby id as join code) and
## EnetTransport (local tests and development without Steam, "ip:port" code).
## Nothing else in the game knows which one is active: NetSession only talks to
## this interface and to the MultiplayerAPI it was given.

## The host is listening; `code` is what a client types to join.
signal hosted(code: String)
## A client created its peer (the connection itself is MultiplayerAPI.connected_to_server).
signal joining(code: String)
signal failed(reason: String)
## Steam only: a peer passed auth. ENet peers are trusted on connection.
signal peer_trusted(peer_id: int)

var api: MultiplayerAPI


func _init(p_api: MultiplayerAPI) -> void:
	api = p_api


func get_kind() -> String:
	return "none"


func host(_max_players: int) -> Error:
	return ERR_UNAVAILABLE


func join(_code: String) -> Error:
	return ERR_UNAVAILABLE


func close() -> void:
	if api != null and api.multiplayer_peer != null:
		api.multiplayer_peer.close()
		api.multiplayer_peer = null


func get_join_code() -> String:
	return ""


## Name shown in the lobby for the local player.
func get_display_name() -> String:
	return OS.get_environment("USERNAME") if OS.has_environment("USERNAME") else "Jugador"


## A stable id for reconnection (Steam id, or a per-install token).
func get_player_token() -> String:
	return ""


## Whether a connected peer may join the session (Steam: authenticated).
func is_peer_trusted(_peer_id: int) -> bool:
	return true


func can_invite() -> bool:
	return false


func invite() -> void:
	pass

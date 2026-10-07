class_name SteamTransport
extends NetworkTransport

## SteamTransport (coop-12): SteamMultiplayerPeer through SteamLobbyManager
## (Friends Only lobby, join code = lobby id). Peers count as trusted only after
## SteamManager validated their auth ticket.

var _steam: SteamManager


func _init(p_api: MultiplayerAPI, steam_manager: SteamManager) -> void:
	super(p_api)
	_steam = steam_manager
	var lobby := _steam.lobby_manager
	lobby.lobby_ready.connect(_on_lobby_ready)
	lobby.lobby_failed.connect(func(reason: String) -> void: failed.emit(reason))
	_steam.client_authenticated.connect(func(peer_id: int, _sid: int) -> void: peer_trusted.emit(peer_id))


func get_kind() -> String:
	return "steam"


func host(max_players: int) -> Error:
	_steam.lobby_manager.create_lobby(SteamApi.LOBBY_TYPE_FRIENDS_ONLY, max_players)
	return OK


func join(code: String) -> Error:
	if not code.strip_edges().is_valid_int():
		failed.emit("bad_code")
		return ERR_INVALID_PARAMETER
	_steam.lobby_manager.join_lobby(int(code.strip_edges()))
	return OK


func close() -> void:
	_steam.lobby_manager.leave_lobby()
	super()


func get_join_code() -> String:
	var id := _steam.lobby_manager.current_lobby_id
	return str(id) if id != 0 else ""


func get_display_name() -> String:
	return SteamApi.steam().getPersonaName()


func get_player_token() -> String:
	return str(SteamApi.steam().getSteamID())


func is_peer_trusted(peer_id: int) -> bool:
	return peer_id == 1 or _steam.connected_clients.has(peer_id)


func can_invite() -> bool:
	return _steam.lobby_manager.current_lobby_id != 0


func invite() -> void:
	SteamApi.steam().activateGameOverlayInviteDialog(_steam.lobby_manager.current_lobby_id)


func _on_lobby_ready(lobby_id: int, is_host: bool) -> void:
	if is_host:
		hosted.emit(str(lobby_id))
	else:
		joining.emit(str(lobby_id))

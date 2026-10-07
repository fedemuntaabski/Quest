class_name SteamLobbyManager
extends Node

signal lobby_ready(lobby_id: int, is_host: bool)
signal lobby_failed(reason: String)
## coop-12: an overlay invite was accepted; NetSession joins through its transport.
signal invite_accepted(lobby_id: int)

var current_lobby_id: int = 0
var peer: MultiplayerPeer = null  # a SteamMultiplayerPeer (SteamApi.new_peer())


func _ready() -> void:
	SteamApi.steam().connect("lobby_created", _on_lobby_created)
	SteamApi.steam().connect("lobby_joined", _on_lobby_joined)
	SteamApi.steam().connect("join_requested", _on_join_requested)
	multiplayer.connected_to_server.connect(_on_connected_to_server)


func create_lobby(lobby_type: int = SteamApi.LOBBY_TYPE_FRIENDS_ONLY, max_members: int = 4) -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	QuestLogger.info(QuestLogger.Category.NETWORK, "create_lobby: steam_mgr=%s is_steam_available=%s" % [steam_mgr, (steam_mgr.is_steam_available() if steam_mgr else "n/a")])
	if steam_mgr == null or not steam_mgr.is_steam_available():
		QuestLogger.error(QuestLogger.Category.NETWORK, "create_lobby called but Steam is not available.")
		lobby_failed.emit("steam_unavailable")
		return
	QuestLogger.info(QuestLogger.Category.NETWORK, "create_lobby: calling Steam.createLobby(type=%d, max=%d)" % [lobby_type, max_members])
	SteamApi.steam().createLobby(lobby_type, max_members)


func join_lobby(lobby_id: int) -> void:
	if current_lobby_id != 0:
		leave_lobby()
	SteamApi.steam().joinLobby(lobby_id)


func leave_lobby() -> void:
	if current_lobby_id == 0:
		return
	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr != null:
		steam_mgr.clear_all_sessions()
	SteamApi.steam().leaveLobby(current_lobby_id)
	current_lobby_id = 0
	_close_peer()


## Closes the network peer (leave_lobby / failed host or client) so no socket stays open.
func _close_peer() -> void:
	if peer != null:
		peer.close()
	if multiplayer.multiplayer_peer == peer:
		multiplayer.multiplayer_peer = null
	peer = null


func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	if connect_result != 1:
		QuestLogger.error(QuestLogger.Category.NETWORK, "Lobby creation failed, result=%d" % connect_result)
		lobby_failed.emit("create_failed:%d" % connect_result)
		return

	current_lobby_id = lobby_id
	SteamApi.steam().setLobbyData(lobby_id, "name", "%s's Game" % SteamApi.steam().getPersonaName())
	SteamApi.steam().setLobbyData(lobby_id, "game_version", str(ProjectSettings.get_setting("application/config/version", "0.0")))

	peer = SteamApi.new_peer()
	var error: int = peer.call("create_host", 0) if peer != null else ERR_UNAVAILABLE
	if error != OK:
		QuestLogger.error(QuestLogger.Category.NETWORK, "create_host failed, error=%d" % error)
		leave_lobby()  # don't leave an open lobby nobody can join
		lobby_failed.emit("create_host_failed:%d" % error)
		return

	multiplayer.multiplayer_peer = peer
	QuestLogger.info(QuestLogger.Category.NETWORK, "Lobby created, lobby_id=%d" % lobby_id)
	lobby_ready.emit(lobby_id, true)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != SteamApi.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		QuestLogger.error(QuestLogger.Category.NETWORK, "Lobby join failed, response=%d" % response)
		lobby_failed.emit("join_failed:%d" % response)
		return

	current_lobby_id = lobby_id
	var host_steam_id: int = SteamApi.steam().getLobbyOwner(lobby_id)

	if host_steam_id == SteamApi.steam().getSteamID():
		# El host también recibe su propio lobby_joined (Steam lo trata como
		# miembro de su propio lobby). El peer ya quedó armado en _on_lobby_created.
		return

	peer = SteamApi.new_peer()
	var error: int = peer.call("create_client", host_steam_id, 0) if peer != null else ERR_UNAVAILABLE
	if error != OK:
		QuestLogger.error(QuestLogger.Category.NETWORK, "create_client failed, error=%d" % error)
		leave_lobby()
		lobby_failed.emit("create_client_failed:%d" % error)
		return

	multiplayer.multiplayer_peer = peer
	QuestLogger.info(QuestLogger.Category.NETWORK, "Lobby joined, lobby_id=%d host_steam_id=%d" % [lobby_id, host_steam_id])

	# The auth ticket is requested in _on_connected_to_server: before the connection
	# exists the host has no peer id yet (the host is always peer 1).
	lobby_ready.emit(lobby_id, false)


func _on_connected_to_server() -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr != null:
		steam_mgr.get_auth_ticket_for_peer(1)


func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	QuestLogger.info(QuestLogger.Category.NETWORK, "Join requested via overlay, lobby_id=%d" % lobby_id)
	# An overlay invite may arrive mid-run: only join from the menus (no gameplay loaded).
	if ManagerLocator.get_room_manager() != null:
		QuestLogger.warn(QuestLogger.Category.NETWORK, "Join request ignored: a run is in progress.")
		return
	invite_accepted.emit(lobby_id)

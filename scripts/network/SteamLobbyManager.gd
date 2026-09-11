class_name SteamLobbyManager
extends Node

signal lobby_ready(lobby_id: int, is_host: bool)
signal lobby_failed(reason: String)

var current_lobby_id: int = 0
var peer: SteamMultiplayerPeer = null


func _ready() -> void:
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_requested)


func create_lobby(lobby_type: int = Steam.LOBBY_TYPE_FRIENDS_ONLY, max_members: int = 4) -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr == null or not steam_mgr.is_steam_available():
		QuestLogger.error(QuestLogger.Category.NETWORK, "create_lobby called but Steam is not available.")
		lobby_failed.emit("steam_unavailable")
		return
	Steam.createLobby(lobby_type, max_members)


func join_lobby(lobby_id: int) -> void:
	if current_lobby_id != 0:
		leave_lobby()
	Steam.joinLobby(lobby_id)


func leave_lobby() -> void:
	if current_lobby_id == 0:
		return
	Steam.leaveLobby(current_lobby_id)
	current_lobby_id = 0
	multiplayer.multiplayer_peer = null
	peer = null


func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	if connect_result != 1:
		QuestLogger.error(QuestLogger.Category.NETWORK, "Lobby creation failed, result=%d" % connect_result)
		lobby_failed.emit("create_failed:%d" % connect_result)
		return

	current_lobby_id = lobby_id
	Steam.setLobbyData(lobby_id, "name", "%s's Game" % Steam.getPersonaName())
	Steam.setLobbyData(lobby_id, "game_version", str(ProjectSettings.get_setting("application/config/version", "0.0")))

	peer = SteamMultiplayerPeer.new()
	var error: int = peer.create_host(0)
	if error != OK:
		QuestLogger.error(QuestLogger.Category.NETWORK, "create_host failed, error=%d" % error)
		lobby_failed.emit("create_host_failed:%d" % error)
		return

	multiplayer.multiplayer_peer = peer
	QuestLogger.info(QuestLogger.Category.NETWORK, "Lobby created, lobby_id=%d" % lobby_id)
	lobby_ready.emit(lobby_id, true)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		QuestLogger.error(QuestLogger.Category.NETWORK, "Lobby join failed, response=%d" % response)
		lobby_failed.emit("join_failed:%d" % response)
		return

	current_lobby_id = lobby_id
	var host_steam_id: int = Steam.getLobbyOwner(lobby_id)

	peer = SteamMultiplayerPeer.new()
	var error: int = peer.create_client(host_steam_id, 0)
	if error != OK:
		QuestLogger.error(QuestLogger.Category.NETWORK, "create_client failed, error=%d" % error)
		lobby_failed.emit("create_client_failed:%d" % error)
		return

	multiplayer.multiplayer_peer = peer
	QuestLogger.info(QuestLogger.Category.NETWORK, "Lobby joined, lobby_id=%d host_steam_id=%d" % [lobby_id, host_steam_id])

	var host_peer_id: int = peer.get_peer_id_for_steam_id(host_steam_id)
	ManagerLocator.get_steam_manager().get_auth_ticket_for_peer(host_peer_id)

	lobby_ready.emit(lobby_id, false)


func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	QuestLogger.info(QuestLogger.Category.NETWORK, "Join requested via overlay, lobby_id=%d" % lobby_id)
	join_lobby(lobby_id)

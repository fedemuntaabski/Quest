extends Node

const APP_ID: int = 480
const AUTH_TIMEOUT_SECONDS: float = 15.0

signal client_authenticated(peer_id: int, steam_id: int)
signal client_rejected(peer_id: int, steam_id: int, reason: String)

var connected_clients: Dictionary[int, Dictionary] = {}
var pending_clients: Dictionary[int, Dictionary] = {}

signal avatar_loaded_ready(steam_id: int, texture: ImageTexture)

var avatar_cache: Dictionary[int, ImageTexture] = {}

var lobby_manager: SteamLobbyManager = null

var _steam_initialized: bool = false
var _local_auth_ticket: int = -1
var _local_auth_ticket_peer: int = -1


func _ready() -> void:
	var init_result: Dictionary = Steam.steamInitEx(false, APP_ID)
	_steam_initialized = init_result.get("status", 1) == 0

	if not _steam_initialized:
		QuestLogger.warn(QuestLogger.Category.NETWORK, "Steam not available: %s" % str(init_result))
		return

	QuestLogger.info(QuestLogger.Category.NETWORK, "Steam initialized. SteamID=%d" % Steam.getSteamID())

	Steam.get_auth_session_ticket_response.connect(_on_get_auth_session_ticket_response)
	Steam.validate_auth_ticket_response.connect(_on_validate_auth_ticket_response)
	Steam.avatar_loaded.connect(_on_loaded_avatar)

	lobby_manager = SteamLobbyManager.new()
	lobby_manager.name = "SteamLobbyManager"
	add_child(lobby_manager)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(_delta: float) -> void:
	if _steam_initialized:
		Steam.run_callbacks()


func is_steam_available() -> bool:
	return _steam_initialized


func get_steam_id_for_peer_id(peer_id: int) -> int:
	if lobby_manager == null or lobby_manager.peer == null:
		return 0
	return lobby_manager.peer.get_steam_id_for_peer_id(peer_id)


func get_user_avatar(steam_id: int = 0, size: int = Steam.AVATAR_MEDIUM) -> void:
	var target_id: int = steam_id if steam_id != 0 else Steam.getSteamID()
	if avatar_cache.has(target_id):
		avatar_loaded_ready.emit(target_id, avatar_cache[target_id])
		return
	Steam.getPlayerAvatar(size, target_id)


func get_auth_ticket_for_peer(peer_id: int) -> void:
	var ticket_info: Dictionary = Steam.getAuthSessionTicket()
	_local_auth_ticket = ticket_info.get("id", -1)
	_local_auth_ticket_peer = peer_id
	pending_clients[peer_id] = {"ticket_buffer": ticket_info.get("buffer", PackedByteArray()), "requested_at": Time.get_ticks_msec()}


func validate_auth_session(ticket_data: PackedByteArray, steam_id: int) -> void:
	var result: int = Steam.beginAuthSession(ticket_data, ticket_data.size(), steam_id)
	if result != Steam.AUTH_SESSION_RESPONSE_OK:
		QuestLogger.warn(QuestLogger.Category.NETWORK, "beginAuthSession failed for steam_id=%d, result=%d" % [steam_id, result])


@rpc("any_peer", "reliable")
func submit_auth_ticket(ticket_bytes: PackedByteArray) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var steam_id: int = get_steam_id_for_peer_id(peer_id)
	if steam_id == 0:
		QuestLogger.warn(QuestLogger.Category.NETWORK, "submit_auth_ticket: could not resolve steam_id for peer_id=%d" % peer_id)
		return
	pending_clients[peer_id] = {"steam_id": steam_id, "ticket": ticket_bytes, "requested_at": Time.get_ticks_msec()}
	validate_auth_session(ticket_bytes, steam_id)
	_start_auth_timeout(peer_id)


func _start_auth_timeout(peer_id: int) -> void:
	await get_tree().create_timer(AUTH_TIMEOUT_SECONDS).timeout
	if pending_clients.has(peer_id):
		QuestLogger.warn(QuestLogger.Category.NETWORK, "Auth timeout for peer_id=%d" % peer_id)
		_reject_client(peer_id, pending_clients[peer_id].get("steam_id", 0), "timeout")


func _on_get_auth_session_ticket_response(_auth_ticket: int, result: int) -> void:
	if result != Steam.AUTH_SESSION_RESPONSE_OK:
		QuestLogger.error(QuestLogger.Category.NETWORK, "Local auth ticket failed, result=%d" % result)
		return
	var entry: Dictionary = pending_clients.get(_local_auth_ticket_peer, {})
	var ticket_buffer: PackedByteArray = entry.get("ticket_buffer", PackedByteArray())
	QuestLogger.info(QuestLogger.Category.NETWORK, "Local auth ticket ready, sending to host peer_id=%d" % _local_auth_ticket_peer)
	submit_auth_ticket.rpc_id(_local_auth_ticket_peer, ticket_buffer)


func _on_validate_auth_ticket_response(steam_id: int, auth_session_response: int, _owner_steam_id: int) -> void:
	var peer_id: int = -1
	for candidate_peer_id: int in pending_clients.keys():
		if pending_clients[candidate_peer_id].get("steam_id", 0) == steam_id:
			peer_id = candidate_peer_id
			break
	if peer_id == -1:
		return

	if auth_session_response == Steam.AUTH_SESSION_RESPONSE_OK:
		connected_clients[peer_id] = {"steam_id": steam_id, "authenticated_at": Time.get_ticks_msec()}
		pending_clients.erase(peer_id)
		QuestLogger.info(QuestLogger.Category.NETWORK, "Client authenticated peer_id=%d steam_id=%d" % [peer_id, steam_id])
		client_authenticated.emit(peer_id, steam_id)
	else:
		_reject_client(peer_id, steam_id, "auth_session_response=%d" % auth_session_response)


func _reject_client(peer_id: int, steam_id: int, reason: String) -> void:
	QuestLogger.warn(QuestLogger.Category.NETWORK, "Rejecting client peer_id=%d steam_id=%d reason=%s" % [peer_id, steam_id, reason])
	if steam_id != 0:
		Steam.endAuthSession(steam_id)
	pending_clients.erase(peer_id)
	client_rejected.emit(peer_id, steam_id, reason)
	if multiplayer.multiplayer_peer != null and peer_id in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)


func _on_loaded_avatar(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	var img := Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	if img == null:
		QuestLogger.warn(QuestLogger.Category.NETWORK, "Failed to build avatar image for steam_id=%d" % user_id)
		return
	if avatar_size > 128:
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	avatar_cache[user_id] = tex
	avatar_loaded_ready.emit(user_id, tex)


func _on_peer_connected(peer_id: int) -> void:
	QuestLogger.info(QuestLogger.Category.NETWORK, "Peer connected: %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	QuestLogger.info(QuestLogger.Category.NETWORK, "Peer disconnected: %d" % peer_id)
	if peer_id == _local_auth_ticket_peer and _local_auth_ticket != -1:
		Steam.cancelAuthTicket(_local_auth_ticket)
		_local_auth_ticket = -1
		_local_auth_ticket_peer = -1
	if connected_clients.has(peer_id):
		Steam.endAuthSession(connected_clients[peer_id].get("steam_id", 0))
		connected_clients.erase(peer_id)
	pending_clients.erase(peer_id)

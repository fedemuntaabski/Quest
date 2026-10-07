class_name CoopSession
extends Node

## NetSession (autoload, coop-12; script class CoopSession so it is typed in
## `--script` tests too). Owns the co-op session: mode, the active
## NetworkTransport, the lobby roster and hero ownership. Gameplay asks Net.* only.
## The host is the authority for the roster: clients send requests, the host
## validates and broadcasts the whole roster (_rpc_sync_lobby).

enum Mode {OFFLINE, HOST, CLIENT}

signal session_started(mode: Mode)
## The client reached the host (connected_to_server).
signal connected
signal session_failed(reason: String)
## The session closed (leave(), host lost, connection failed).
signal session_ended(reason: String)
## Lobby roster / picks / ready flags changed (on every peer).
signal lobby_changed
## The host started the run (every peer, before Main.start_gameplay()).
signal run_started(seed: int)
## Host: a client has loaded the current floor (NetSync starts sending to it).
signal floor_ready(peer_id: int)
## A player joined / left / came back (HUD notices).
signal player_joined(peer_id: int, player_name: String)
signal player_left(peer_id: int, player_name: String)

const TOKEN_PATH := "user://net_token.txt"
const CONFIG_PATH := "res://resources/net/net_config.tres"
const PARTY_SIZE: int = preload("res://scripts/autoload/GameSession.gd").PARTY_SIZE

var mode: Mode = Mode.OFFLINE
var transport: NetworkTransport = null
## Overridable for in-process tests (two SceneMultiplayer branches).
var api: MultiplayerAPI = null
var config: NetConfig = load(CONFIG_PATH)
## peer_id -> {name, token, color, heroes: Array, ready: bool}. The host owns
## it; clients get copies through _rpc_sync_lobby.
var players: Dictionary = {}
## hero_id -> peer_id (fixed at start_run, changed by recruits/disconnects).
var hero_owner: Dictionary = {}
## Seed of the run being played (Main._begin_new_run reads it while online).
var run_seed: int = 0
var in_run := false
## Host: peer -> floor index it has loaded (NetSync only sends to these).
var ready_floor: Dictionary = {}
## Steam peers that registered before their auth ticket was validated.
var _pending_register: Dictionary = {}


func _ready() -> void:
	if api == null:
		api = multiplayer
	_bind_api()
	var steam := ManagerLocator.get_steam_manager()
	if steam != null and steam.lobby_manager != null:
		steam.lobby_manager.invite_accepted.connect(func(lobby_id: int) -> void: join(str(lobby_id)))


func _bind_api() -> void:
	if not api.connected_to_server.is_connected(_on_connected):
		api.connected_to_server.connect(_on_connected)
		api.connection_failed.connect(_on_connection_failed)
		api.server_disconnected.connect(_on_server_disconnected)
		api.peer_disconnected.connect(_on_peer_disconnected)


func is_online() -> bool:
	return mode != Mode.OFFLINE and api != null and api.multiplayer_peer != null


func is_authority() -> bool:
	return mode != Mode.CLIENT


func is_host() -> bool:
	return mode == Mode.HOST


func local_peer() -> int:
	return api.get_unique_id() if is_online() else 1


## Offline every hero is the local player's; online, only the ones it owns.
func owns(hero_id: String, peer_id: int = -1) -> bool:
	if not is_online():
		return true
	return hero_owner.get(hero_id, 1) == (local_peer() if peer_id < 0 else peer_id)


func player_color(peer_id: int) -> Color:
	return config.color_for(players.get(peer_id, {}).get("color", 0))


func player_name(peer_id: int) -> String:
	return players.get(peer_id, {}).get("name", "Jugador %d" % peer_id)


## Heroes each player picks in the lobby: 1 each, PARTY_SIZE (2) when alone.
func heroes_per_player() -> int:
	return maxi(1, ceili(float(PARTY_SIZE) / maxi(1, players.size())))


## Steam when available, ENet otherwise or with the `--net=enet` user arg.
func make_transport() -> NetworkTransport:
	var steam := ManagerLocator.get_steam_manager()
	var force_enet := OS.get_cmdline_user_args().has("--net=enet")
	if not force_enet and steam != null and steam.is_steam_available() and steam.lobby_manager != null:
		return SteamTransport.new(api, steam)
	return EnetTransport.new(api)


func host(max_players: int = 4, p_transport: NetworkTransport = null) -> Error:
	leave("rehost")
	transport = p_transport if p_transport != null else make_transport()
	_hook_transport()
	mode = Mode.HOST
	var err := transport.host(max_players)
	if err != OK:
		_reset("host_failed")
	return err


func join(code: String, p_transport: NetworkTransport = null) -> Error:
	leave("rejoin")
	transport = p_transport if p_transport != null else make_transport()
	_hook_transport()
	mode = Mode.CLIENT
	var err := transport.join(code)
	if err != OK:
		_reset("join_failed")
	return err


## Closes the peer/lobby and returns to offline. Safe to call when offline.
func leave(reason: String = "leave") -> void:
	if transport == null and mode == Mode.OFFLINE:
		return
	QuestLogger.info(QuestLogger.Category.NETWORK, "Session closed (%s)" % reason)
	if transport != null:
		transport.close()
	_reset(reason)


func get_kind() -> String:
	return transport.get_kind() if transport != null else "offline"


func get_join_code() -> String:
	return transport.get_join_code() if transport != null else ""


func _hook_transport() -> void:
	transport.hosted.connect(func(code: String) -> void:
		QuestLogger.info(QuestLogger.Category.NETWORK, "Hosting (%s) code=%s" % [transport.get_kind(), code])
		players = {1: _new_player(local_display_name(), _local_token(), 0)}
		lobby_changed.emit()
		session_started.emit(Mode.HOST))
	transport.failed.connect(func(reason: String) -> void:
		session_failed.emit(reason)
		leave("transport_failed:" + reason))
	transport.peer_trusted.connect(_on_peer_trusted)


func _reset(reason: String) -> void:
	var was := mode
	mode = Mode.OFFLINE
	transport = null
	players.clear()
	hero_owner.clear()
	_pending_register.clear()
	ready_floor.clear()
	in_run = false
	if was != Mode.OFFLINE:
		session_ended.emit(reason)


func _on_connected() -> void:
	if mode != Mode.CLIENT:
		return
	QuestLogger.info(QuestLogger.Category.NETWORK, "Connected to host as peer %d" % api.get_unique_id())
	connected.emit()
	_rpc_register.rpc_id(1, local_display_name(), _local_token())
	session_started.emit(Mode.CLIENT)


func _on_connection_failed() -> void:
	session_failed.emit("connection_failed")
	leave("connection_failed")


func _on_server_disconnected() -> void:
	leave("host_lost")


# ─── Identity ─────────────────────────────────────────────────

## Name shown to the others (`--net-name=X` overrides: two local instances).
func local_display_name() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net-name="):
			return a.substr(11)
	return transport.get_display_name() if transport != null else "Jugador"


## Reconnection key: `--net-token=X`, the Steam id, or a per-install token.
func _local_token() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net-token="):
			return a.substr(12)
	var t := transport.get_player_token() if transport != null else ""
	return t if t != "" else local_token()


## A per-install random id, used as the reconnection key outside Steam.
static func local_token() -> String:
	if FileAccess.file_exists(TOKEN_PATH):
		var f := FileAccess.open(TOKEN_PATH, FileAccess.READ)
		if f:
			return f.get_as_text().strip_edges()
	var token := "%x%x" % [randi(), Time.get_ticks_usec()]
	var w := FileAccess.open(TOKEN_PATH, FileAccess.WRITE)
	if w:
		w.store_string(token)
	return token


# ─── Lobby (host-authoritative) ───────────────────────────────

func _new_player(p_name: String, token: String, color: int) -> Dictionary:
	return {"name": p_name.left(24), "token": token, "color": color, "heroes": [], "ready": false}


func _free_color() -> int:
	var used := []
	for p in players.values():
		used.append(p.color)
	for i in config.max_players:
		if not used.has(i):
			return i
	return players.size()


@rpc("any_peer", "reliable")
func _rpc_register(p_name: String, token: String) -> void:
	if not is_host():
		return
	var peer := api.get_remote_sender_id()
	if transport != null and not transport.is_peer_trusted(peer):
		_pending_register[peer] = [p_name, token]  # Steam: wait for the auth ticket
		return
	_register(peer, p_name, token)


func _on_peer_trusted(peer: int) -> void:
	if _pending_register.has(peer):
		var r: Array = _pending_register[peer]
		_pending_register.erase(peer)
		_register(peer, r[0], r[1])


func _register(peer: int, p_name: String, token: String) -> void:
	if in_run:
		_rejoin(peer, p_name, token)
		return
	if players.size() >= config.max_players:
		api.multiplayer_peer.disconnect_peer(peer)
		return
	players[peer] = _new_player(p_name, token, _free_color())
	_trim_picks()
	QuestLogger.info(QuestLogger.Category.NETWORK, "Player %d joined the lobby: %s" % [peer, p_name])
	player_joined.emit(peer, p_name)
	_broadcast_lobby()


## A peer registering while a run is going on (reconnection, phase 6).
func _rejoin(peer: int, _p_name: String, _token: String) -> void:
	api.multiplayer_peer.disconnect_peer(peer)


func _on_peer_disconnected(peer: int) -> void:
	_pending_register.erase(peer)
	if not is_host() or not players.has(peer):
		return
	var p_name := player_name(peer)
	players.erase(peer)
	QuestLogger.info(QuestLogger.Category.NETWORK, "Player %d left: %s" % [peer, p_name])
	player_left.emit(peer, p_name)
	if in_run:
		_on_player_left_run(peer)
	else:
		_broadcast_lobby()


## A player dropped mid-run (phase 6).
func _on_player_left_run(_peer: int) -> void:
	_broadcast_lobby()


## Fewer heroes per player when someone joins: keep each one's first picks.
func _trim_picks() -> void:
	var quota := heroes_per_player()
	for p in players.values():
		if p.heroes.size() > quota:
			p.heroes = p.heroes.slice(0, quota)
			p.ready = false


func _broadcast_lobby() -> void:
	lobby_changed.emit()
	if is_online():
		_rpc_sync_lobby.rpc(players, hero_owner)


@rpc("authority", "reliable")
func _rpc_sync_lobby(p_players: Dictionary, p_owner: Dictionary) -> void:
	players = p_players
	hero_owner = p_owner
	lobby_changed.emit()


## Client: this floor is loaded, start sending me snapshots and state.
func report_floor_ready(floor_index: int) -> void:
	if is_online() and not is_host():
		_rpc_floor_ready.rpc_id(1, floor_index)


@rpc("any_peer", "reliable")
func _rpc_floor_ready(floor_index: int) -> void:
	if not is_host():
		return
	var peer := api.get_remote_sender_id()
	ready_floor[peer] = floor_index
	QuestLogger.info(QuestLogger.Category.NETWORK, "Peer %d loaded floor %d" % [peer, floor_index])
	floor_ready.emit(peer)


## Host: `hero_id` now belongs to `peer` (recruits, disconnects); everyone learns it.
func assign_hero(hero_id: String, peer: int) -> void:
	hero_owner[hero_id] = peer
	_broadcast_lobby()


## Who already picked `hero_id` (0 = free).
func hero_taken_by(hero_id: String) -> int:
	for peer in players:
		if players[peer].heroes.has(hero_id):
			return peer
	return 0


## Local player toggles a hero; the host validates.
func request_pick(hero_id: String) -> void:
	if is_host():
		_apply_pick(1, hero_id)
	else:
		_rpc_pick.rpc_id(1, hero_id)


func request_set_ready(value: bool) -> void:
	if is_host():
		_apply_ready(1, value)
	else:
		_rpc_ready.rpc_id(1, value)


@rpc("any_peer", "reliable")
func _rpc_pick(hero_id: String) -> void:
	if is_host():
		_apply_pick(api.get_remote_sender_id(), hero_id)


@rpc("any_peer", "reliable")
func _rpc_ready(value: bool) -> void:
	if is_host():
		_apply_ready(api.get_remote_sender_id(), value)


## Why a pick is refused ("" = valid). Picking an own hero again drops it.
func pick_block_reason(peer: int, hero_id: String) -> String:
	if in_run or not players.has(peer):
		return "La partida ya empezó"
	if not CharacterDatabase.has_id(hero_id):
		return "Héroe desconocido"
	var owner_peer := hero_taken_by(hero_id)
	if owner_peer != 0 and owner_peer != peer:
		return "Ya lo eligió %s" % player_name(owner_peer)
	if owner_peer == 0 and players[peer].heroes.size() >= heroes_per_player():
		return "Máximo %d héroe(s) por jugador" % heroes_per_player()
	return ""


func _apply_pick(peer: int, hero_id: String) -> bool:
	if pick_block_reason(peer, hero_id) != "":
		return false
	var heroes: Array = players[peer].heroes
	if heroes.has(hero_id):
		heroes.erase(hero_id)
	else:
		heroes.append(hero_id)
	players[peer].ready = false
	_broadcast_lobby()
	return true


func _apply_ready(peer: int, value: bool) -> bool:
	if not players.has(peer) or in_run:
		return false
	if value and players[peer].heroes.size() != heroes_per_player():
		return false
	players[peer].ready = value
	_broadcast_lobby()
	return true


func start_block_reason() -> String:
	if not is_host():
		return "Solo el anfitrión inicia"
	for peer in players:
		if not players[peer].ready:
			return "Falta que %s esté listo" % player_name(peer)
	return ""


## Host: roll the seed, fix hero owners and start the run on every peer.
func start_run() -> bool:
	if start_block_reason() != "":
		return false
	return restart_run()


## Host: a new run (lobby start, or Retry/New run from an end screen) with the lobby picks.
func restart_run() -> bool:
	if not is_host():
		return false
	var owners := {}
	for peer in players:
		for id in players[peer].heroes:
			owners[id] = peer
	var gs := ManagerLocator.get_game_session()
	var difficulty: String = gs.difficulty if gs else "normal"
	_rpc_start_run.rpc(randi(), owners, difficulty, 1)
	return true


## Host: everyone goes down to the next floor (same run).
func advance_floor() -> void:
	if is_host():
		ready_floor.clear()
		_rpc_advance_floor.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_advance_floor() -> void:
	var main := ManagerLocator.get_main_orchestrator()
	if main:
		main.advance_floor()


## Every peer (the host through call_local): same seed, same party, same owners.
@rpc("authority", "call_local", "reliable")
func _rpc_start_run(seed: int, owners: Dictionary, difficulty: String, floor_index: int) -> void:
	run_seed = seed
	hero_owner = owners
	in_run = true
	ready_floor.clear()
	var ids: Array[String] = []
	for peer in players:  # party order = join order
		for id in players[peer].heroes:
			if owners.has(id) and not ids.has(id):
				ids.append(id)
	for id in owners:
		if not ids.has(id):
			ids.append(id)
	var gs := ManagerLocator.get_game_session()
	if gs:
		gs.difficulty = difficulty
		gs.set_party(ids)
	QuestLogger.info(QuestLogger.Category.NETWORK, "start_run seed=%d floor=%d party=%s" % [seed, floor_index, ids])
	run_started.emit(seed)
	var main := ManagerLocator.get_main_orchestrator()
	if main:
		main.start_gameplay(floor_index)

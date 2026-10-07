extends Node2D
class_name PlayerActionController

## PlayerActionController: room-graph move + door-open coordinator. Clicking
## a revealed zone connected to the hero's current room glides the hero
## straight there; clicking an unrevealed zone or a closed door opens it
## (DoorTurnSystem tick + ResourceManager gain) and auto-walks the hero in.
## All input arrives as RoomZone/Door Area2D signals — no raw mouse polling.
## Session 12: `player` is the primary selected hero (Main2d → set_player, used
## for zone highlights). Session 14: an order acts on every selected hero, all
## walking at once; one order at a time (a hero still walking blocks new orders).
## coop-12: clicks become NetCommands ("move"/"open_door" with explicit hero ids);
## the host runs move_heroes()/open_door(). "Busy" is per hero, so two players'
## orders can run at the same time.

var player: Player
var tilemap: TileMapLayer
var room_manager: RoomManager
var door_turn_system: DoorTurnSystem

var _hovered_zone_id: String = ""
## Heroes walking right now (Player -> true): they take no new order until they arrive.
var _busy: Dictionary = {}
## Players with an order batch in progress (peer -> true): one order at a time per
## player, as in single player; different players' orders run side by side.
var _busy_peers: Dictionary = {}
## Compat (tests): true while any order batch is walking.
var _action_in_flight: bool:
	get:
		return not _busy_peers.is_empty()


func setup(p_player: Player, p_tilemap: TileMapLayer, p_room_manager: RoomManager, p_door_turn_system: DoorTurnSystem) -> void:
	player = p_player
	tilemap = p_tilemap
	room_manager = p_room_manager
	door_turn_system = p_door_turn_system

	if room_manager:
		room_manager.zone_clicked.connect(_on_zone_clicked)
		room_manager.zone_hovered.connect(_on_zone_hovered)
		room_manager.zone_unhovered.connect(_on_zone_unhovered)
		for door in room_manager.get_all_doors():
			if not door.door_clicked.is_connected(_on_door_clicked):
				door.door_clicked.connect(_on_door_clicked)

	refresh_zones()


## Selected hero changed (Main2d). The others wait where they are.
func set_player(p_player: Player) -> void:
	player = p_player
	refresh_zones()


func _can_act() -> bool:
	if player == null or tilemap == null or room_manager == null or is_peer_busy(Net.local_peer()):
		return false
	if _selected_heroes().is_empty():
		return false
	var gsm := ManagerLocator.get_game_state_manager()
	return gsm == null or gsm.is_active()


## Living selected heroes (SelectionManager order); just `player` without one.
func _selected_heroes() -> Array[Player]:
	var out: Array[Player] = []
	var selection := ManagerLocator.get_selection_manager()
	if selection == null:
		if player and player.can_accept_input():
			out.append(player)
		return out
	var heroes := ManagerLocator.get_heroes()
	for id: String in selection.selected_ids:
		for hero in heroes:
			if hero.stats.hero_id == id and hero.can_accept_input() and not _busy.has(hero):
				out.append(hero)
	return out


func _selected_ids() -> Array[String]:
	var ids: Array[String] = []
	for hero in _selected_heroes():
		ids.append(hero.stats.hero_id)
	return ids


func is_busy(hero: Player) -> bool:
	return _busy.has(hero)


func is_peer_busy(peer: int) -> bool:
	return _busy_peers.has(peer)


# ─────────────────────────────────────────────
# ZONE HIGHLIGHT
# ─────────────────────────────────────────────
func refresh_zones() -> void:
	if room_manager == null or player == null:
		return
	room_manager.set_current_zone(player.current_zone_id)
	if _hovered_zone_id != "" and _hovered_zone_id != player.current_zone_id:
		room_manager.set_zone_highlight(_hovered_zone_id, _classify_zone(_hovered_zone_id))


func _on_zone_hovered(zone_id: String) -> void:
	_hovered_zone_id = zone_id
	room_manager.set_zone_highlight(zone_id, _classify_zone(zone_id))


func _on_zone_unhovered(zone_id: String) -> void:
	if _hovered_zone_id == zone_id:
		_hovered_zone_id = ""
	var state := RoomZone.Highlight.CURRENT if (player and zone_id == player.current_zone_id) else RoomZone.Highlight.NONE
	room_manager.set_zone_highlight(zone_id, state)


func _classify_zone(zone_id: String) -> int:
	if player and zone_id == player.current_zone_id:
		return RoomZone.Highlight.CURRENT

	if not room_manager.find_zone_path(player.current_zone_id, zone_id).is_empty():
		return RoomZone.Highlight.REACHABLE
	return RoomZone.Highlight.BLOCKED


# ─────────────────────────────────────────────
# CLICK HANDLING
# ─────────────────────────────────────────────
func _on_zone_clicked(zone_id: String) -> void:
	if not _can_act():
		return

	# Unrevealed zones are hidden and non-pickable (fog of war); only doors open them.
	if room_manager.is_zone_revealed(zone_id):
		await ManagerLocator.get_net_commands().request("move", {"heroes": _selected_ids(), "zone": zone_id})


func _on_door_clicked(door: Door) -> void:
	if not _can_act():
		return
	await ManagerLocator.get_net_commands().request("open_door", {"door": door.door_id, "heroes": _selected_ids()})


## Every given hero walks to the zone from where it stands (heroes with no
## revealed path stay put; heroes already there don't move). Host/offline only.
func move_heroes(heroes: Array[Player], zone_id: String, peer: int = 1) -> void:
	var orders: Array[Dictionary] = []
	var blocked := false
	for hero in heroes:
		if _busy.has(hero):
			continue
		if hero.current_zone_id == zone_id:
			continue
		var order := _order_via_path(hero, zone_id)
		if order.is_empty():
			blocked = true
			QuestLogger.info(QuestLogger.Category.MAP, "Move rejected: '%s' is not connected to '%s' through revealed zones." % [zone_id, hero.current_zone_id])
		else:
			orders.append(order)
	if orders.is_empty() and blocked:
		room_manager.set_zone_highlight(zone_id, RoomZone.Highlight.BLOCKED)
	await _run_moves(orders, peer)


## {hero, waypoints, final_zone_id} along the revealed-zone path, or {} without one.
func _order_via_path(hero: Player, zone_id: String) -> Dictionary:
	var path := room_manager.find_zone_path(hero.current_zone_id, zone_id)
	if path.is_empty():
		return {}
	var waypoints: Array[Vector2] = []
	for step_id in path.slice(1):
		waypoints.append(room_manager.get_center(step_id))
	return {"hero": hero, "waypoints": waypoints, "final_zone_id": zone_id}


## Why `heroes` can't open `door` now ("" = they can). Same rules as before coop-12.
func door_block_reason(door: Door, heroes: Array[Player]) -> String:
	if door.is_opened() or door.is_secret:
		return "La puerta ya está abierta"
	var extraction := ManagerLocator.get_extraction_manager()
	if extraction and not extraction.can_open_doors():
		return "Durante la extracción no se abren puertas"
	# Tactical pause: heroes may be ordered to walk, but opening a door ticks the turn
	# and rolls the threat while everything else is frozen.
	if Engine.time_scale <= 0.0:
		return "En pausa: no se abren puertas"
	# A loop door sits at room_a's wall: hidden (and not openable) while room_a
	# is undiscovered, even if the hero stands in room_b.
	if not room_manager.is_zone_revealed(door.from_zone_id):
		return "Puerta sin descubrir"
	if _opener(door, heroes) == null:
		return "Ningún héroe elegido está junto a la puerta"
	if room_manager.is_group_revealed(door.target_room_id):
		return "La puerta ya está abierta"
	return ""


## The first given hero standing next to the door (it opens it: one tick).
func _opener(door: Door, heroes: Array[Player]) -> Player:
	for hero in heroes:
		if not _busy.has(hero) and door.get_target_room_for(hero.current_zone_id) != "":
			return hero
	return null


## Opens `door` with the first adjacent hero of `heroes`; all of them walk in.
## Host/offline only (NetCommands "open_door" validates with door_block_reason).
func open_door(door: Door, heroes: Array[Player], peer: int = 1) -> void:
	var reason := door_block_reason(door, heroes)
	if reason != "":
		QuestLogger.info(QuestLogger.Category.DOOR, "Door '%s' rejected: %s." % [door.door_id, reason])
		return
	var opener := _opener(door, heroes)
	var selected := heroes

	var opened := door_turn_system.open_room(door.target_room_id)
	if not opened:
		return
	door.disable_door()
	var audio := ManagerLocator.get_audio()
	if audio:
		audio.play_sfx(&"door")

	var group_zone_ids := room_manager.get_group_zone_ids(door.target_room_id)
	var final_zone_id := group_zone_ids[-1] if not group_zone_ids.is_empty() else opener.current_zone_id

	var orders: Array[Dictionary] = []
	var opener_waypoints := room_manager.get_group_centers(door.target_room_id)
	if not opener_waypoints.is_empty():
		orders.append({"hero": opener, "waypoints": opener_waypoints, "final_zone_id": final_zone_id})
	for hero in selected:
		if hero != opener and not _busy.has(hero) and hero.current_zone_id != final_zone_id:
			var order := _order_via_path(hero, final_zone_id)
			if not order.is_empty():
				orders.append(order)

	await _run_moves(orders, peer)
	room_manager.refresh_door_visibility()


## Walks every order at once and returns when the last hero arrived. Each hero
## is busy until it arrives; heroes outside the batch can take other orders.
func _run_moves(orders: Array[Dictionary], peer: int = 1) -> void:
	if orders.is_empty():
		return
	_busy_peers[peer] = true
	room_manager.clear_highlights()
	var batch := {"left": orders.size()}
	for order in orders:
		_busy[order["hero"]] = true
	for order in orders:
		_walk_and_count(order, batch)
	while batch.left > 0:
		await get_tree().process_frame
	_busy_peers.erase(peer)
	refresh_zones()


func _walk_and_count(order: Dictionary, batch: Dictionary) -> void:
	await _walk(order["hero"], order["waypoints"], order["final_zone_id"])
	_busy.erase(order["hero"])
	batch.left -= 1


## Speed factor of the Nexo carrier (FloorConfig.carrier_speed_mult, 0.85 = 15 % slower).
func _carrier_speed_mult() -> float:
	var floor_manager := ManagerLocator.get_floor_manager()
	return floor_manager.carrier_speed_mult() if floor_manager else FloorManager.DEFAULT_CONFIG.carrier_speed_mult


func _walk(hero: Player, waypoints: Array[Vector2], final_zone_id: String) -> void:
	var speed := MoveAction.DEFAULT_SPEED_PX * hero.move_speed_mult() * (_carrier_speed_mult() if hero.is_carrying_nexo else 1.0)
	var action := MoveAction.new(hero, waypoints, speed)
	if action.can_execute():
		await action.execute()
		hero.set_zone(final_zone_id, room_manager.get_center(final_zone_id), tilemap)
		if hero.is_carrying_nexo and room_manager.is_exit_room(final_zone_id):
			var extraction := ManagerLocator.get_extraction_manager()
			if extraction:
				extraction.declare_victory()

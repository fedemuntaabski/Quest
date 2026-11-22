extends Node2D
class_name PlayerActionController

## PlayerActionController: room-graph move + door-open coordinator. Clicking
## a revealed zone connected to the hero's current room glides the hero
## straight there; clicking an unrevealed zone or a closed door opens it
## (DoorTurnSystem tick + ResourceManager gain) and auto-walks the hero in.
## All input arrives as RoomZone/Door Area2D signals — no raw mouse polling.
## Session 12: `player` is the primary selected hero (Main2d → set_player, used
## for zone highlights). Session 14: an order acts on every selected hero, all
## walking at once. juego-35: a new order replaces a walk in progress (DotE/RTS): the
## hero goes back to the lane of the zone it stands in and on to the new target. Before,
## every click while a walk ran (or a second one in the tactical pause) was dropped
## without a word, which read as "right click does nothing, on any room".
## coop-12: clicks become NetCommands ("move"/"open_door" with explicit hero ids);
## the host runs move_heroes()/open_door().

var player: Player
var tilemap: TileMapLayer
var room_manager: RoomManager
var door_turn_system: DoorTurnSystem

var _hovered_zone_id: String = ""
## Heroes walking right now (Player -> walk token). A newer order for the hero takes a
## new token; the old walk sees it and stops where it is.
var _busy: Dictionary = {}
var _tweens: Dictionary = {}
var _next_token := 0
## Order batches walking per player (peer -> count).
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
	var reason := _act_block_reason()
	if reason != "":
		QuestLogger.info(QuestLogger.Category.MAP, "Click ignored: %s." % reason)
	return reason == ""


## Why a click can't become an order now ("" = it can). Logged, never silent.
func _act_block_reason() -> String:
	if player == null or tilemap == null or room_manager == null:
		return "floor not set up"
	if _selected_heroes().is_empty():
		return "no living hero selected"
	var gsm := ManagerLocator.get_game_state_manager()
	if gsm and not gsm.is_active():
		return "game state %s" % GameStateManager.State.keys()[gsm.current_state]
	return ""


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
			if hero.stats.hero_id == id and hero.can_accept_input():
				out.append(hero)
	return out


func _selected_ids() -> Array[String]:
	var ids: Array[String] = []
	for hero in _selected_heroes():
		ids.append(hero.stats.hero_id)
	return ids


func is_busy(hero: Player) -> bool:
	return _busy.has(hero)


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
	else:
		QuestLogger.info(QuestLogger.Category.MAP, "Click ignored: zone '%s' not discovered." % zone_id)


func _on_door_clicked(door: Door) -> void:
	if not _can_act():
		return
	await ManagerLocator.get_net_commands().request("open_door", {"door": door.door_id, "heroes": _selected_ids()})


## Every given hero walks to the zone from where it stands (heroes with no
## revealed path stay put; heroes standing there don't move, one walking through it
## stops at its centre). Host/offline only.
func move_heroes(heroes: Array[Player], zone_id: String, peer: int = 1) -> void:
	var orders: Array[Dictionary] = []
	var blocked := false
	for hero in heroes:
		if hero.current_zone_id == zone_id and not _busy.has(hero):
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


## {hero, waypoints, zones} along the revealed-zone path (one zone per waypoint), or {} without one.
## A hero caught mid-walk first goes back to its zone's centre (the lane), so the new
## leg never cuts through a wall.
func _order_via_path(hero: Player, zone_id: String) -> Dictionary:
	var path := room_manager.find_zone_path(hero.current_zone_id, zone_id)
	if path.is_empty():
		return {}
	var zones: Array[String] = []
	if hero.global_position.distance_to(room_manager.get_center(hero.current_zone_id)) > 1.0:
		zones.append(hero.current_zone_id)
	zones.append_array(path.slice(1))
	var waypoints: Array[Vector2] = []
	for step_id in zones:
		waypoints.append(room_manager.get_center(step_id))
	return {"hero": hero, "waypoints": waypoints, "zones": zones}


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


## The first given hero standing next to the door (it opens it: one tick; a walk it
## was on gives way to the opening).
func _opener(door: Door, heroes: Array[Player]) -> Player:
	for hero in heroes:
		if door.get_target_room_for(hero.current_zone_id) != "":
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
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"door_dust", door.global_position)

	var group_zone_ids := room_manager.get_group_zone_ids(door.target_room_id)
	var final_zone_id := group_zone_ids[-1] if not group_zone_ids.is_empty() else opener.current_zone_id

	var orders: Array[Dictionary] = []
	var opener_waypoints := room_manager.get_group_centers(door.target_room_id)
	var opener_zones := group_zone_ids.duplicate()
	var opener_lane := room_manager.get_center(opener.current_zone_id)
	if opener.global_position.distance_to(opener_lane) > 1.0:  # caught mid-walk: back on the lane first
		opener_waypoints.push_front(opener_lane)
		opener_zones.push_front(opener.current_zone_id)
	if not opener_waypoints.is_empty():
		orders.append({"hero": opener, "waypoints": opener_waypoints, "zones": opener_zones})
	for hero in selected:
		if hero != opener and hero.current_zone_id != final_zone_id:
			var order := _order_via_path(hero, final_zone_id)
			if not order.is_empty():
				orders.append(order)

	await _run_moves(orders, peer)
	room_manager.refresh_door_visibility()


## Walks every order at once and returns when the last hero arrived (or took a newer
## order). A hero already walking drops that walk where it is: one tween per hero.
func _run_moves(orders: Array[Dictionary], peer: int = 1) -> void:
	if orders.is_empty():
		return
	_busy_peers[peer] = int(_busy_peers.get(peer, 0)) + 1
	room_manager.clear_highlights()
	var batch := {"left": orders.size()}
	for order in orders:
		var hero: Player = order["hero"]
		var old: Tween = _tweens.get(hero)
		if old and old.is_valid():
			old.kill()
		_next_token += 1
		_busy[hero] = _next_token
		order["token"] = _next_token
	for order in orders:
		_walk_and_count(order, batch)
	while batch.left > 0:
		await get_tree().process_frame
	_busy_peers[peer] -= 1
	if _busy_peers[peer] <= 0:
		_busy_peers.erase(peer)
	refresh_zones()


func _walk_and_count(order: Dictionary, batch: Dictionary) -> void:
	var hero: Player = order["hero"]
	await _walk(hero, order["waypoints"], order["zones"], order["token"])
	if _busy.get(hero) == order["token"]:
		_busy.erase(hero)
		_tweens.erase(hero)
	batch.left -= 1


## Speed factor of the Relic carrier (FloorConfig.carrier_speed_mult, 0.85 = 15 % slower).
func _carrier_speed_mult() -> float:
	var floor_manager := ManagerLocator.get_floor_manager()
	return floor_manager.carrier_speed_mult() if floor_manager else FloorManager.DEFAULT_CONFIG.carrier_speed_mult


## Glides along `waypoints` (one per entry of `zones`). The hero is in each zone from
## the moment it crosses in (traps, chests, enemies, a Relic drop see the real zone);
## falling stops it where it stands, and its order ends there; so does a newer order
## (`token` no longer the hero's), which already killed this tween.
func _walk(hero: Player, waypoints: Array[Vector2], zones: Array[String], token: int = 0) -> void:
	var speed := MoveAction.DEFAULT_SPEED_PX * hero.move_speed_mult() * (_carrier_speed_mult() if hero.is_carrying_relic else 1.0)
	var action := MoveAction.new(hero, waypoints, speed)
	if not action.can_execute():
		return
	var tween := action.start()
	_tweens[hero] = tween
	var next := 0
	while tween.is_valid():
		await get_tree().process_frame
		if _busy.get(hero) != token:
			return
		if not hero.stats.is_alive():
			tween.kill()
			return
		while next < zones.size() and room_manager.zone_has_point(zones[next], hero.global_position):
			hero.enter_zone(zones[next])
			next += 1
	if _busy.get(hero) != token:
		return
	for zone_id in zones.slice(next):  # a long frame may jump a zone: nothing is skipped
		hero.enter_zone(zone_id)
	if not hero.stats.is_alive():  # the last zone's trap
		return
	var final_zone_id: String = zones[-1]
	hero.set_zone(final_zone_id, room_manager.get_center(final_zone_id), tilemap)
	if hero.is_carrying_relic and room_manager.is_exit_room(final_zone_id):
		var extraction := ManagerLocator.get_extraction_manager()
		if extraction:
			extraction.declare_victory()

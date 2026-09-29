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

var player: Player
var tilemap: TileMapLayer
var room_manager: RoomManager
var door_turn_system: DoorTurnSystem

signal _batch_done

var _action_in_flight: bool = false
var _pending_walks: int = 0
var _hovered_zone_id: String = ""


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
	if player == null or tilemap == null or room_manager == null or _action_in_flight:
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
			if hero.stats.hero_id == id and hero.can_accept_input():
				out.append(hero)
	return out


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
		await _move_to_zone(zone_id)


func _on_door_clicked(door: Door) -> void:
	if not _can_act():
		return
	await _open_group(door)


## Every selected hero walks to the zone from where it stands (heroes with no
## revealed path stay put; heroes already there don't move).
func _move_to_zone(zone_id: String) -> void:
	var orders: Array[Dictionary] = []
	var blocked := false
	for hero in _selected_heroes():
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
	await _run_moves(orders)


## {hero, waypoints, final_zone_id} along the revealed-zone path, or {} without one.
func _order_via_path(hero: Player, zone_id: String) -> Dictionary:
	var path := room_manager.find_zone_path(hero.current_zone_id, zone_id)
	if path.is_empty():
		return {}
	var waypoints: Array[Vector2] = []
	for step_id in path.slice(1):
		waypoints.append(room_manager.get_center(step_id))
	return {"hero": hero, "waypoints": waypoints, "final_zone_id": zone_id}


func _open_group(door: Door) -> void:
	if door.is_opened():
		return
	var extraction := ManagerLocator.get_extraction_manager()
	if extraction and not extraction.can_open_doors():
		QuestLogger.info(QuestLogger.Category.DOOR, "Door '%s' rejected: extraction phase active." % door.door_id)
		return
	# A loop door sits at room_a's wall: hidden (and not openable) while room_a
	# is undiscovered, even if the hero stands in room_b.
	if not room_manager.is_zone_revealed(door.from_zone_id):
		return
	# The first selected hero standing next to the door opens it (one tick).
	var opener: Player = null
	var selected := _selected_heroes()
	for hero in selected:
		if door.get_target_room_for(hero.current_zone_id) != "":
			opener = hero
			break
	if opener == null:
		QuestLogger.info(QuestLogger.Category.DOOR, "Door '%s' rejected: no selected hero is adjacent (%s / %s)." % [door.door_id, door.room_a_id, door.room_b_id])
		return
	if room_manager.is_group_revealed(door.target_room_id):
		return

	var opened := door_turn_system.open_room(door.target_room_id)
	if not opened:
		return
	door.disable_door()

	var group_zone_ids := room_manager.get_group_zone_ids(door.target_room_id)
	var final_zone_id := group_zone_ids[-1] if not group_zone_ids.is_empty() else opener.current_zone_id

	var orders: Array[Dictionary] = []
	var opener_waypoints := room_manager.get_group_centers(door.target_room_id)
	if not opener_waypoints.is_empty():
		orders.append({"hero": opener, "waypoints": opener_waypoints, "final_zone_id": final_zone_id})
	for hero in selected:
		if hero != opener and hero.current_zone_id != final_zone_id:
			var order := _order_via_path(hero, final_zone_id)
			if not order.is_empty():
				orders.append(order)

	await _run_moves(orders)
	room_manager.refresh_door_visibility()


## Walks every order at once and returns when the last hero arrived. One batch
## at a time (`_action_in_flight`); heroes outside the batch wait where they are.
func _run_moves(orders: Array[Dictionary]) -> void:
	if orders.is_empty():
		return
	_action_in_flight = true
	room_manager.clear_highlights()
	_pending_walks = orders.size()
	for order in orders:
		_walk(order["hero"], order["waypoints"], order["final_zone_id"])
	if _pending_walks > 0:
		await _batch_done
	_action_in_flight = false
	refresh_zones()


func _walk(hero: Player, waypoints: Array[Vector2], final_zone_id: String) -> void:
	var speed := MoveAction.DEFAULT_SPEED_PX * (0.75 if hero.is_carrying_nexo else 1.0)
	var action := MoveAction.new(hero, waypoints, speed)
	if action.can_execute():
		await action.execute()
		hero.set_zone(final_zone_id, room_manager.get_center(final_zone_id), tilemap)
		if hero.is_carrying_nexo and room_manager.is_exit_room(final_zone_id):
			var extraction := ManagerLocator.get_extraction_manager()
			if extraction:
				extraction.declare_victory()
	_pending_walks -= 1
	if _pending_walks == 0:
		_batch_done.emit()

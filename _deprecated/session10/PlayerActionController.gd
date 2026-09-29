extends Node2D
class_name PlayerActionController

## PlayerActionController: room-graph move + door-open coordinator. Clicking
## a revealed zone connected to the hero's current room glides the hero
## straight there; clicking an unrevealed zone or a closed door opens it
## (DoorTurnSystem tick + ResourceManager gain) and auto-walks the hero in.
## All input arrives as RoomZone/Door Area2D signals — no raw mouse polling.

var player: Player
var tilemap: TileMapLayer
var room_manager: RoomManager
var door_turn_system: DoorTurnSystem

var _action_in_flight: bool = false
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


func _can_act() -> bool:
	if player == null or tilemap == null or room_manager == null or _action_in_flight:
		return false
	if not player.can_accept_input():
		return false
	var gsm := ManagerLocator.get_game_state_manager()
	return gsm == null or gsm.is_active()


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
	if zone_id == player.current_zone_id:
		return

	# Unrevealed zones are hidden and non-pickable (fog of war); only doors open them.
	if room_manager.is_zone_revealed(zone_id):
		await _move_to_zone(zone_id)


func _on_door_clicked(door: Door) -> void:
	if not _can_act():
		return
	await _open_group(door)


func _move_to_zone(zone_id: String) -> void:
	var path := room_manager.find_zone_path(player.current_zone_id, zone_id)
	if path.is_empty():
		room_manager.set_zone_highlight(zone_id, RoomZone.Highlight.BLOCKED)
		QuestLogger.info(QuestLogger.Category.MAP, "Move rejected: '%s' is not connected to '%s' through revealed zones." % [zone_id, player.current_zone_id])
		return

	var waypoints: Array[Vector2] = []
	for step_id in path.slice(1):
		waypoints.append(room_manager.get_center(step_id))
	await _run_move(waypoints, zone_id)


func _open_group(door: Door) -> void:
	if door.is_opened():
		return
	var extraction := ManagerLocator.get_extraction_manager()
	if extraction and not extraction.can_open_doors():
		QuestLogger.info(QuestLogger.Category.DOOR, "Door '%s' rejected: extraction phase active." % door.door_id)
		return
	if door.get_target_room_for(player.current_zone_id) == "":
		QuestLogger.info(QuestLogger.Category.DOOR, "Door '%s' rejected: hero in '%s' is not adjacent (%s / %s)." % [door.door_id, player.current_zone_id, door.room_a_id, door.room_b_id])
		return
	if room_manager.is_group_revealed(door.target_room_id):
		return

	var opened := door_turn_system.open_room(door.target_room_id)
	if not opened:
		return
	door.disable_door()

	var waypoints := room_manager.get_group_centers(door.target_room_id)
	var group_zone_ids := room_manager.get_group_zone_ids(door.target_room_id)
	var final_zone_id := group_zone_ids[-1] if not group_zone_ids.is_empty() else player.current_zone_id

	await _run_move(waypoints, final_zone_id)
	room_manager.refresh_door_visibility()


func _run_move(waypoints: Array[Vector2], final_zone_id: String) -> void:
	if waypoints.is_empty():
		return

	var speed := MoveAction.DEFAULT_SPEED_PX * (0.75 if player.is_carrying_nexo else 1.0)
	var action := MoveAction.new(player, waypoints, speed)
	if not action.can_execute():
		return

	_action_in_flight = true
	room_manager.clear_highlights()

	await action.execute()

	player.set_zone(final_zone_id, room_manager.get_center(final_zone_id), tilemap)
	room_manager.set_current_zone(final_zone_id)
	_action_in_flight = false
	refresh_zones()

	if player.is_carrying_nexo and room_manager.is_exit_room(final_zone_id):
		var extraction := ManagerLocator.get_extraction_manager()
		if extraction:
			extraction.declare_victory()

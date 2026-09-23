extends Node2D
class_name RoomManager

## RoomManager: owns the room/corridor graph — geometry (rects/cells/world
## centers), adjacency, and the clickable RoomZone nodes. Reveal/visited state
## stays owned by DoorTurnSystem (keyed by "group_id", i.e. its room_id); this
## class only ever reads that via `is_zone_revealed()`, never duplicates it.

signal zone_clicked(zone_id: String)
signal zone_hovered(zone_id: String)
signal zone_unhovered(zone_id: String)
signal room_powered(zone_id: String)
signal slot_clicked(zone_id: String, slot: BuildingSlot)

const ZONE_SCENE := preload("res://scenes/RoomZone.tscn")
const DEFAULT_TILE_SIZE := Vector2(64, 64)

var tilemap: TileMapLayer
var door_turn_system: DoorTurnSystem

var zones: Dictionary = {}          # zone_id -> {id, kind, rect, cells, center_position, neighbors, group_id, node}
var groups: Dictionary = {}         # group_id -> Array[String] ordered zone ids (corridor-first)
var _doors_by_group: Dictionary = {}  # group_id -> Door
var rooms_dict: Dictionary = {}     # room_id -> RoomZone (room-kind zones only; graph nodes)
var _current_zone_id: String = ""


func _ready() -> void:
	add_to_group("room_manager")


func setup(p_tilemap: TileMapLayer, p_door_turn_system: DoorTurnSystem) -> void:
	tilemap = p_tilemap
	door_turn_system = p_door_turn_system


func _tile_size() -> Vector2:
	if tilemap and tilemap.tile_set:
		return Vector2(tilemap.tile_set.tile_size)
	return DEFAULT_TILE_SIZE


func build_from_layout(layout: Dictionary) -> void:
	zones.clear()
	groups.clear()
	rooms_dict.clear()

	var tile_size := _tile_size()
	var zones_def: Dictionary = layout.get("zones", {})

	for zone_id in zones_def.keys():
		var def: Dictionary = zones_def[zone_id]
		var rect := Rect2i(def["pos"], def["size"])
		var center := (Vector2(rect.position) + Vector2(rect.size) / 2.0) * tile_size
		zones[zone_id] = {
			"id": zone_id,
			"kind": def.get("kind", "room"),
			"rect": rect,
			"cells": _rect_cells(rect),
			"center_position": center,
			"neighbors": [],
			"group_id": def.get("group", zone_id),
			"is_exit_room": def.get("is_exit_room", false),
			"node": null,
		}

	for pair in layout.get("connections", []):
		var a: String = pair[0]
		var b: String = pair[1]
		if zones.has(a) and zones.has(b):
			(zones[a]["neighbors"] as Array).append(b)
			(zones[b]["neighbors"] as Array).append(a)

	var groups_def: Dictionary = layout.get("groups", {})
	for group_id in groups_def.keys():
		var group_zone_ids: Array[String] = []
		group_zone_ids.assign(groups_def[group_id].get("zones", []))
		groups[group_id] = group_zone_ids

	for zone_id in zones.keys():
		_spawn_zone_node(zone_id)

	QuestLogger.info(QuestLogger.Category.MAP, "RoomManager: built %d zones, %d groups." % [zones.size(), groups.size()])


func _spawn_zone_node(zone_id: String) -> void:
	var record: Dictionary = zones[zone_id]
	var rect: Rect2i = record["rect"]

	var zone := ZONE_SCENE.instantiate() as RoomZone
	zone.name = zone_id
	zone.position = record["center_position"]
	add_child(zone)
	zone.configure(zone_id, Vector2(rect.size) * _tile_size(), record["kind"])
	zone.center_position = record["center_position"]
	zone.clicked.connect(func(z: RoomZone): zone_clicked.emit(z.zone_id))
	zone.hovered.connect(func(z: RoomZone): zone_hovered.emit(z.zone_id))
	zone.unhovered.connect(func(z: RoomZone): zone_unhovered.emit(z.zone_id))
	zone.powered_up.connect(func(zid: String): room_powered.emit(zid))
	zone.slot_clicked.connect(func(zid: String, slot: BuildingSlot): slot_clicked.emit(zid, slot))

	record["node"] = zone
	if record["kind"] == "room":
		register_room(zone)


## Registers a room node in the graph. Only room-kind zones are graph nodes.
func register_room(room: RoomZone) -> void:
	if room == null or room.room_id == "":
		return
	rooms_dict[room.room_id] = room


func register_door(door: Door) -> void:
	if door == null:
		return
	door.global_position = GridUtils.cell_to_world(tilemap, door.cell)
	_doors_by_group[door.target_room_id] = door
	_link_door_to_rooms(door)


## Graph edge registration: resolves the door's two endpoints (deriving them
## from from_zone_id / target group's room zone when unset) and injects the
## door into both rooms' `connected_doors`.
func _link_door_to_rooms(door: Door) -> void:
	if door.room_a_id == "":
		door.room_a_id = door.from_zone_id
	if door.room_b_id == "":
		door.room_b_id = _first_room_zone_in_group(door.target_room_id)

	var room_a: RoomZone = get_room(door.room_a_id)
	var room_b: RoomZone = get_room(door.room_b_id)
	if room_a == null or room_b == null:
		QuestLogger.warn(QuestLogger.Category.MAP, "RoomManager: door '%s' not linked, unknown room(s) '%s' / '%s'." % [door.door_id, door.room_a_id, door.room_b_id])
		return

	for room in [room_a, room_b]:
		if not room.connected_doors.has(door):
			room.connected_doors.append(door)


func _first_room_zone_in_group(group_id: String) -> String:
	for zone_id in (groups.get(group_id, []) as Array):
		if zones.get(zone_id, {}).get("kind", "") == "room":
			return zone_id
	return ""


# ─────────────────────────────────────────────
# QUERIES
# ─────────────────────────────────────────────
func has_zone(zone_id: String) -> bool:
	return zones.has(zone_id)


func get_zone(zone_id: String) -> Dictionary:
	return zones.get(zone_id, {})


func get_center(zone_id: String) -> Vector2:
	return zones.get(zone_id, {}).get("center_position", Vector2.ZERO)


func get_cells(zone_id: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(zones.get(zone_id, {}).get("cells", []))
	return cells


func get_group_id(zone_id: String) -> String:
	return zones.get(zone_id, {}).get("group_id", "")


func get_group_cells(group_id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for zone_id in (groups.get(group_id, []) as Array):
		result.append_array(get_cells(zone_id))
	return result


func get_group_zone_ids(group_id: String) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(groups.get(group_id, []))
	return ids


func get_group_centers(group_id: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for zone_id in (groups.get(group_id, []) as Array):
		result.append(get_center(zone_id))
	return result


func get_door_for_group(group_id: String) -> Door:
	return _doors_by_group.get(group_id) as Door


func get_all_doors() -> Array[Door]:
	var doors: Array[Door] = []
	for door in _doors_by_group.values():
		doors.append(door)
	return doors


func get_zone_at_cell(cell: Vector2i) -> String:
	for zone_id in zones.keys():
		if (zones[zone_id]["cells"] as Array).has(cell):
			return zone_id
	return ""


func is_zone_revealed(zone_id: String) -> bool:
	if door_turn_system == null:
		return false
	return door_turn_system.is_room_visited(get_group_id(zone_id))


func is_zone_powered(zone_id: String) -> bool:
	var node: RoomZone = zones.get(zone_id, {}).get("node")
	return node.is_powered if node else false


func set_zone_powered(zone_id: String, v: bool) -> void:
	var node: RoomZone = zones.get(zone_id, {}).get("node")
	if node:
		node.set_powered(v)


func is_exit_room(zone_id: String) -> bool:
	return zones.get(zone_id, {}).get("is_exit_room", false)


func get_modules_in_group(group_id: String) -> Array[Module]:
	var modules: Array[Module] = []
	for zone_id in (groups.get(group_id, []) as Array):
		var node: RoomZone = zones.get(zone_id, {}).get("node")
		if node:
			modules.append_array(node.get_modules())
	return modules


func get_all_modules() -> Array[Module]:
	var modules: Array[Module] = []
	for zone_id in zones.keys():
		var node: RoomZone = zones[zone_id]["node"]
		if node:
			modules.append_array(node.get_modules())
	return modules


## Group ids whose room-kind zone is revealed but not yet powered — the
## dark-room pool for enemy spawns (extraction ticks and door-open waves).
func get_unpowered_revealed_room_group_ids() -> Array[String]:
	var result: Array[String] = []
	for group_id in groups.keys():
		for zone_id in (groups[group_id] as Array):
			if zones.get(zone_id, {}).get("kind", "") != "room":
				continue
			if is_zone_revealed(zone_id) and not is_zone_powered(zone_id):
				result.append(group_id)
			break
	return result


func get_room(room_id: String) -> RoomZone:
	return rooms_dict.get(room_id) as RoomZone


## Visited rooms without power — vulnerable zones for enemy spawn risk.
func get_dark_rooms() -> Array[RoomZone]:
	var dark_rooms: Array[RoomZone] = []
	for room: RoomZone in rooms_dict.values():
		if room.is_visited and not room.is_powered:
			dark_rooms.append(room)
	return dark_rooms


## Visited rooms with power — safe, buildable zones.
func get_powered_rooms() -> Array[RoomZone]:
	var powered_rooms: Array[RoomZone] = []
	for room: RoomZone in rooms_dict.values():
		if room.is_visited and room.is_powered:
			powered_rooms.append(room)
	return powered_rooms


## True if any door of room A has room B as its counterpart (open or not).
func are_rooms_connected(room_a_id: String, room_b_id: String) -> bool:
	return _shared_door(room_a_id, room_b_id) != null


## Like are_rooms_connected, but only when the shared door is open.
func is_path_open(room_a_id: String, room_b_id: String) -> bool:
	var door := _shared_door(room_a_id, room_b_id)
	return door != null and door.is_open


## IDs of all rooms directly linked to `room_id`, regardless of door state.
func get_adjacent_rooms(room_id: String) -> Array[String]:
	var result: Array[String] = []
	var room := get_room(room_id)
	if room == null:
		return result
	for door in room.connected_doors:
		var other := _door_counterpart(door, room_id)
		if other != "" and not result.has(other):
			result.append(other)
	return result


func _shared_door(room_a_id: String, room_b_id: String) -> Door:
	var room := get_room(room_a_id)
	if room == null:
		return null
	for door in room.connected_doors:
		if _door_counterpart(door, room_a_id) == room_b_id:
			return door
	return null


func _door_counterpart(door: Door, room_id: String) -> String:
	if door.room_a_id == room_id:
		return door.room_b_id
	if door.room_b_id == room_id:
		return door.room_a_id
	return ""


func are_connected(a_id: String, b_id: String) -> bool:
	if not zones.has(a_id):
		return false
	return (zones[a_id]["neighbors"] as Array).has(b_id)


## BFS over `neighbors`, traversing only revealed zones. Returns the full
## path [from_id, ..., to_id], or [] when unreachable / ids unknown.
func find_zone_path(from_id: String, to_id: String) -> Array[String]:
	var result: Array[String] = []
	if not (zones.has(from_id) and zones.has(to_id)):
		return result
	if from_id == to_id:
		result.append(from_id)
		return result

	var frontier: Array[String] = [from_id]
	var came_from: Dictionary = {from_id: ""}

	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		if current == to_id:
			break
		for neighbor in (zones[current]["neighbors"] as Array):
			if came_from.has(neighbor) or not is_zone_revealed(neighbor):
				continue
			came_from[neighbor] = current
			frontier.append(neighbor)

	if not came_from.has(to_id):
		return result

	var step: String = to_id
	while step != "":
		result.push_front(step)
		step = came_from[step]
	return result


# ─────────────────────────────────────────────
# PRESENTATION
# ─────────────────────────────────────────────
func set_current_zone(zone_id: String) -> void:
	if _current_zone_id != "" and zones.has(_current_zone_id):
		var prev: RoomZone = zones[_current_zone_id]["node"]
		if prev:
			prev.set_highlight(RoomZone.Highlight.NONE)
	_current_zone_id = zone_id
	var node: RoomZone = zones.get(zone_id, {}).get("node")
	if node:
		node.set_highlight(RoomZone.Highlight.CURRENT)


func set_zone_highlight(zone_id: String, state: int) -> void:
	var node: RoomZone = zones.get(zone_id, {}).get("node")
	if node:
		node.set_highlight(state)


func clear_highlights(except_zone_id: String = "") -> void:
	for zone_id in zones.keys():
		if zone_id == except_zone_id:
			continue
		var node: RoomZone = zones[zone_id]["node"]
		if node == null:
			continue
		node.set_highlight(RoomZone.Highlight.CURRENT if zone_id == _current_zone_id else RoomZone.Highlight.NONE)


## Single reveal path: shows the zone node, marks it visited and paints its
## floor tiles. Zones stay hidden/inert until this runs.
func reveal_room(room_id: String) -> void:
	var node: RoomZone = zones.get(room_id, {}).get("node")
	if node == null:
		return
	node.is_visited = true
	node.set_revealed(true)
	if tilemap is FloorGenerator:
		(tilemap as FloorGenerator).fill_cells(get_cells(room_id))


func on_group_revealed(group_id: String) -> void:
	for zone_id in (groups.get(group_id, []) as Array):
		reveal_room(zone_id)
	refresh_door_visibility()


func refresh_door_visibility() -> void:
	for group_id in _doors_by_group.keys():
		var door: Door = _doors_by_group[group_id]
		var from_revealed := is_zone_revealed(door.from_zone_id) if door.from_zone_id != "" else true
		door.visible = from_revealed and not door.is_opened()


# ─────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────
func _rect_cells(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			cells.append(Vector2i(x, y))
	return cells

extends Resource
class_name MapLayout

## MapLayout: data-only floor map — rooms + corridor entities. Built by
## MapGenerator or authored as .tres (resources/maps/fallback_layout.tres);
## RoomManager.build_from_map() turns it into zones/groups/RoomZone nodes.
## Invariants (checked by validate()): one start, >=1 exit, every non-start
## room entered by exactly one non-loop corridor (its reveal group), loops
## join two distinct known rooms not already joined, unique ids, no
## overlapping cells, every room reachable from the start through non-loop
## corridors alone (loops never reveal rooms, so they can't be the only way in).

@export var map_seed: int = 0
@export var rooms: Array[RoomData] = []
@export var corridors: Array[CorridorData] = []


func get_room(room_id: String) -> RoomData:
	for room in rooms:
		if room.id == room_id:
			return room
	return null


func get_start_room_id() -> String:
	for room in rooms:
		if room.is_start:
			return room.id
	return ""


## The corridor that leads into `room_id` (null for the start room). Loops
## are never entry corridors.
func get_entry_corridor(room_id: String) -> CorridorData:
	for corridor in corridors:
		if corridor.room_b == room_id and not corridor.is_loop:
			return corridor
	return null


## Returns every broken invariant; empty = valid.
func validate() -> Array[String]:
	var problems: Array[String] = []
	var ids: Dictionary = {}
	var starts := 0
	var exits := 0
	for room in rooms:
		if ids.has(room.id):
			problems.append("duplicate room id '%s'" % room.id)
		ids[room.id] = true
		starts += int(room.is_start)
		exits += int(room.is_exit)
	if starts != 1:
		problems.append("expected 1 start room, found %d" % starts)
	if exits < 1:
		problems.append("no exit room")

	var entries: Dictionary = {}
	var pairs: Dictionary = {}
	var corridor_ids: Dictionary = {}
	for corridor in corridors:
		# Corridor ids are zone ids, and a loop's id is also its reveal group id.
		if ids.has(corridor.id) or corridor_ids.has(corridor.id):
			problems.append("duplicate id '%s' (corridor)" % corridor.id)
		corridor_ids[corridor.id] = true
		if not (ids.has(corridor.room_a) and ids.has(corridor.room_b)):
			problems.append("corridor '%s' joins unknown room(s)" % corridor.id)
		if corridor.room_a == corridor.room_b:
			problems.append("corridor '%s' joins '%s' to itself" % [corridor.id, corridor.room_a])
		var pair := "%s|%s" % ([corridor.room_a, corridor.room_b] if corridor.room_a < corridor.room_b else [corridor.room_b, corridor.room_a])
		if pairs.has(pair):
			problems.append("corridors '%s' and '%s' join the same rooms" % [pairs[pair], corridor.id])
		pairs[pair] = corridor.id
		if not corridor.is_loop:
			entries[corridor.room_b] = int(entries.get(corridor.room_b, 0)) + 1
	for room in rooms:
		var expected := 0 if room.is_start else 1
		if int(entries.get(room.id, 0)) != expected:
			problems.append("room '%s' has %d entry corridors, expected %d" % [room.id, int(entries.get(room.id, 0)), expected])

	# ponytail: O(cells) dict scan, fine for <100 rooms.
	var owner: Dictionary = {}
	var shapes: Array = []
	for room in rooms:
		shapes.append([room.id, room.get_rect()])
	for corridor in corridors:
		shapes.append([corridor.id, corridor.get_rect()])
		shapes.append([corridor.id + ":door", Rect2i(corridor.door_cell, Vector2i.ONE)])
	for shape in shapes:
		var rect: Rect2i = shape[1]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var cell := Vector2i(x, y)
				if owner.has(cell):
					problems.append("'%s' overlaps '%s' at %s" % [shape[0], owner[cell], cell])
				owner[cell] = shape[0]

	for room in rooms:
		if room.corner_cuts != Vector4i.ZERO and not MapGenerator.shape_ok(room.size, room.corner_cuts):
			problems.append("room '%s' corner cuts %s block its centre or lanes" % [room.id, room.corner_cuts])

	var reached: Dictionary = {get_start_room_id(): true}
	var frontier: Array[String] = [get_start_room_id()]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		for corridor in corridors:
			if corridor.is_loop:
				continue
			var other := ""
			if corridor.room_a == current:
				other = corridor.room_b
			elif corridor.room_b == current:
				other = corridor.room_a
			if other != "" and not reached.has(other):
				reached[other] = true
				frontier.append(other)
	for room in rooms:
		if not reached.has(room.id):
			problems.append("room '%s' unreachable from start" % room.id)
	return problems

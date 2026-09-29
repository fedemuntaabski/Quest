extends RefCounted
class_name MapGenerator

## MapGenerator: deterministic (same seed + params -> same MapLayout) DotE-style
## floor. Rooms sit on a coarse slot grid (SLOT_PITCH cells apart, max
## MAX_ROOM_SIZE) so they can never overlap; each new room attaches to an
## existing one through a straight corridor, giving a tree: connected, no
## orphans, and exactly one entry corridor per room (= its reveal group).
## Start = first room; exit = the room farthest from it (so the start->exit
## path always exists and is the longest one); vault = deepest other dead end.
##
## Session 11: generate() stays the tree, byte-for-byte (same RNG stream).
## Loops and room types are separate post-passes with their own salted RNGs,
## so they never move the tree nor each other: add_loops() appends is_loop
## corridors (each its own corridor-only reveal group), assign_room_types()
## tags rooms. generate_floor() chains the three for a FloorConfig floor.

const SLOT_PITCH := 9
const MAX_ROOM_SIZE := 5
const ROOM_SIZES: Array[Vector2i] = [Vector2i(5, 5), Vector2i(5, 3), Vector2i(3, 5), Vector2i(3, 3)]
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const MAX_ATTEMPTS := 500


## `branch_chance`: probability each new room hangs off a random earlier room
## instead of extending the newest one (0 = one long line, 1 = bushy).
static func generate(p_seed: int, room_count: int, branch_chance: float) -> MapLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed

	var layout := MapLayout.new()
	layout.map_seed = p_seed
	var slot_of: Dictionary = {}      # room_id -> Vector2i slot
	var room_at: Dictionary = {}      # Vector2i slot -> RoomData
	var order: Array[RoomData] = []

	var start := _make_room("room_0", Vector2i.ZERO, Vector2i(5, 5))
	start.is_start = true
	_add_room(layout, start, Vector2i.ZERO, slot_of, room_at, order)

	var last := start
	var attempts := 0
	while order.size() < room_count and attempts < MAX_ATTEMPTS:
		attempts += 1
		var base := last if rng.randf() >= branch_chance else order[rng.randi_range(0, order.size() - 1)]
		var base_slot: Vector2i = slot_of[base.id]
		var first_dir := rng.randi_range(0, DIRS.size() - 1)
		var child_slot := Vector2i.MAX
		for i in DIRS.size():
			var candidate: Vector2i = base_slot + DIRS[(first_dir + i) % DIRS.size()]
			if not room_at.has(candidate):
				child_slot = candidate
				break
		if child_slot == Vector2i.MAX:
			last = order[rng.randi_range(0, order.size() - 1)]
			continue

		var child := _make_room("room_%d" % order.size(), child_slot, ROOM_SIZES[rng.randi_range(0, ROOM_SIZES.size() - 1)])
		_add_room(layout, child, child_slot, slot_of, room_at, order)
		layout.corridors.append(_make_corridor(base, child, child_slot - base_slot, base_slot))
		base.neighbors.append(child.id)
		child.neighbors.append(base.id)
		last = child

	_mark_exit_and_vault(layout, start)
	return layout


## Full per-floor pipeline: tree -> optional loops -> room types.
static func generate_floor(p_seed: int, config: FloorConfig, floor_index: int) -> MapLayout:
	var layout := generate(p_seed, config.room_count(floor_index), config.branch_chance(floor_index))
	add_loops(layout, config.loop_chance(floor_index), config.max_loops(floor_index))
	assign_room_types(layout, config.room_types, floor_index)
	return layout


## Up to `max_loops` extra corridors, each slot rolling `loop_chance`.
## Candidates = rooms in 4-adjacent slots not joined yet: such a corridor only
## ever occupies the gap between those two slots, so it can't cross anything;
## each one is still re-checked with validate() and dropped if it breaks the
## map. Runs out of candidates (the "N attempts") -> fewer/no loops, never fails.
static func add_loops(layout: MapLayout, loop_chance: float, max_loops: int) -> void:
	if max_loops <= 0 or loop_chance <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.map_seed, "loops"])

	var room_at: Dictionary = {}   # Vector2i slot -> RoomData
	for room in layout.rooms:
		room_at[_slot_of(room)] = room
	var candidates: Array = []     # [from: RoomData, to: RoomData, dir: Vector2i]
	for room in layout.rooms:
		for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:  # each pair once
			var other: RoomData = room_at.get(_slot_of(room) + dir)
			if other and not room.neighbors.has(other.id):
				candidates.append([room, other, dir])
	_shuffle(candidates, rng)

	var next := 0
	for i in max_loops:
		if rng.randf() >= loop_chance:
			continue
		while next < candidates.size():
			var from: RoomData = candidates[next][0]
			var to: RoomData = candidates[next][1]
			var corridor := _make_corridor(from, to, candidates[next][2], _slot_of(from))
			next += 1
			corridor.id = "loop_%s_%s" % [from.id, to.id]
			corridor.is_loop = true
			layout.corridors.append(corridor)
			if layout.validate().is_empty():
				from.neighbors.append(to.id)
				to.neighbors.append(from.id)
				break
			layout.corridors.pop_back()


## Tags non-start/exit rooms with the special types of `rules`, in rule order:
## each rule gets max_count_at(floor) slots, each rolling chance_at(floor) and
## taking the next (shuffled) candidate. Geometry is never touched.
static func assign_room_types(layout: MapLayout, rules: Array[RoomTypeRule], floor_index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.map_seed, "room_types"])
	var candidates: Array = []
	for room in layout.rooms:
		room.room_type = RoomData.RoomType.COMBAT
		if not (room.is_start or room.is_exit):
			candidates.append(room)
	_shuffle(candidates, rng)

	var next := 0
	for rule in rules:
		# Start/Exit are fixed by the tree (is_start/is_exit), never rolled.
		if rule == null or rule.type == RoomData.RoomType.START or rule.type == RoomData.RoomType.EXIT:
			continue
		for i in rule.max_count_at(floor_index):
			if next >= candidates.size():
				return
			if rng.randf() < rule.chance_at(floor_index):
				(candidates[next] as RoomData).room_type = rule.type
				next += 1


## Slot of a generated room (rooms sit inside their slot box, inset < SLOT_PITCH;
## floor() keeps negative slots right).
static func _slot_of(room: RoomData) -> Vector2i:
	return Vector2i((Vector2(room.pos) / SLOT_PITCH).floor())


## Fisher-Yates on our own RNG (never the global shuffle(): determinism).
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


static func _make_room(id: String, slot: Vector2i, size: Vector2i) -> RoomData:
	var room := RoomData.new()
	room.id = id
	room.size = size
	# Center inside the slot's MAX_ROOM_SIZE box so the box's middle row/column
	# (where corridors run) always crosses the room.
	room.pos = slot * SLOT_PITCH + (Vector2i(MAX_ROOM_SIZE, MAX_ROOM_SIZE) - size) / 2
	return room


static func _add_room(layout: MapLayout, room: RoomData, slot: Vector2i, slot_of: Dictionary, room_at: Dictionary, order: Array[RoomData]) -> void:
	layout.rooms.append(room)
	slot_of[room.id] = slot
	room_at[slot] = room
	order.append(room)


## Door cell hugs `from`'s wall; the corridor fills the gap up to `to`'s wall.
static func _make_corridor(from: RoomData, to: RoomData, dir: Vector2i, from_slot: Vector2i) -> CorridorData:
	var axis := 0 if dir.x != 0 else 1
	var cross := 1 - axis
	var lane := from_slot[cross] * SLOT_PITCH + MAX_ROOM_SIZE / 2

	var door := 0
	var lo := 0
	var hi := 0
	if dir[axis] > 0:
		door = from.pos[axis] + from.size[axis]
		lo = door + 1
		hi = to.pos[axis] - 1
	else:
		door = from.pos[axis] - 1
		lo = to.pos[axis] + to.size[axis]
		hi = door - 1

	var corridor := CorridorData.new()
	corridor.id = "corr_%s" % to.id
	corridor.room_a = from.id
	corridor.room_b = to.id
	var door_cell := Vector2i.ZERO
	door_cell[axis] = door
	door_cell[cross] = lane
	corridor.door_cell = door_cell
	var pos := Vector2i.ZERO
	pos[axis] = lo
	pos[cross] = lane
	corridor.pos = pos
	var size := Vector2i.ONE
	size[axis] = hi - lo + 1
	corridor.size = size
	return corridor


static func _mark_exit_and_vault(layout: MapLayout, start: RoomData) -> void:
	var depth: Dictionary = {start.id: 0}
	var frontier: Array[String] = [start.id]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		for neighbor in layout.get_room(current).neighbors:
			if not depth.has(neighbor):
				depth[neighbor] = int(depth[current]) + 1
				frontier.append(neighbor)

	var exit_room := start
	for room in layout.rooms:
		if int(depth[room.id]) > int(depth[exit_room.id]):
			exit_room = room
	exit_room.is_exit = true

	var vault: RoomData = null
	for room in layout.rooms:
		if room == start or room == exit_room or room.neighbors.size() != 1:
			continue
		if vault == null or int(depth[room.id]) > int(depth[vault.id]):
			vault = room
	if vault:
		vault.is_vault = true

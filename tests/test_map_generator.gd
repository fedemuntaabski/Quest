extends SceneTree

## Headless self-check for MapGenerator + fallback layout: 1000 floors
## (200 seeds x 5 floors) through generate_floor (tree + loops + room types),
## a loop stress pass, hand-built invalid layouts, determinism. Run:
##   godot --headless --path . --script res://tests/test_map_generator.gd
## Exit code 0 = all good, 1 = failure (details printed).

const SEEDS_PER_FLOOR := 200
const SPECIAL_TYPES := [RoomData.RoomType.REST, RoomData.RoomType.LOOT, RoomData.RoomType.ELITE]

var failures: Array[String] = []


func _init() -> void:
	var fallback := load("res://resources/maps/fallback_layout.tres") as MapLayout
	if fallback == null or not fallback.validate().is_empty():
		failures.append("fallback invalid: %s" % (fallback.validate() if fallback else "null"))

	var config := load("res://resources/floors/default_floor_config.tres") as FloorConfig
	_check_config(config)

	var loops_per_floor: Array[float] = []
	var seen_types: Dictionary = {}
	var maps_with_loops := 0
	for floor_index in range(1, config.max_floors + 1):
		var loops_total := 0
		for s in range(SEEDS_PER_FLOOR):
			var map_seed := s * 7919 + floor_index
			var tree := MapGenerator.generate(map_seed, config.room_count(floor_index), config.branch_chance(floor_index))
			var layout := MapGenerator.generate_floor(map_seed, config, floor_index)
			var where := "floor %d seed %d" % [floor_index, s]
			var loops := _check_layout(layout, tree, config, floor_index, where)
			loops_total += loops
			maps_with_loops += int(loops > 0)
			for room in layout.rooms:
				seen_types[room.get_room_type()] = true
		loops_per_floor.append(float(loops_total) / SEEDS_PER_FLOOR)

	if maps_with_loops == 0:
		failures.append("no generated map got a loop")
	for type in SPECIAL_TYPES:
		if not seen_types.has(type):
			failures.append("room type %s never assigned" % RoomData.RoomType.keys()[type])
	if loops_per_floor[-1] <= loops_per_floor[0]:
		failures.append("loops don't scale per floor: avg %s" % [loops_per_floor])

	_stress_loops(config)
	_check_invalid_layouts()

	var a := MapGenerator.generate(42, 8, 0.4)
	var b := MapGenerator.generate(42, 8, 0.4)
	var c := MapGenerator.generate(43, 8, 0.4)
	if _signature(a) != _signature(b):
		failures.append("same seed produced different layouts")
	if _signature(a) == _signature(c):
		failures.append("different seeds produced identical layouts")
	if _signature(MapGenerator.generate_floor(42, config, 5)) != _signature(MapGenerator.generate_floor(42, config, 5)):
		failures.append("generate_floor: same seed produced different layouts (loops/types)")

	for failure in failures.slice(0, 20):
		printerr("FAIL: ", failure)
	print("test_map_generator: %s (%d failures) — loops/map by floor %s" % ["OK" if failures.is_empty() else "FAILED", failures.size(), loops_per_floor])
	quit(0 if failures.is_empty() else 1)


## Per-floor scaling never goes down, and the default config has every special type.
func _check_config(config: FloorConfig) -> void:
	for type in SPECIAL_TYPES:
		if config.get_room_type_rule(type) == null:
			failures.append("default config has no rule for %s" % RoomData.RoomType.keys()[type])
	for f in range(1, config.max_floors):
		if config.max_loops(f + 1) < config.max_loops(f) or config.loop_chance(f + 1) < config.loop_chance(f):
			failures.append("loop scaling goes down at floor %d" % f)
		for rule in config.room_types:
			if rule.max_count_at(f + 1) < rule.max_count_at(f) or rule.chance_at(f + 1) < rule.chance_at(f) or rule.reward_at(f + 1) < rule.reward_at(f):
				failures.append("%s scaling goes down at floor %d" % [RoomData.RoomType.keys()[rule.type], f])
	if config.max_loops(config.max_floors) <= config.max_loops(1):
		failures.append("max_loops doesn't grow with floors")


## Returns the loop count. `tree` = generate() with the same seed.
func _check_layout(layout: MapLayout, tree: MapLayout, config: FloorConfig, floor_index: int, where: String) -> int:
	var problems := layout.validate()
	if not problems.is_empty():
		failures.append("%s: %s" % [where, problems])
	if layout.rooms.size() != config.room_count(floor_index):
		failures.append("%s: %d rooms, wanted %d" % [where, layout.rooms.size(), config.room_count(floor_index)])
	# Loops/types never move the tree: rooms + non-loop corridors == plain generate().
	if _signature(layout, false) != _signature(tree, false):
		failures.append("%s: loops/types altered the tree layout" % where)

	var starts: Array[String] = []
	var exits: Array[String] = []
	var counts: Dictionary = {}
	for room in layout.rooms:
		var type := room.get_room_type()
		counts[type] = int(counts.get(type, 0)) + 1
		if type == RoomData.RoomType.START:
			starts.append(room.id)
		elif type == RoomData.RoomType.EXIT:
			exits.append(room.id)
		if (room.is_start or room.is_exit) and room.room_type != RoomData.RoomType.COMBAT:
			failures.append("%s: start/exit '%s' also tagged %s" % [where, room.id, RoomData.RoomType.keys()[room.room_type]])
	if starts.size() != 1 or exits.size() != 1 or starts == exits:
		failures.append("%s: starts %s exits %s" % [where, starts, exits])
	elif starts[0] != tree.get_start_room_id() or not tree.get_room(exits[0]).is_exit:
		failures.append("%s: start/exit moved (%s/%s)" % [where, starts[0], exits[0]])
	for rule in config.room_types:
		if int(counts.get(rule.type, 0)) > rule.max_count_at(floor_index):
			failures.append("%s: %d %s rooms > max %d" % [where, counts[rule.type], RoomData.RoomType.keys()[rule.type], rule.max_count_at(floor_index)])

	var loops := 0
	for corridor in layout.corridors:
		if not corridor.is_loop:
			continue
		loops += 1
		var room_a := tree.get_room(corridor.room_a)
		var room_b := tree.get_room(corridor.room_b)
		if room_a == null or room_b == null or room_a.neighbors.has(room_b.id):
			failures.append("%s: loop '%s' joins unknown or already-joined rooms" % [where, corridor.id])
		elif (MapGenerator._slot_of(room_a) - MapGenerator._slot_of(room_b)).abs() not in [Vector2i(1, 0), Vector2i(0, 1)]:
			failures.append("%s: loop '%s' joins non-adjacent slots" % [where, corridor.id])
	if loops > config.max_loops(floor_index):
		failures.append("%s: %d loops > max %d" % [where, loops, config.max_loops(floor_index)])
	if not _all_reachable(layout):
		failures.append("%s: not every room reachable over all corridors" % where)
	return loops


## Every candidate pair becomes a loop: geometry must still validate.
func _stress_loops(config: FloorConfig) -> void:
	var total := 0
	for s in range(SEEDS_PER_FLOOR):
		var layout := MapGenerator.generate(s * 104729 + 3, config.max_room_count, 0.6)
		var before := layout.corridors.size()
		MapGenerator.add_loops(layout, 1.0, 999)
		total += layout.corridors.size() - before
		var problems := layout.validate()
		if not problems.is_empty():
			failures.append("stress seed %d: %s" % [s, problems])
	if total == 0:
		failures.append("stress: no loops added at all")


## validate() must still catch broken loop setups.
func _check_invalid_layouts() -> void:
	# a --tree--> b; c reached only through a loop: unreachable (never revealed).
	var only_loop := _tiny_layout()
	only_loop.corridors.assign([_corridor("corr_b", "a", "b", false, Vector2i(5, 0)), _corridor("loop_b_c", "b", "c", true, Vector2i(14, 0))])
	_expect_problem(only_loop, "unreachable", "room only reachable through a loop")
	_expect_problem(only_loop, "entry corridors", "room without a non-loop entry")

	var twice := _tiny_layout()
	twice.corridors.assign([_corridor("corr_b", "a", "b", false, Vector2i(5, 0)), _corridor("corr_c", "b", "c", false, Vector2i(14, 0)), _corridor("loop_a_b", "a", "b", true, Vector2i(5, 3))])
	_expect_problem(twice, "join the same rooms", "loop duplicating a tree corridor")

	var dup_id := _tiny_layout()
	dup_id.corridors.assign([_corridor("corr_b", "a", "b", false, Vector2i(5, 0)), _corridor("corr_b", "b", "c", false, Vector2i(14, 0))])
	_expect_problem(dup_id, "duplicate id", "duplicate corridor id")

	var ok := _tiny_layout()
	ok.corridors.assign([_corridor("corr_b", "a", "b", false, Vector2i(5, 0)), _corridor("corr_c", "b", "c", false, Vector2i(14, 0))])
	if not ok.validate().is_empty():
		failures.append("hand-built valid layout rejected: %s" % [ok.validate()])


## Three 3x3 rooms in a row, 9 cells apart (a = start, c = exit).
func _tiny_layout() -> MapLayout:
	var layout := MapLayout.new()
	for i in 3:
		var room := RoomData.new()
		room.id = ["a", "b", "c"][i]
		room.pos = Vector2i(i * 9, 0)
		room.size = Vector2i(3, 3)
		room.is_start = i == 0
		room.is_exit = i == 2
		layout.rooms.append(room)
	return layout


func _corridor(id: String, room_a: String, room_b: String, is_loop: bool, door: Vector2i) -> CorridorData:
	var corridor := CorridorData.new()
	corridor.id = id
	corridor.room_a = room_a
	corridor.room_b = room_b
	corridor.is_loop = is_loop
	corridor.door_cell = door
	corridor.pos = door + Vector2i(1, 0)
	corridor.size = Vector2i(3, 1)
	return corridor


func _expect_problem(layout: MapLayout, needle: String, what: String) -> void:
	for problem in layout.validate():
		if needle in problem:
			return
	failures.append("validate() missed %s (got %s)" % [what, layout.validate()])


func _all_reachable(layout: MapLayout) -> bool:
	var reached: Dictionary = {layout.get_start_room_id(): true}
	var frontier: Array[String] = [layout.get_start_room_id()]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		for corridor in layout.corridors:
			var other := corridor.room_b if corridor.room_a == current else (corridor.room_a if corridor.room_b == current else "")
			if other != "" and not reached.has(other):
				reached[other] = true
				frontier.append(other)
	return reached.size() == layout.rooms.size()


## `with_loops` false = the tree part only (rooms + non-loop corridors).
func _signature(layout: MapLayout, with_loops: bool = true) -> String:
	var parts: Array[String] = []
	for room in layout.rooms:
		parts.append("%s%s%s" % [room.id, room.pos, room.size])
		if with_loops:
			parts.append(str(room.room_type))
	for corridor in layout.corridors:
		if with_loops or not corridor.is_loop:
			parts.append("%s%s%s" % [corridor.id, corridor.pos, corridor.door_cell])
	return ",".join(parts)

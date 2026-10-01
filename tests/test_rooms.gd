extends SceneTree

## Room types audit (session rooms-1): generation over 30 seeds x 5 floors
## (appears, quota, connectivity, start/exit never typed), display data per
## type (RoomTypeVisualConfig) and the discovery effect of Rest on a live Main2d
## with the whole party. Prints a per-type table. Complements test_map_flow.gd
## (rewards/spawn rules/elite multipliers) and test_door_alignment.gd.
##   godot --headless --path . --script res://tests/test_rooms.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const FLOOR_CONFIG_PATH := "res://resources/floors/default_floor_config.tres"
const VISUAL_PATH := "res://resources/maps/map_visual_config.tres"
const SEEDS := 30
const FLOORS := 5

var failures: Array[String] = []


func _initialize() -> void:
	var config := load(FLOOR_CONFIG_PATH) as FloorConfig
	var visual := load(VISUAL_PATH) as MapVisualConfig
	_check_generation(config)
	_check_display(config, visual)
	await _check_rest_heals_party(config)
	await _check_generator_slots(config)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_rooms: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _type_name(type: RoomData.RoomType) -> String:
	return RoomData.RoomType.find_key(type)


func _check_generation(config: FloorConfig) -> void:
	var counts: Dictionary = {}  # type -> Array[int] per floor
	for type in RoomData.RoomType.values():
		counts[type] = []
		counts[type].resize(FLOORS)
		counts[type].fill(0)
	for floor_index in range(1, FLOORS + 1):
		for s in SEEDS:
			var where := "seed %d floor %d" % [s, floor_index]
			var layout := MapGenerator.generate_floor(s, config, floor_index)
			var problems := layout.validate()
			if not problems.is_empty():
				failures.append("%s: invalid layout %s" % [where, problems])
			_check_connected(layout, where)
			var per_type: Dictionary = {}
			for room in layout.rooms:
				var type := room.get_room_type()
				counts[type][floor_index - 1] += 1
				per_type[type] = int(per_type.get(type, 0)) + 1
				if (room.is_start or room.is_exit) and room.room_type != RoomData.RoomType.COMBAT:
					failures.append("%s: start/exit '%s' also stores type %s" % [where, room.id, _type_name(room.room_type)])
			for rule in config.room_types:
				if int(per_type.get(rule.type, 0)) > rule.max_count_at(floor_index):
					failures.append("%s: %s over its quota (%d > %d)" % [where, _type_name(rule.type), per_type[rule.type], rule.max_count_at(floor_index)])
			for type in per_type:
				if type in [RoomData.RoomType.COMBAT, RoomData.RoomType.START, RoomData.RoomType.EXIT]:
					continue
				if config.get_room_type_rule(type) == null:
					failures.append("%s: %s generated without a RoomTypeRule" % [where, _type_name(type)])
	print("generation (%d seeds x %d floors), rooms per floor 1..5:" % [SEEDS, FLOORS])
	for type in RoomData.RoomType.values():
		print("  %-10s %s" % [_type_name(type), counts[type]])
		var total := 0
		for n in counts[type]:
			total += n
		var has_rule := config.get_room_type_rule(type) != null
		if has_rule and total == 0:
			failures.append("%s has a rule but never appeared in %d layouts" % [_type_name(type), SEEDS * FLOORS])


## Every room reachable from the start over all corridors; no loop touches the exit.
func _check_connected(layout: MapLayout, where: String) -> void:
	var start := ""
	for room in layout.rooms:
		if room.is_start:
			start = room.id
	var seen: Dictionary = {start: true}
	var frontier: Array[String] = [start]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		for corridor in layout.corridors:
			var other := ""
			if corridor.room_a == current:
				other = corridor.room_b
			elif corridor.room_b == current:
				other = corridor.room_a
			if other != "" and not seen.has(other):
				seen[other] = true
				frontier.append(other)
	if seen.size() != layout.rooms.size():
		failures.append("%s: %d of %d rooms reachable from the start" % [where, seen.size(), layout.rooms.size()])
	for corridor in layout.corridors:
		if corridor.is_loop and (layout.get_room(corridor.room_a).is_exit or layout.get_room(corridor.room_b).is_exit):
			failures.append("%s: loop '%s' touches the exit" % [where, corridor.id])


func _check_display(config: FloorConfig, visual: MapVisualConfig) -> void:
	for type in RoomData.RoomType.values():
		if type == RoomData.RoomType.COMBAT:
			continue
		var entry := visual.room_type_visual(type)
		var name := _type_name(type)
		if entry == null:
			failures.append("%s: no RoomTypeVisual" % name)
			continue
		if entry.display_name == "" or entry.color.a <= 0.0 or entry.banner_text == "" and type != RoomData.RoomType.START:
			failures.append("%s: needs display_name, opaque color and banner_text" % name)
		var generated := config.get_room_type_rule(type) != null
		if generated and not (entry.show_marker and entry.icon):
			failures.append("%s: generated type needs marker + icon (minimap/badge)" % name)
		if not generated and type not in [RoomData.RoomType.START, RoomData.RoomType.EXIT]:
			failures.append("%s: has a visual but no RoomTypeRule (never generated: design-only)" % name)


## Rest heals every living hero once (not just the primary one).
func _check_rest_heals_party(config: FloorConfig) -> void:
	var found_seed := -1
	var found_floor := 0
	var rest_id := ""
	for n in 500:
		for f in range(1, FLOORS + 1):
			seed(n)
			var layout := MapGenerator.generate_floor(hash([randi(), f]), config, f)
			for room in layout.rooms:
				if room.get_room_type() == RoomData.RoomType.REST and rest_id == "":
					rest_id = room.id
			if rest_id != "":
				found_seed = n
				found_floor = f
				break
		if rest_id != "":
			break
	if rest_id == "":
		failures.append("rest heal: no seed < 500 with a Rest room")
		return
	var resources := root.get_node("ResourceManager") as ResourceManager
	resources.reset_resources()
	seed(found_seed)
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.standalone_floor = found_floor
	root.add_child(main2d)
	await process_frame
	var label := "rest heal (seed %d floor %d '%s')" % [found_seed, found_floor, rest_id]
	var stats: Array[CharacterStats] = root.get_node("PlayerStats").get_all_stats()
	if stats.size() < 2:
		failures.append("%s: expected a 2-hero party, got %d" % [label, stats.size()])
	var rule := config.get_room_type_rule(RoomData.RoomType.REST)
	for s in stats:
		s.current_hp = s.max_hp
		s.take_damage(10)
	var before: Array[int] = []
	for s in stats:
		before.append(s.current_hp)
	main2d.floor_manager.on_room_discovered(rest_id, [] as Array[Vector2i])
	for i in stats.size():
		var expected := mini(stats[i].max_hp, before[i] + rule.heal_on_discovery)
		if stats[i].current_hp != expected:
			failures.append("%s: hero '%s' hp %d -> %d, expected %d" % [label, stats[i].hero_id, before[i], stats[i].current_hp, expected])
	main2d.queue_free()
	await process_frame


## Generator room: lit, it offers 2 MAJOR + 2 MINOR slots (others: 1 + 2).
func _check_generator_slots(config: FloorConfig) -> void:
	var found_seed := -1
	var found_floor := 0
	var gen_id := ""
	for n in 500:
		for f in range(1, FLOORS + 1):
			seed(n)
			var layout := MapGenerator.generate_floor(hash([randi(), f]), config, f)
			for room in layout.rooms:
				if room.get_room_type() == RoomData.RoomType.GENERATOR and gen_id == "":
					gen_id = room.id
			if gen_id != "":
				found_seed = n
				found_floor = f
				break
		if gen_id != "":
			break
	if gen_id == "":
		failures.append("generator slots: no seed < 500 with a Generator room")
		return
	seed(found_seed)
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.standalone_floor = found_floor
	root.add_child(main2d)
	await process_frame
	var room_manager: RoomManager = main2d.room_manager
	var label := "generator slots (seed %d floor %d '%s')" % [found_seed, found_floor, gen_id]
	var plain := ""
	for room in main2d.map_layout.rooms:
		if room.get_room_type() == RoomData.RoomType.COMBAT and not room.is_start and plain == "":
			plain = room.id
	for pair in [[gen_id, 2], [plain, 1]]:
		var zone := room_manager.get_zone_node(pair[0])
		zone.set_powered(true)
		var majors := 0
		var minors := 0
		for slot in zone._building_slots:
			if slot.slot_type == BuildingSlot.SlotType.MAJOR:
				majors += 1
			else:
				minors += 1
		if majors != pair[1] or minors != 2:
			failures.append("%s: '%s' has %d major / %d minor slots, expected %d / 2" % [label, pair[0], majors, minors, pair[1]])
	main2d.queue_free()
	await process_frame

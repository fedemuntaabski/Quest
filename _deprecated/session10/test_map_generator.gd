extends SceneTree

## Headless self-check for MapGenerator + fallback layout. Run:
##   godot --headless --path . --script res://tests/test_map_generator.gd
## Exit code 0 = all good, 1 = failure (details printed).

func _init() -> void:
	var failures: Array[String] = []

	var fallback := load("res://resources/maps/fallback_layout.tres") as MapLayout
	if fallback == null or not fallback.validate().is_empty():
		failures.append("fallback invalid: %s" % (fallback.validate() if fallback else "null"))

	var config := load("res://resources/floors/default_floor_config.tres") as FloorConfig
	for floor_index in range(1, config.max_floors + 1):
		for s in range(200):
			var layout := MapGenerator.generate(s * 7919 + floor_index, config.room_count(floor_index), config.branch_chance(floor_index))
			var problems := layout.validate()
			if not problems.is_empty():
				failures.append("floor %d seed %d: %s" % [floor_index, s, problems])
			if layout.rooms.size() != config.room_count(floor_index):
				failures.append("floor %d seed %d: %d rooms, wanted %d" % [floor_index, s, layout.rooms.size(), config.room_count(floor_index)])

	var a := MapGenerator.generate(42, 8, 0.4)
	var b := MapGenerator.generate(42, 8, 0.4)
	var c := MapGenerator.generate(43, 8, 0.4)
	if _signature(a) != _signature(b):
		failures.append("same seed produced different layouts")
	if _signature(a) == _signature(c):
		failures.append("different seeds produced identical layouts")

	for failure in failures.slice(0, 20):
		printerr("FAIL: ", failure)
	print("test_map_generator: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _signature(layout: MapLayout) -> String:
	var parts: Array[String] = []
	for room in layout.rooms:
		parts.append("%s%s%s" % [room.id, room.pos, room.size])
	for corridor in layout.corridors:
		parts.append("%s%s%s" % [corridor.id, corridor.pos, corridor.door_cell])
	return ",".join(parts)

extends SceneTree

## Headless smoke test: boots Main2d (generated map, then fallback), opens
## every door in reveal order and checks discovery dust + fog consistency.
##   godot --headless --path . --script res://tests/test_map_flow.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	await _run(false)
	await _run(true)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_map_flow: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _run(use_fallback: bool) -> void:
	var resources := root.get_node("ResourceManager") as ResourceManager
	resources.reset_resources()
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = use_fallback
	root.add_child(main2d)
	await process_frame

	var room_manager: RoomManager = main2d.room_manager
	var doors: DoorTurnSystem = main2d.door_turn_system
	var label := "fallback" if use_fallback else "generated"
	if use_fallback and room_manager.get_start_zone_id() != "start_room":
		failures.append("fallback start is '%s'" % room_manager.get_start_zone_id())

	var per_room: int = main2d.floor_manager.config.discovery_dust(1)
	var opened := 0
	var progress := true
	while progress:
		progress = false
		for door in room_manager.get_all_doors():
			if door.is_open or not room_manager.is_zone_revealed(door.from_zone_id):
				continue
			var dust_before := resources.get_resource("dust")
			if not doors.open_room(door.target_room_id):
				failures.append("%s: open_room('%s') refused" % [label, door.target_room_id])
			door.disable_door()
			opened += 1
			progress = true
			if resources.get_resource("dust") - dust_before != per_room:
				failures.append("%s: discovering '%s' gave %d dust, expected %d" % [label, door.target_room_id, resources.get_resource("dust") - dust_before, per_room])

	if opened != main2d.map_layout.corridors.size():
		failures.append("%s: opened %d of %d doors" % [label, opened, main2d.map_layout.corridors.size()])
	if not room_manager.validate_visibility():
		failures.append("%s: visibility mismatch" % label)
	var exit_found := false
	for zone_id in room_manager.get_zone_ids():
		exit_found = exit_found or room_manager.is_exit_room(zone_id)
	if not exit_found:
		failures.append("%s: no exit zone" % label)
	if not room_manager.find_zone_path(room_manager.get_start_zone_id(), _exit_zone(room_manager)).size() > 1:
		failures.append("%s: no revealed path start -> exit" % label)

	main2d.queue_free()
	await process_frame


func _exit_zone(room_manager: RoomManager) -> String:
	for zone_id in room_manager.get_zone_ids():
		if room_manager.is_exit_room(zone_id):
			return zone_id
	return ""

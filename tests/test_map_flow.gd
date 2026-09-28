extends SceneTree

## Headless smoke test: boots Main2d (generated map, then fallback), opens
## every door in reveal order and checks discovery dust + fog consistency,
## room lighting (dark/lit/affordable) and the exit hint modes.
##   godot --headless --path . --script res://tests/test_map_flow.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	_check_edge_point()
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

	_check_lighting(room_manager, label)
	var indicator: ExitIndicator = main2d.exit_indicator
	var config := room_manager.visual_config
	if config.exit_hint_mode != MapVisualConfig.ExitHintMode.ON_DISCOVERY:
		failures.append("%s: default exit_hint_mode is %s, expected ON_DISCOVERY" % [label, MapVisualConfig.ExitHintMode.keys()[config.exit_hint_mode]])
	_expect_hint_drawn(indicator, false, "%s start (default mode)" % label)
	_expect_hint(indicator, config, MapVisualConfig.ExitHintMode.ALWAYS, true, "%s start" % label)
	_expect_hint(indicator, config, MapVisualConfig.ExitHintMode.ON_DISCOVERY, false, "%s start" % label)
	_expect_hint(indicator, config, MapVisualConfig.ExitHintMode.ON_CRYSTAL, false, "%s start" % label)

	config.exit_hint_mode = MapVisualConfig.ExitHintMode.ON_DISCOVERY
	var exit_zone := _exit_zone(room_manager)
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
			_expect_hint_drawn(indicator, room_manager.is_zone_revealed(exit_zone), "%s after opening '%s'" % [label, door.target_room_id])

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

	_expect_hint(indicator, config, MapVisualConfig.ExitHintMode.ON_DISCOVERY, true, "%s explored" % label)
	_expect_hint(indicator, config, MapVisualConfig.ExitHintMode.ON_CRYSTAL, false, "%s explored" % label)
	main2d.extraction_manager.start_extraction()
	_expect_hint(indicator, config, MapVisualConfig.ExitHintMode.ON_CRYSTAL, true, "%s carrying" % label)
	if not indicator.is_emphasized():
		failures.append("%s: exit hint not emphasized while carrying the crystal" % label)
	# Shared cached .tres: restore the default for the next run.
	config.exit_hint_mode = MapVisualConfig.ExitHintMode.ON_DISCOVERY

	main2d.queue_free()
	await process_frame


func _exit_zone(room_manager: RoomManager) -> String:
	for zone_id in room_manager.get_zone_ids():
		if room_manager.is_exit_room(zone_id):
			return zone_id
	return ""


## Mode changes must propagate through config.changed alone (no manual refresh).
func _expect_hint(indicator: ExitIndicator, config: MapVisualConfig, mode: MapVisualConfig.ExitHintMode, expected: bool, when: String) -> void:
	config.exit_hint_mode = mode
	if indicator.is_hint_visible() != expected:
		failures.append("%s: exit hint mode %s visible=%s, expected %s" % [when, MapVisualConfig.ExitHintMode.keys()[mode], indicator.is_hint_visible(), expected])


## Marker drawn + arrow able to show (only _process places it) == `expected`.
func _expect_hint_drawn(indicator: ExitIndicator, expected: bool, when: String) -> void:
	var marker := indicator.get_node("ExitMarker") as Node2D
	var arrow := indicator.get_node("ExitArrowLayer/ExitArrow") as Node2D
	if marker.visible != expected or indicator.is_processing() != expected:
		failures.append("%s: marker visible=%s arrow active=%s, expected %s" % [when, marker.visible, indicator.is_processing(), expected])
	if not expected and arrow.visible:
		failures.append("%s: arrow visible while hint hidden" % when)


func _check_lighting(room_manager: RoomManager, label: String) -> void:
	var zone := room_manager.get_zone_node(room_manager.get_start_zone_id())
	var light := zone.get_light()
	if light == null:
		failures.append("%s: start room has no RoomLight" % label)
		return
	if not light.is_dark():
		failures.append("%s: unpowered start room not dark" % label)
	if not light.is_affordable_highlighted():
		failures.append("%s: 20 dust >= cost but room not highlighted as affordable" % label)
	zone.set_powered(true)
	if light.is_dark() or light.is_affordable_highlighted():
		failures.append("%s: powered room still dark/affordable" % label)
	zone.set_powered(false)
	if not light.is_dark():
		failures.append("%s: unpowered-again room not dark" % label)


func _check_edge_point() -> void:
	var rect := Rect2(0, 0, 100, 100)
	for case in [[Vector2(300, 50), Vector2(100, 50)], [Vector2(50, -200), Vector2(50, 0)], [Vector2(50, 50), Vector2(50, 50)]]:
		var got := ExitIndicator.edge_point(rect, case[0])
		if not got.is_equal_approx(case[1]):
			failures.append("edge_point(%s) = %s, expected %s" % [case[0], got, case[1]])

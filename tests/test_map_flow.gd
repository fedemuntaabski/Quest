extends SceneTree

## Headless smoke test: boots Main2d (generated map, then fallback), opens
## every door in reveal order and checks discovery dust + fog consistency,
## room lighting (start lit, middle-click toggle + refund, dark canvas), the
## exit hint modes and the exit-gated Nexo pickup.
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

	var minimap := Minimap.new()
	root.add_child(minimap)
	await process_frame
	if not minimap.visible:
		failures.append("%s: minimap hid itself (no RoomManager?)" % label)
	minimap.queue_free()

	var camera := main2d.player.get_node_or_null("Camera2D") as GameCamera
	var start_bounds := Rect2()
	if camera == null:
		failures.append("%s: Player/Camera2D is not a GameCamera" % label)
	else:
		start_bounds = await _check_camera(camera, main2d.player, label)

	_check_lighting(room_manager, resources, label)
	var nexo_controller: NexoController = main2d.nexo_controller
	if nexo_controller.get_block_reason() == "":
		failures.append("%s: Nexo pickable before discovering the exit" % label)
	nexo_controller.confirm_pickup()
	if main2d.extraction_manager.current_phase != ExtractionManager.Phase.EXPLORATION or main2d.player.is_carrying_nexo:
		failures.append("%s: confirm_pickup bypassed the exit gate" % label)
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

	if camera and not (camera.get_bounds().encloses(start_bounds) and camera.get_bounds().get_area() > start_bounds.get_area()):
		failures.append("%s: camera bounds %s did not grow past %s after exploring" % [label, camera.get_bounds(), start_bounds])

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
	if nexo_controller.get_block_reason() != "":
		failures.append("%s: Nexo still blocked after exploring: %s" % [label, nexo_controller.get_block_reason()])
	nexo_controller.confirm_pickup()
	if main2d.extraction_manager.current_phase != ExtractionManager.Phase.EXTRACTION or not main2d.player.is_carrying_nexo:
		failures.append("%s: confirming the Nexo dialog did not start extraction" % label)
	_expect_hint(indicator, config, MapVisualConfig.ExitHintMode.ON_CRYSTAL, true, "%s carrying" % label)
	if not indicator.is_emphasized():
		failures.append("%s: exit hint not emphasized while carrying the crystal" % label)
	# Shared cached .tres: restore the default for the next run.
	config.exit_hint_mode = MapVisualConfig.ExitHintMode.ON_DISCOVERY

	main2d.queue_free()
	await process_frame


## Follow, zoom limits, clamp to discovered rooms + margin, focus/recenter.
## Returns the start-of-floor bounds so the caller can check they grow.
func _check_camera(camera: GameCamera, player: Player, label: String) -> Rect2:
	# Headless mouse sits at (0,0) = a screen corner → edge scroll off here.
	camera.config = camera.config.duplicate()
	camera.config.edge_scroll_enabled = false
	await process_frame
	if not camera.top_level or not camera.is_following() or camera.global_position.distance_to(player.global_position) > 1.0:
		failures.append("%s: camera not following the hero at start (%s vs %s)" % [label, camera.global_position, player.global_position])
	var cfg := camera.config
	var expected_zoom := clampf(cfg.default_zoom, cfg.zoom_min, cfg.zoom_max)
	if not (is_equal_approx(camera.zoom.x, expected_zoom) and is_equal_approx(camera.get_target_zoom(), expected_zoom)) \
			or cfg.default_zoom < cfg.zoom_min or cfg.default_zoom > cfg.zoom_max:
		failures.append("%s: default zoom %f not applied on the first frame / outside [%f, %f] (zoom %f)" % [label, cfg.default_zoom, cfg.zoom_min, cfg.zoom_max, camera.zoom.x])
	camera.set_target_zoom(1000.0)
	if not is_equal_approx(camera.get_target_zoom(), camera.config.zoom_max):
		failures.append("%s: zoom not clamped to max (%f)" % [label, camera.get_target_zoom()])
	camera.set_target_zoom(0.0001)
	if not is_equal_approx(camera.get_target_zoom(), camera.config.zoom_min):
		failures.append("%s: zoom not clamped to min (%f)" % [label, camera.get_target_zoom()])
	camera.set_target_zoom(1.0)
	var bounds := camera.get_bounds()
	if not bounds.has_point(player.global_position) or bounds.size.x < camera.config.bounds_margin * 2.0:
		failures.append("%s: camera bounds %s miss the hero/margin" % [label, bounds])
	var far := Vector2(1e6, -1e6)
	var clamped := camera.clamp_to_bounds(far)
	if not bounds.grow(0.01).has_point(clamped) or clamped == far:
		failures.append("%s: clamp_to_bounds(%s) = %s outside %s" % [label, far, clamped, bounds])
	camera.focus_on(far)
	if camera.is_following() or not bounds.grow(0.01).has_point(camera.global_position):
		failures.append("%s: focus_on should stop following and stay clamped" % label)
	camera.recenter()
	await process_frame
	if not camera.is_following() or camera.global_position.distance_to(player.global_position) > 1.0:
		failures.append("%s: recenter did not return to the hero" % label)
	return bounds


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


## Start room lit for free; middle-click toggle pays/refunds POWER_COST; the
## free start light refunds nothing; dark canvas present.
func _check_lighting(room_manager: RoomManager, resources: ResourceManager, label: String) -> void:
	if room_manager.get_node_or_null("DarkCanvas") == null:
		failures.append("%s: no DarkCanvas CanvasModulate" % label)
	var zone := room_manager.get_zone_node(room_manager.get_start_zone_id())
	var light := zone.get_light()
	if light == null:
		failures.append("%s: start room has no RoomLight" % label)
		return
	if not zone.is_powered or light.is_dark():
		failures.append("%s: start room not lit by default" % label)
	var dust := resources.get_resource("dust")
	zone.toggle_power()
	if zone.is_powered or not light.is_dark() or resources.get_resource("dust") != dust:
		failures.append("%s: switching the free start light off must darken it without refund (dust %d -> %d)" % [label, dust, resources.get_resource("dust")])
	if not light.is_affordable_highlighted():
		failures.append("%s: %d dust >= cost but room not highlighted as affordable" % [label, dust])
	zone.toggle_power()
	if not zone.is_powered or light.is_dark() or light.is_affordable_highlighted() or resources.get_resource("dust") != dust - RoomZone.POWER_COST:
		failures.append("%s: middle-click light should cost %d dust" % [label, RoomZone.POWER_COST])
	zone.toggle_power()
	if zone.is_powered or resources.get_resource("dust") != dust:
		failures.append("%s: switching a paid light off should refund it" % label)
	zone.set_powered(true)  # restore the default for the rest of the run


func _check_edge_point() -> void:
	var rect := Rect2(0, 0, 100, 100)
	for case in [[Vector2(300, 50), Vector2(100, 50)], [Vector2(50, -200), Vector2(50, 0)], [Vector2(50, 50), Vector2(50, 50)]]:
		var got := ExitIndicator.edge_point(rect, case[0])
		if not got.is_equal_approx(case[1]):
			failures.append("edge_point(%s) = %s, expected %s" % [case[0], got, case[1]])

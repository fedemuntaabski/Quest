extends SceneTree

## Headless smoke test: boots Main2d (generated map, then fallback), opens
## every door in reveal order and checks discovery dust + fog consistency,
## room lighting (start lit, middle-click toggle + refund, dark canvas), the
## exit hint modes and the exit-gated Nexo pickup. Session 11: a map with a
## loop + Rest/Loot/Elite rooms (rewards, heal, spawn rules, loop paths, badges).
##   godot --headless --path . --script res://tests/test_map_flow.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const FLOOR_CONFIG_PATH := "res://resources/floors/default_floor_config.tres"
const REST_DAMAGE := 30

var failures: Array[String] = []


func _initialize() -> void:
	_check_edge_point()
	await _run(false)
	await _run(true)
	await _run_types_and_loops()
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
			var expected_dust := _expected_dust(main2d, door.target_room_id, per_room)
			if resources.get_resource("dust") - dust_before != expected_dust:
				failures.append("%s: discovering '%s' gave %d dust, expected %d" % [label, door.target_room_id, resources.get_resource("dust") - dust_before, expected_dust])
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


## Discovery dust for a group: 0 for a loop corridor (no room), else the
## per-room amount plus the room type's reward when it pays in dust.
func _expected_dust(main2d: Node, group_id: String, per_room: int) -> int:
	var room_manager: RoomManager = main2d.room_manager
	if room_manager.get_zone_kind(group_id) == "corridor":
		return 0
	var rule: RoomTypeRule = main2d.floor_manager.room_type_rule(room_manager.get_room_type(group_id))
	return per_room + (rule.reward_at(main2d.floor_manager.floor_index) if rule and rule.reward_resource == "dust" else 0)


## Session 11: boots a floor that has a loop + Rest + Loot + Elite (seed found
## offline through the same randi() -> hash([run_seed, floor]) path Main2d uses
## standalone), opens every door and checks each type's effect and the loops.
func _run_types_and_loops() -> void:
	var config := load(FLOOR_CONFIG_PATH) as FloorConfig
	var found := -1
	var floor_index := 0
	var wanted: MapLayout = null
	for n in range(500):
		for f in [3, 4, 5]:
			seed(n)
			var layout := MapGenerator.generate_floor(hash([randi(), f]), config, f)
			if _has_loop_and_types(layout):
				found = n
				floor_index = f
				wanted = layout
				break
		if found >= 0:
			break
	if found < 0:
		failures.append("types: no seed < 500 with a loop + Rest + Loot + Elite")
		return

	var resources := root.get_node("ResourceManager") as ResourceManager
	resources.reset_resources()
	seed(found)
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.standalone_floor = floor_index
	root.add_child(main2d)
	await process_frame
	var label := "types (seed %d floor %d)" % [found, floor_index]
	var layout: MapLayout = main2d.map_layout
	if layout.map_seed != wanted.map_seed or not _has_loop_and_types(layout):
		failures.append("%s: Main2d built another map (seed plumbing changed: %d vs %d)" % [label, layout.map_seed, wanted.map_seed])
		main2d.queue_free()
		await process_frame
		return

	var room_manager: RoomManager = main2d.room_manager
	var doors: DoorTurnSystem = main2d.door_turn_system
	var fm: FloorManager = main2d.floor_manager
	var enemies: EnemyManager = main2d.enemy_manager
	var hero_stats: CharacterStats = main2d.player.stats
	var per_room := config.discovery_dust(floor_index)
	var typed: Array[String] = []
	for room in layout.rooms:
		if RoomData.TYPE_LABELS.has(room.get_room_type()):
			typed.append(room.id)
			if room_manager.get_room_type(room.id) != room.get_room_type():
				failures.append("%s: RoomManager type of '%s' differs from the layout" % [label, room.id])
			var badge := room_manager.get_zone_node(room.id).get_node_or_null("TypeBadge") as Node2D
			if badge == null or badge.visible:
				failures.append("%s: '%s' badge missing or visible under fog" % [label, room.id])
	if room_manager.get_zone_node(room_manager.get_start_zone_id()).get_node_or_null("TypeBadge") != null:
		failures.append("%s: the start room got a type badge" % label)

	var progress := true
	while progress:
		progress = false
		for door in room_manager.get_all_doors():
			if door.is_open or not room_manager.is_zone_revealed(door.from_zone_id):
				continue
			var group := door.target_room_id
			var rule: RoomTypeRule = fm.room_type_rule(room_manager.get_room_type(group)) if room_manager.get_zone_kind(group) == "room" else null
			var reward_key := rule.reward_resource if rule else ""
			var reward_before := resources.get_resource(reward_key) if reward_key != "" else 0
			var reward_yield := resources.get_turn_yield(reward_key) if reward_key != "" else 0
			var dust_before := resources.get_resource("dust")
			if rule and rule.heal_on_discovery > 0:
				hero_stats.take_damage(REST_DAMAGE)
			var hp_before := hero_stats.current_hp
			if not doors.open_room(group):
				failures.append("%s: open_room('%s') refused" % [label, group])
			door.disable_door()
			progress = true
			var expected_dust := _expected_dust(main2d, group, per_room)
			if resources.get_resource("dust") - dust_before != expected_dust:
				failures.append("%s: discovering '%s' gave %d dust, expected %d" % [label, group, resources.get_resource("dust") - dust_before, expected_dust])
			if rule and reward_key != "" and reward_key != "dust":
				# The turn tick also pays the resource's yield.
				var got := resources.get_resource(reward_key) - reward_before - reward_yield
				if got != rule.reward_at(floor_index):
					failures.append("%s: '%s' reward %d %s, expected %d" % [label, group, got, reward_key, rule.reward_at(floor_index)])
				var after := resources.get_resource(reward_key)
				if doors.open_room(group) or resources.get_resource(reward_key) != after:
					failures.append("%s: '%s' reward paid twice" % [label, group])
			if rule and rule.heal_on_discovery > 0 and hero_stats.current_hp != mini(hero_stats.max_hp, hp_before + rule.heal_on_discovery):
				failures.append("%s: Rest '%s' healed %d -> %d, expected +%d" % [label, group, hp_before, hero_stats.current_hp, rule.heal_on_discovery])

	for room_id in typed:
		var badge := room_manager.get_zone_node(room_id).get_node("TypeBadge") as Node2D
		if not badge.visible:
			failures.append("%s: '%s' badge hidden after discovery" % [label, room_id])

	# Rest: never a spawn room (door-open invasions + extraction waves), lit or dark.
	var combat_room := ""
	for room in layout.rooms:
		if room.get_room_type() == RoomData.RoomType.COMBAT and combat_room == "":
			combat_room = room.id
	for room in layout.rooms:
		var type := room.get_room_type()
		var in_pool := enemies.get_spawn_rooms().any(func(z: RoomZone) -> bool: return z.zone_id == room.id)
		if type == RoomData.RoomType.REST:
			var count := enemies._enemies.size()
			enemies.spawn_enemies_in_room(room.id, 2)
			if in_pool or enemies._enemies.size() != count or not room_manager.is_room_dark(room.id):
				failures.append("%s: Rest room '%s' can host spawns (in pool %s)" % [label, room.id, in_pool])
			if not (room.id in room_manager.get_unpowered_revealed_room_group_ids()):
				failures.append("%s: Rest room '%s' should still count as dark" % [label, room.id])
		elif type != RoomData.RoomType.START and not in_pool:
			failures.append("%s: dark '%s' missing from the spawn pool" % [label, room.id])
		if type == RoomData.RoomType.ELITE:
			var rule := fm.room_type_rule(type)
			var elite := _spawn_one(enemies, room.id)
			var base := _spawn_one(enemies, combat_room)
			if elite == null or base == null:
				failures.append("%s: could not spawn in '%s'/'%s'" % [label, room.id, combat_room])
			else:
				var elite_hp := maxi(1, roundi(int(Enemy.VARIANT_CONFIG[elite.variant]["hp"]) * fm.enemy_hp_multiplier() * rule.enemy_hp_mult * elite.type.hp_mult))
				var base_hp := maxi(1, roundi(int(Enemy.VARIANT_CONFIG[base.variant]["hp"]) * fm.enemy_hp_multiplier() * base.type.hp_mult))
				if elite.max_hp != elite_hp or base.max_hp != base_hp:
					failures.append("%s: Elite hp %d (want %d), Combat hp %d (want %d)" % [label, elite.max_hp, elite_hp, base.max_hp, base_hp])

	# Loops: once open, the shortcut is the shortest path between its rooms.
	for corridor in layout.corridors:
		if not corridor.is_loop:
			continue
		var path := room_manager.find_zone_path(corridor.room_a, corridor.room_b)
		if " ".join(path) != "%s %s %s" % [corridor.room_a, corridor.id, corridor.room_b]:
			failures.append("%s: loop '%s' path %s" % [label, corridor.id, path])
		var door := room_manager.get_door_for_group(corridor.id)
		if door == null or door.room_a_id != corridor.room_a or door.room_b_id != corridor.room_b:
			failures.append("%s: loop '%s' door endpoints wrong" % [label, corridor.id])
	if not room_manager.validate_graph() or not room_manager.validate_visibility():
		failures.append("%s: graph/visibility validation failed" % label)

	var minimap := Minimap.new()
	root.add_child(minimap)
	await process_frame
	if not minimap.visible:
		failures.append("%s: minimap hid itself" % label)
	minimap.queue_free()
	main2d.queue_free()
	await process_frame


func _has_loop_and_types(layout: MapLayout) -> bool:
	var found: Dictionary = {}
	for room in layout.rooms:
		found[room.get_room_type()] = true
	var has_loop := layout.corridors.any(func(c: CorridorData) -> bool: return c.is_loop)
	return has_loop and found.has(RoomData.RoomType.REST) and found.has(RoomData.RoomType.LOOT) and found.has(RoomData.RoomType.ELITE)


## Spawns one enemy in a room's group and returns it (null if none spawned).
func _spawn_one(enemies: EnemyManager, room_id: String) -> Enemy:
	var before := enemies._enemies.size()
	enemies.spawn_enemies_in_room(room_id, 1)
	return enemies._enemies[-1] if enemies._enemies.size() > before else null


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

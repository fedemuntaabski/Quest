extends SceneTree

## Nexo + extraction (session bucle-7):
##   - extraction waves go by stages: bigger and closer together, capped at the last stage
##   - the carrier is 15 % slower (FloorConfig.carrier_speed_mult)
##   - a fallen carrier drops the Nexo; another hero picks it up, the run goes on
##   - the run is lost only when every hero is down
##   - assassins go for the carrier; with none they fall back to the next rule
##   godot --headless --path . --script res://tests/test_extraction_phases.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const IMP := "res://resources/enemies/imp.tres"  # assassin profile

var failures: Array[String] = []


func _initialize() -> void:
	_test_config()
	await _test_live()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_extraction_phases: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _test_config() -> void:
	var config: FloorConfig = load("res://resources/floors/default_floor_config.tres")
	_expect(is_equal_approx(config.carrier_speed_mult, 0.85), "carrier speed should default to 0.85")
	for floor_index in range(1, 6):
		var size := 0
		var gap := INF
		for stage in config.extraction_stage_count:
			var next_size := config.extraction_wave_size(stage)
			var next_gap := config.extraction_stage_interval(floor_index, stage)
			_expect(next_size >= size, "floor %d stage %d: wave shrinks" % [floor_index, stage])
			_expect(next_gap <= gap and next_gap >= config.min_extraction_spawn_interval, "floor %d stage %d: gap %.1f" % [floor_index, stage, next_gap])
			size = next_size
			gap = next_gap
		_expect(config.extraction_wave_size(config.extraction_stage_count - 1) > config.extraction_wave_size(0), "floor %d: waves never grow" % floor_index)


func _live_main2d() -> Node:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.standalone_floor = 1
	root.add_child(main2d)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false
	for group_id in main2d.door_turn_system.rooms.keys():
		main2d.door_turn_system.rooms[group_id]["visited"] = true
	main2d.room_manager.refresh_visibility()
	main2d.nexo.max_hp = 100000
	main2d.nexo.current_hp = 100000
	main2d.floor_manager.config = main2d.floor_manager.config.duplicate()
	main2d.floor_manager.config.max_enemies_by_floor = PackedInt32Array([999])
	return main2d


func _test_live() -> void:
	var main2d := await _live_main2d()
	var rm: RoomManager = main2d.room_manager
	var extraction: ExtractionManager = main2d.extraction_manager
	var enemies: EnemyManager = main2d.enemy_manager
	var nexo: Nexo = main2d.nexo
	var controller: NexoController = main2d.nexo_controller
	var config: FloorConfig = main2d.floor_manager.config
	var heroes: Array = main2d.heroes
	_expect(heroes.size() >= 2, "need two heroes")
	if heroes.size() < 2:
		return
	var carrier: Player = heroes[0]
	var other: Player = heroes[1]
	var start := rm.get_start_zone_id()
	var far := rm.get_center(start)

	# Carry speed comes from the config.
	_expect(is_equal_approx(main2d.player_action_controller._carrier_speed_mult(), config.carrier_speed_mult), "controller ignores carrier_speed_mult")

	# --- safe at the base: no timed spawns before the pickup ---
	_expect(extraction.current_phase == ExtractionManager.Phase.EXPLORATION and extraction._spawn_timer.is_stopped(), "waves running before the pickup")

	# --- pickup starts stage 0 ---
	var phases: Array = []
	extraction.phase_changed.connect(func(new_phase: int, _old: int) -> void: phases.append(new_phase))
	var stages: Array = []
	extraction.stage_changed.connect(func(stage: int) -> void: stages.append(stage))
	carrier.set_zone(start, far, main2d.floor_layer)
	_expect(controller.get_block_reason() == "" or controller.get_block_reason().begins_with("Descubr"), "unexpected block reason '%s'" % controller.get_block_reason())
	carrier.pick_up_nexo()
	nexo.pick_up()
	extraction.start_extraction()
	_expect(phases == [ExtractionManager.Phase.EXTRACTION], "phase_changed should fire once with EXTRACTION")
	_expect(extraction.stage == 0 and not extraction._spawn_timer.is_stopped(), "stage 0 / wave timer not started")
	_expect(is_equal_approx(extraction._spawn_timer.wait_time, config.extraction_stage_interval(1, 0)), "wave gap of stage 0")

	# --- stages grow, then hold at the last one ---
	enemies.spawn_wave(0)
	var first_wave := enemies.alive_count()
	extraction._on_spawn_timeout()
	var stage0_spawned := enemies.alive_count() - first_wave
	_expect(stage0_spawned == config.extraction_wave_size(0), "stage 0 wave spawned %d, want %d" % [stage0_spawned, config.extraction_wave_size(0)])
	for i in config.extraction_stage_count + 2:
		extraction._on_stage_timeout()
	_expect(extraction.stage == config.extraction_stage_count - 1, "stage stops at the last one (is %d)" % extraction.stage)
	_expect(stages == range(1, config.extraction_stage_count), "stage_changed sequence %s" % [stages])
	_expect(is_equal_approx(extraction._spawn_timer.wait_time, config.extraction_stage_interval(1, extraction.stage)), "wave gap of the last stage")
	var before_last := enemies.alive_count()
	extraction._on_spawn_timeout()
	_expect(enemies.alive_count() - before_last == config.extraction_wave_size(extraction.stage), "last stage wave size")

	# --- assassin goes for the carrier ---
	var assassin := enemies._spawn_enemy(start, rm.get_center(start))
	assassin.configure(Enemy.Variant.SWARM, start, 1.0, 1.0, load(IMP))
	var target := assassin.selector.select(rm)
	_expect(target != null and target.type == TargetRule.Type.HERO_CARRIER and target.node == carrier, "assassin should target the carrier")

	# --- the carrier falls (away from the base): the Nexo stays, the run goes on ---
	var carrier_zone := ""
	for zone_id in rm.get_zone_ids():
		if rm.get_zone_kind(zone_id) == "room" and zone_id != start:
			carrier_zone = zone_id
			break
	_expect(carrier_zone != "", "no second room to drop the Nexo in")
	carrier.set_zone(carrier_zone, rm.get_center(carrier_zone), main2d.floor_layer)
	carrier.stats.take_damage(carrier.stats.max_hp * 10)
	_expect(not main2d._is_dead, "the run ended with a hero still alive")
	_expect(nexo.is_dropped() and nexo.drop_zone_id == carrier_zone and not carrier.is_carrying_nexo, "Nexo not dropped where the carrier fell")
	_expect(nexo.visible and nexo.input_pickable, "dropped Nexo should be visible and clickable")
	_expect(nexo.get_target_zone(rm) == carrier_zone, "raiders should head for the dropped Nexo")
	_expect(extraction.current_phase == ExtractionManager.Phase.EXTRACTION, "extraction should go on")
	target = assassin.selector.select(rm)
	_expect(target != null and target.type != TargetRule.Type.HERO_CARRIER, "assassin has no carrier to chase")

	# --- another hero takes it ---
	root.get_node("SelectionManager").select_only(other.stats.hero_id)
	other.set_zone(start, far, main2d.floor_layer)
	_expect(controller.get_block_reason() != "", "pickup allowed away from the dropped Nexo")
	other.set_zone(carrier_zone, rm.get_center(carrier_zone), main2d.floor_layer)
	_expect(controller.get_block_reason() == "", "pickup refused next to the dropped Nexo: '%s'" % controller.get_block_reason())
	controller.confirm_pickup()
	_expect(other.is_carrying_nexo and nexo.is_carried() and not nexo.visible, "second hero did not take the Nexo")
	_expect(controller.get_block_reason() != "", "a carried Nexo cannot be taken again")
	_expect(phases.size() == 1, "re-pickup must not restart the extraction")

	# --- everyone down = defeat ---
	other.stats.take_damage(other.stats.max_hp * 10)
	_expect(main2d._is_dead, "the run should end when every hero is down")
	_expect(nexo.is_dropped(), "the second carrier's Nexo should drop as well")

	main2d.queue_free()
	await process_frame

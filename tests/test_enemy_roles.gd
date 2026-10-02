extends SceneTree

## Session enemies-2: HUNTER / RAIDER roles over a live Main2d (+ HUD).
##   - hunter picks the nearest hero in aggro_range, else the closest hero's zone
##   - raider ignores heroes, walks the shortest route to the Nexo and damages it
##   - raider turns on a hero that blocks / hits it
##   - raider share per floor follows FloorConfig.raider_ratio_by_floor
##   - Nexo: cracks by HP, under_attack, HUD alert, 0 HP = the usual defeat
##   - no raider stuck, none stacked, over 30 seeds on floors 1 and 5
##   godot --headless --path . --script res://tests/test_enemy_roles.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"
const GOBLIN: EnemyType = preload("res://resources/enemies/goblin.tres")
const SKELET: EnemyType = preload("res://resources/enemies/skelet.tres")
const FAR := Vector2(9000, 9000)
const RAIDERS_PER_RUN := 4
const ARRIVE_TIMEOUT := 60.0  # game seconds (Engine.time_scale speeds the wait up)

var failures: Array[String] = []


func _initialize() -> void:
	await _test_hunter()
	await _test_raider_route_and_damage()
	await _test_raider_reaction()
	await _test_ratios()
	await _test_nexo_feedback_and_defeat()
	for floor_index in [1, 5]:
		for s in range(1, 31):
			await _test_no_stuck(s, floor_index)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_enemy_roles: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _boot(fallback: bool, floor_index: int = 1, with_hud: bool = false) -> Array:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = fallback
	main2d.standalone_floor = floor_index
	root.add_child(main2d)
	await process_frame
	var hud: HUDController = null
	if with_hud:
		hud = (load(HUD_PATH) as PackedScene).instantiate() as HUDController
		root.add_child(hud)
		await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false
	for group_id in main2d.door_turn_system.rooms.keys():
		main2d.door_turn_system.rooms[group_id]["visited"] = true
	main2d.room_manager.refresh_visibility()
	main2d.nexo.max_hp = 100000  # the defeat is tested on its own
	main2d.nexo.current_hp = 100000
	return [main2d, hud]


func _free(main2d: Node, hud: Node = null) -> void:
	paused = false
	if hud:
		hud.queue_free()
	main2d.queue_free()
	await process_frame
	await process_frame


## An Enemy of `type` without its AI timer running, so tests call the AI by hand.
func _make_enemy(main2d: Node, type: EnemyType, zone_id: String, slot: int = 0, run_ai: bool = false) -> Enemy:
	var enemies: EnemyManager = main2d.enemy_manager
	var enemy := EnemyManager.ENEMY_SCENE.instantiate() as Enemy
	enemies._enemies_root.add_child(enemy)
	enemy.setup(main2d.room_manager.get_center(zone_id))
	enemy.slot = slot
	enemy.configure(Enemy.Variant.SWARM, zone_id, 1.0, 1.0, type)
	if not run_ai:
		enemy.ai_timer.stop()
	return enemy


func _place_hero(hero: Player, zone_id: String, pos: Vector2) -> void:
	hero.current_zone_id = zone_id
	hero.global_position = pos


func _rooms_by_distance(rm: RoomManager, from_zone: String) -> Array[String]:
	var rooms: Array[String] = []
	for zone_id in rm.get_zone_ids():
		if rm.get_zone_kind(zone_id) == "room" and rm.find_zone_path(from_zone, zone_id).size() > 0:
			rooms.append(zone_id)
	rooms.sort_custom(func(a: String, b: String): return rm.find_zone_path(from_zone, a).size() < rm.find_zone_path(from_zone, b).size())
	return rooms


func _test_hunter() -> void:
	var booted: Array = await _boot(true)
	var main2d = booted[0]
	var rm: RoomManager = main2d.room_manager
	var heroes: Array[Player] = main2d.heroes
	_expect(heroes.size() >= 2, "hunter: need 2 heroes, got %d" % heroes.size())
	var rooms := _rooms_by_distance(rm, rm.get_start_zone_id())
	var far_room: String = rooms[rooms.size() - 1]
	var enemy := _make_enemy(main2d, SKELET, far_room)
	_expect(enemy.role == EnemyType.Role.HUNTER, "hunter: skelet should be a HUNTER")

	# Both heroes in aggro, the second one nearer -> it is chosen.
	var here := rm.get_center(far_room)
	_place_hero(heroes[0], far_room, here + Vector2(200, 0))
	_place_hero(heroes[1], far_room, here + Vector2(60, 0))
	_expect(enemy._aggro_hero(rm) == heroes[1], "hunter: did not pick the nearest hero in aggro_range")
	_expect(enemy._goal_zone(rm) == far_room, "hunter: goal zone should be the hero's zone")
	_expect(enemy._goal_point(far_room) == heroes[1].global_position, "hunter: should close in on the hero's position")

	# No hero in aggro -> the zone of the closest hero by route.
	_place_hero(heroes[0], rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()))
	var second_zone: String = rooms[rooms.size() - 2]
	_place_hero(heroes[1], second_zone, rm.get_center(second_zone) + Vector2(0, 5000))  # outside aggro_range by position
	_expect(enemy._aggro_hero(rm) == null, "hunter: a hero beyond aggro_range was chosen")
	var expect_zone := enemy._player_zone(rm)
	_expect(enemy._goal_zone(rm) == expect_zone and expect_zone != "", "hunter: without aggro it should head for the closest hero's zone ('%s' vs '%s')" % [enemy._goal_zone(rm), expect_zone])
	await _free(main2d)


func _test_raider_route_and_damage() -> void:
	var booted: Array = await _boot(true)
	var main2d = booted[0]
	var rm: RoomManager = main2d.room_manager
	var nexo: Nexo = main2d.nexo
	for hero in main2d.heroes:
		_place_hero(hero, rm.get_start_zone_id(), FAR)
	var rooms := _rooms_by_distance(rm, rm.get_start_zone_id())
	var spawn: String = rooms[rooms.size() - 1]
	var expected := rm.find_zone_path(spawn, rm.get_start_zone_id())
	var raider := _make_enemy(main2d, GOBLIN, spawn, 0, true)
	_expect(raider.role == EnemyType.Role.RAIDER and raider.nexus_damage > 0, "raider: goblin should be a RAIDER with damage_vs_nexus")
	_expect(raider._goal_zone(rm) == rm.get_start_zone_id(), "raider: goal must be the Nexo's zone")

	var visited: Array[String] = [spawn]
	var waited := 0.0
	while waited < 40.0 and nexo.current_hp == nexo.max_hp:
		await create_timer(0.05).timeout
		waited += 0.05
		if raider.current_zone_id != visited[visited.size() - 1]:
			visited.append(raider.current_zone_id)
	_expect(nexo.current_hp < nexo.max_hp, "raider: never damaged the Nexo (zone '%s', waited %.1fs)" % [raider.current_zone_id, waited])
	for zone_id in visited:
		_expect(expected.has(zone_id), "raider: left the shortest route through '%s' (route %s)" % [zone_id, expected])
	_expect(visited[visited.size() - 1] == rm.get_start_zone_id(), "raider: did not end in the Nexo's zone")

	# Carried Nexo: the target follows the carrier.
	main2d.heroes[0].is_carrying_nexo = true
	_place_hero(main2d.heroes[0], spawn, rm.get_center(spawn) + Vector2(0, 5000))
	_expect(nexo.get_target_zone(rm) == spawn, "raider: carried Nexo target zone should be the carrier's")
	main2d.heroes[0].is_carrying_nexo = false
	await _free(main2d)


func _test_raider_reaction() -> void:
	var booted: Array = await _boot(true)
	var main2d = booted[0]
	var rm: RoomManager = main2d.room_manager
	var hero: Player = main2d.heroes[0]
	var zone: String = _rooms_by_distance(rm, rm.get_start_zone_id())[-1]
	for h in main2d.heroes:
		_place_hero(h, zone, FAR)
	var raider := _make_enemy(main2d, GOBLIN, zone)
	_expect(raider._is_raiding(), "raider reaction: should ignore far heroes")
	_place_hero(hero, zone, raider.global_position + Vector2(100, 0))  # near, not blocking
	raider._note_blocking_hero()
	_expect(raider._is_raiding(), "raider reaction: a hero 100px away must not distract it")
	_place_hero(hero, zone, raider.global_position + Vector2(20, 0))  # blocking
	raider._note_blocking_hero()
	_expect(not raider._is_raiding(), "raider reaction: a blocking hero should provoke it")
	_expect(raider._goal_zone(rm) == zone, "raider reaction: provoked raider should go for the hero")
	var attacked := _make_enemy(main2d, GOBLIN, zone)
	_place_hero(hero, zone, FAR)
	attacked._on_hurt(1)
	_expect(not attacked._is_raiding(), "raider reaction: a hit from a hero should provoke it")
	await _free(main2d)


func _test_ratios() -> void:
	var booted: Array = await _boot(true)
	var main2d = booted[0]
	var fm: FloorManager = main2d.floor_manager
	var config := fm.config
	var previous := -1.0
	for floor_index in range(1, 6):
		fm.floor_index = floor_index
		var ratio := fm.raider_ratio()
		_expect(is_equal_approx(ratio, config.raider_ratio_by_floor[floor_index - 1]), "ratio floor %d: %f != resource value" % [floor_index, ratio])
		_expect(ratio >= previous, "ratio floor %d: not non-decreasing" % floor_index)
		previous = ratio
		var rng := RandomNumberGenerator.new()
		rng.seed = floor_index
		var raiders := 0
		for i in 4000:
			raiders += int(fm.roll_role(rng) == EnemyType.Role.RAIDER)
		_expect(absf(raiders / 4000.0 - ratio) < 0.03, "ratio floor %d: rolled %.3f, expected %.3f" % [floor_index, raiders / 4000.0, ratio])
		# Pool data: both roles available on every floor.
		var pool := config.enemy_pool(floor_index)
		_expect(pool.roll(rng, EnemyType.Role.RAIDER) != null, "pool floor %d: no raider type" % floor_index)
		_expect(pool.roll(rng, EnemyType.Role.HUNTER) != null, "pool floor %d: no hunter type" % floor_index)
	_expect(config.raider_ratio(1) <= 0.1, "floor 1 should be almost only hunters")
	_expect(config.raider_ratio(5) > config.raider_ratio(1), "raiders should increase with floors")
	# Raiders look different: tint + marker; hunters stay plain.
	var rm: RoomManager = main2d.room_manager
	var raider := _make_enemy(main2d, GOBLIN, rm.get_start_zone_id())
	var hunter := _make_enemy(main2d, SKELET, rm.get_start_zone_id())
	_expect(raider.get_node_or_null("RaiderMarker") != null and raider.visual.modulate != Color.WHITE, "raider: missing tint/marker")
	_expect(hunter.get_node_or_null("RaiderMarker") == null and hunter.visual.modulate == Color.WHITE, "hunter: should look plain")
	await _free(main2d)


func _test_nexo_feedback_and_defeat() -> void:
	var booted: Array = await _boot(true, 1, true)
	var main2d = booted[0]
	var hud: HUDController = booted[1]
	var nexo: Nexo = main2d.nexo
	nexo.max_hp = 100
	nexo.current_hp = 100
	_expect(nexo.crack_stage() == 0, "nexo: intact at full HP")
	nexo.take_damage(25)
	_expect(nexo.crack_stage() == 1 and nexo.cracks[0].visible and not nexo.cracks[1].visible, "nexo: first crack at 75%")
	_expect(nexo.under_attack and hud.nexo_alert.visible, "nexo: HUD alert should show while attacked")
	nexo.take_damage(25)
	_expect(nexo.crack_stage() == 2, "nexo: second crack at 50%")
	nexo.take_damage(25)
	_expect(nexo.crack_stage() == 3, "nexo: third crack at 25%")
	await create_timer(Nexo.UNDER_ATTACK_SEC + 0.3).timeout
	_expect(not nexo.under_attack and not hud.nexo_alert.visible, "nexo: alert should end after the last hit")
	_expect(not main2d.game_state_manager.is_dead(), "nexo: alive at 25 HP")
	nexo.take_damage(25)
	_expect(nexo.current_hp == 0 and main2d.game_state_manager.is_dead(), "nexo: 0 HP must apply the usual defeat")
	await _free(main2d, hud)


## 4 raiders spawned together in the farthest room must all reach the Nexo, not stack.
func _test_no_stuck(s: int, floor_index: int) -> void:
	seed(s)
	var booted: Array = await _boot(false, floor_index)
	var main2d = booted[0]
	Engine.time_scale = 10.0  # Main2d resets it on exit; set per run
	var rm: RoomManager = main2d.room_manager
	var nexo: Nexo = main2d.nexo
	for hero in main2d.heroes:
		_place_hero(hero, rm.get_start_zone_id(), FAR)
	var rooms := _rooms_by_distance(rm, rm.get_start_zone_id())
	var spawn: String = rooms[rooms.size() - 1]
	var raiders: Array[Enemy] = []
	for i in RAIDERS_PER_RUN:
		raiders.append(_make_enemy(main2d, GOBLIN, spawn, i, true))
	var label := "seed %d floor %d" % [s, floor_index]
	var waited := 0.0
	while waited < ARRIVE_TIMEOUT and not raiders.all(func(e: Enemy): return e.current_state == Enemy.State.ATTACKING):
		await create_timer(0.25).timeout
		waited += 0.25
	for e in raiders:
		_expect(e.current_state == Enemy.State.ATTACKING and e.target_nexo == nexo, "%s: raider stuck in '%s' after %.0fs" % [label, e.current_zone_id, waited])
	for i in raiders.size():
		for j in range(i + 1, raiders.size()):
			_expect(raiders[i].global_position.distance_to(raiders[j].global_position) >= 8.0, "%s: raiders %d and %d stacked" % [label, i, j])
	await _free(main2d)

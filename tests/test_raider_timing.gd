extends SceneTree

## Raiders must give the player time to react (session enemies-2): over 30 seeds
## x 5 floors with every room revealed, no spawn roll in any eligible room may
## return a raider that reaches the Nexo sooner than FloorConfig.raider_min_arrival_sec.
## Also checks both roles stay compatible with turrets / Rest rooms (enemy_body
## layer, "enemies" group, blocks_spawns).
##   godot --headless --path . --script res://tests/test_raider_timing.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const SEEDS := 30
const ROLLS_PER_ROOM := 40

var failures: Array[String] = []
var raiders_seen := 0
var fallbacks_seen := 0


func _initialize() -> void:
	for floor_index in range(1, 6):
		for s in range(1, SEEDS + 1):
			await _run(s, floor_index)
	_expect(raiders_seen > 0, "no raider ever rolled: timing untested")
	_expect(fallbacks_seen > 0, "no room is too close for a raider: gate untested")
	print("test_raider_timing: %d raiders checked, %d too-close rooms" % [raiders_seen, fallbacks_seen])
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_raider_timing: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run(s: int, floor_index: int) -> void:
	seed(s)
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.standalone_floor = floor_index
	root.add_child(main2d)
	await process_frame
	var label := "seed %d floor %d" % [s, floor_index]
	var rm: RoomManager = main2d.room_manager
	var enemies: EnemyManager = main2d.enemy_manager
	var min_sec: float = main2d.floor_manager.config.raider_min_arrival_sec
	for group_id in main2d.door_turn_system.rooms.keys():
		main2d.door_turn_system.rooms[group_id]["visited"] = true
	rm.refresh_visibility()

	for zone_id in rm.get_zone_ids():
		if rm.get_zone_kind(zone_id) != "room":
			continue
		for i in ROLLS_PER_ROOM:
			var type := enemies._roll_type(zone_id)
			if type.role != EnemyType.Role.RAIDER:
				continue
			raiders_seen += 1
			var sec := enemies.raider_arrival_sec(zone_id, type)
			_expect(sec >= min_sec, "%s: raider '%s' from '%s' arrives in %.2fs < %.2fs" % [label, type.id, zone_id, sec, min_sec])
		# The gate bites somewhere: a plain goblin from this room would arrive too soon.
		if enemies.raider_arrival_sec(zone_id, EnemyManager.FALLBACK_TYPE) < min_sec:
			fallbacks_seen += 1

	# Compatibility: every spawned enemy (either role) is a plain turret target.
	for i in 6:
		var enemy := enemies._spawn_enemy(rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()))
		_expect(enemy.collision_layer == 2 and enemy.is_in_group("enemies"), "%s: enemy not targetable by turrets" % label)
		enemy.queue_free()
	for zone_id in rm.get_zone_ids():
		if rm.get_zone_kind(zone_id) == "room" and rm.get_room_type(zone_id) == RoomData.RoomType.REST:
			var before := enemies._enemies.size()
			enemies.spawn_enemies_in_room(rm.get_group_id(zone_id), 3)
			_expect(enemies._enemies.size() == before, "%s: Rest room '%s' spawned enemies" % [label, zone_id])

	main2d.queue_free()
	await process_frame

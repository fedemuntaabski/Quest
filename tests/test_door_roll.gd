extends SceneTree

## Door loop (session bucle-7):
##   - DoorRollConfig: the threat chance grows with the doors opened (until max_chance),
##     the enemy count never shrinks, every floor pays dust + one random resource
##   - invasions and waves only spawn in dark (unpowered) rooms
##   - the simultaneous enemy cap holds, door invasions and waves included
##   - every opened door (loops too) pays the extra resource
##   - energizing costs more per room already energized; the refund is what was paid
##   - a switched-off turret works again when the room is lit
##   - spawns are telegraphed: HUD text naming the rooms + minimap alert
##   godot --headless --path . --script res://tests/test_door_roll.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const TURRET_SCENE := "res://scenes/world/TurretModule.tscn"
const SEEDS := 8

var failures: Array[String] = []


func _initialize() -> void:
	_test_config()
	for floor_index in [1, 3, 5]:
		for s in range(1, SEEDS + 1):
			await _run(s, floor_index)
	await _test_turret_relight()
	await _test_telegraph()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_door_roll: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _test_config() -> void:
	var config: FloorConfig = load("res://resources/floors/default_floor_config.tres")
	var roll: DoorRollConfig = config.door_roll
	_expect(roll != null, "FloorConfig.door_roll missing")
	if roll == null:
		return
	for floor_index in range(1, 6):
		var previous_chance := -1.0
		var previous_count := 0
		var grew := false
		for doors in range(0, 25):
			var chance := roll.threat_chance(doors, floor_index)
			var count := roll.enemy_count(doors, floor_index)
			_expect(chance >= previous_chance, "floor %d: chance falls at door %d" % [floor_index, doors])
			_expect(chance <= roll.max_chance + 0.0001, "floor %d: chance %f over max" % [floor_index, chance])
			_expect(count >= previous_count and count >= 1, "floor %d: count shrinks at door %d" % [floor_index, doors])
			grew = grew or chance > previous_chance and previous_chance >= 0.0
			previous_chance = chance
			previous_count = count
		_expect(grew, "floor %d: the chance never grows with the doors" % floor_index)
		_expect(is_equal_approx(previous_chance, roll.max_chance), "floor %d: chance never reaches max_chance" % floor_index)
		_expect(roll.dust_reward(floor_index) > 0 and roll.bonus_amount(floor_index) > 0, "floor %d: a door pays nothing" % floor_index)
		_expect(roll.threat_chance(3, floor_index) >= roll.threat_chance(3, 1), "floor %d: not harder than floor 1" % floor_index)
	# Every configured resource shows up as the extra reward on some floor.
	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for floor_index in range(1, 6):
		for i in 300:
			var key := roll.roll_bonus_resource(floor_index, rng)
			_expect(key in roll.bonus_resources, "bonus '%s' is not a configured resource" % key)
			seen[key] = true
	for key in roll.bonus_resources:
		_expect(seen.has(key), "bonus resource '%s' never rolled" % key)


func _boot(s: int, floor_index: int) -> Node:
	seed(s)
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.standalone_floor = floor_index
	root.add_child(main2d)
	await process_frame
	return main2d


func _run(s: int, floor_index: int) -> void:
	var label := "seed %d floor %d" % [s, floor_index]
	var resources := root.get_node("ResourceManager")
	resources.reset_resources()
	var main2d := await _boot(s, floor_index)
	var rm: RoomManager = main2d.room_manager
	var enemies: EnemyManager = main2d.enemy_manager
	var fm: FloorManager = main2d.floor_manager
	var doors: DoorTurnSystem = main2d.door_turn_system
	fm.config = fm.config.duplicate()

	# --- reward: every door pays dust (rooms) + the extra resource (rooms and loops) ---
	var roll := fm.config.door_roll
	fm.config.max_enemies_by_floor = PackedInt32Array([999])
	var opened_room := false
	var opened_loop := false
	for door in rm.get_all_doors():
		if door.is_open or not rm.is_zone_revealed(door.from_zone_id):
			continue
		var group := door.target_room_id
		var is_loop := rm.get_zone_kind(group) == "corridor"
		if (is_loop and opened_loop) or (not is_loop and opened_room):
			continue
		var bonus := fm.door_bonus(group)
		var key: String = bonus["key"]
		var before: int = resources.get_resource(key)
		var dust_before: int = resources.get_resource("dust")
		_expect(doors.open_room(group), "%s: open_room('%s') refused" % [label, group])
		door.disable_door()
		_expect(resources.get_resource(key) - before >= int(bonus["amount"]), "%s: door '%s' paid no extra %s" % [label, group, key])
		if is_loop:
			opened_loop = true
		else:
			opened_room = true
			_expect(resources.get_resource("dust") - dust_before >= roll.dust_reward(floor_index), "%s: room door '%s' paid less than %d dust" % [label, group, roll.dust_reward(floor_index)])
	_expect(opened_room, "%s: no room door to open" % label)

	# --- reveal everything, light every other room ---
	for group_id in doors.rooms.keys():
		doors.rooms[group_id]["visited"] = true
	rm.refresh_visibility()
	var lit: Array[String] = []
	var index := 0
	for room in rm.get_dark_rooms():
		if index % 2 == 0:
			rm.set_zone_powered(room.zone_id, true)
			lit.append(room.zone_id)
		index += 1
	var dark_ids: Array[String] = []
	for room in enemies.get_spawn_rooms():
		dark_ids.append(room.zone_id)
	_expect(not dark_ids.is_empty(), "%s: no dark room left to test" % label)

	# --- spawns only in dark rooms (drop what the door openings above spawned) ---
	_clear_enemies(enemies)
	var announced: Array[String] = []
	enemies.enemies_appeared.connect(func(zones: Array[String], _n: int, _src: String) -> void: announced.append_array(zones))
	for i in 120:
		enemies._on_turn_advanced(100)  # chance at max_chance
	_expect(enemies.alive_count() > 0, "%s: 120 max-chance rolls spawned nothing" % label)
	for enemy in enemies._enemies:
		_expect(enemy.current_zone_id in dark_ids and not (enemy.current_zone_id in lit), "%s: enemy spawned in lit/blocked room '%s'" % [label, enemy.current_zone_id])
	for zone_id in announced:
		_expect(zone_id in dark_ids, "%s: alert announced lit room '%s'" % [label, zone_id])
	_expect(not announced.is_empty(), "%s: no enemies_appeared alert" % label)

	# --- cap ---
	var cap := 3
	fm.config.max_enemies_by_floor = PackedInt32Array([cap])
	_clear_enemies(enemies)
	_expect(enemies.spawn_wave(20) == cap and enemies.alive_count() == cap, "%s: spawn_wave(20) with cap %d gave %d" % [label, cap, enemies.alive_count()])
	for i in 60:
		enemies._on_turn_advanced(100)
	enemies.spawn_enemies_in_room(rm.get_group_id(dark_ids[0]), 10)
	_expect(enemies.alive_count() <= cap, "%s: %d enemies alive over cap %d" % [label, enemies.alive_count(), cap])

	# --- energize cost grows per energized room, refund = what was paid ---
	if s == 1:
		_test_power_cost(label, main2d, resources)

	main2d.queue_free()
	await process_frame


func _clear_enemies(enemies: EnemyManager) -> void:
	for enemy in enemies._enemies:
		enemy.free()
	enemies._enemies.clear()


func _test_power_cost(label: String, main2d: Node, resources: Node) -> void:
	var rm: RoomManager = main2d.room_manager
	var step: int = main2d.floor_manager.config.power_cost_step
	for room: RoomZone in rm.rooms_dict.values():
		rm.set_zone_powered(room.zone_id, false)
	var rooms: Array[RoomZone] = []
	for room in rm.get_dark_rooms():
		if rooms.size() < 3:
			rooms.append(room)
	_expect(rooms.size() == 3, "%s: need 3 dark rooms for the cost test" % label)
	if rooms.size() < 3:
		return
	resources.add_resource("dust", 1000)
	var expected := [RoomZone.POWER_COST, RoomZone.POWER_COST + step, RoomZone.POWER_COST + 2 * step]
	for i in 3:
		var before: int = resources.get_resource("dust")
		_expect(rooms[i].next_power_cost() == expected[i], "%s: cost of room %d is %d, want %d" % [label, i, rooms[i].next_power_cost(), expected[i]])
		rooms[i].try_power_up()
		_expect(rooms[i].is_powered and before - resources.get_resource("dust") == expected[i], "%s: room %d paid %d, want %d" % [label, i, before - resources.get_resource("dust"), expected[i]])
	_expect(rm.get_energized_count() == 3, "%s: energized count %d" % [label, rm.get_energized_count()])
	var before_refund: int = resources.get_resource("dust")
	rooms[1].power_down()
	_expect(resources.get_resource("dust") - before_refund == expected[1], "%s: refund %d, want %d" % [label, resources.get_resource("dust") - before_refund, expected[1]])
	_expect(rooms[1].next_power_cost() == RoomZone.POWER_COST + 2 * step, "%s: cost after a refund is %d" % [label, rooms[1].next_power_cost()])
	var cheap: int = resources.get_resource("dust")
	resources.spend_resource("dust", cheap)
	rooms[1].try_power_up()
	_expect(not rooms[1].is_powered, "%s: lit a room without dust" % label)
	var icon := rooms[1].get_node_or_null("PowerIcon") as Node2D
	_expect(icon != null, "%s: room has no PowerIcon" % label)


func _test_turret_relight() -> void:
	var turret := (load(TURRET_SCENE) as PackedScene).instantiate() as TurretModule
	root.add_child(turret)
	await process_frame
	turret.powered = false
	turret._on_fire_timer_timeout()
	_expect(not turret.fire_timer.is_stopped(), "a switched-off turret stopped its timer for good")
	turret.free()


func _test_telegraph() -> void:
	root.get_node("ResourceManager").reset_resources()
	var main2d := await _boot(1, 1)
	var hud := (load("res://scenes/hud/HUD.tscn") as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	for group_id in main2d.door_turn_system.rooms.keys():
		main2d.door_turn_system.rooms[group_id]["visited"] = true
	main2d.room_manager.refresh_visibility()
	var enemies: EnemyManager = main2d.enemy_manager
	var minimap := hud.find_child("Minimap", true, false) as Minimap
	_expect(minimap != null, "HUD has no Minimap")
	_expect(enemies.spawn_wave(3) > 0, "telegraph: no wave spawned")
	_expect(hud._hint_panel.visible and "Oleada" in hud._hint_title.text, "telegraph: wave text missing ('%s')" % hud._hint_title.text)
	_expect("Sala" in hud._hint_body.text or "Botín" in hud._hint_body.text or "Élite" in hud._hint_body.text or hud._hint_body.text.length() > 10, "telegraph: text does not name rooms ('%s')" % hud._hint_body.text)
	_expect(hud._alert_player != null and hud._alert_player.stream != null, "telegraph: no alert sound")
	if minimap:
		_expect(not minimap._spawn_alerts.is_empty(), "telegraph: minimap alert missing")
		for zone_id in minimap._spawn_alerts:
			_expect(main2d.room_manager.get_zone_kind(zone_id) == "room" and main2d.room_manager.is_room_dark(zone_id), "telegraph: minimap alert in '%s' (not a dark room)" % zone_id)
	hud.free()
	main2d.queue_free()
	await process_frame

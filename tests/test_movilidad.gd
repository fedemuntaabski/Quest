extends SceneTree

## juego-22: hero movement through the real path (NetCommands "move" / the zone click
## handler -> PlayerActionController.move_heroes -> _walk), party of 4. Complements
## test_corridor_picking (clicks), test_selection / test_party (selection), test_tactical_pause
## (an order given in pause), test_net_commands / test_net_sync (host validation, co-op).
##   - path: only revealed zones; enter_zone() fires once per crossed zone, in path order;
##     the glide passes by every zone center, never jumps; lands on the target's center
##   - refusals: unknown zone, fog, own zone = no-op (no zone change, nothing busy)
##   - speed: game time = sum(leg / (420 x move_speed_mult)) per hero; the carrier x carrier_speed_mult
##   - a second order mid-walk is refused (one order at a time per player): no double tween
##   - whole selection and control groups walk; heroes sharing a zone keep apart sprites
##   - downed: refused; revived: walks again
##   - tactical pause (time_scale 0) and menu pause (tree paused) freeze the glide, it resumes
##   - a hunter follows the party into its new zone
##   godot --headless --path . --script res://tests/test_movilidad.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const PARTY: Array[String] = ["warrior", "mage", "rogue", "tank"]
const HUGE_HP := 100000
const SCALE := 4.0
## Real-time tolerance on a measured glide (frame granularity + easing at the ends).
const SPEED_TOLERANCE := 0.08

var failures: Array[String] = []
var cmds: CoopCommands
var selection: Node
var main2d: Node
var rm: RoomManager
var pac: PlayerActionController


func _initialize() -> void:
	cmds = root.get_node("NetCommands") as CoopCommands
	selection = root.get_node("SelectionManager")
	var session := root.get_node("GameSession")
	session.set_selection(PARTY.slice(0, 2) as Array[String])
	session.recruited_ids.assign(PARTY.slice(2))
	await _boot(false)
	await _check_refusals()
	await _free()
	await _boot(true)
	_expect(main2d.heroes.size() == 4, "party of %d, want 4" % main2d.heroes.size())
	await _check_path()
	await _check_speeds()
	await _check_reorder()
	await _check_selection()
	await _check_downed()
	await _check_pauses()
	await _check_enemy_follows()
	await _free()
	(root.get_node("GameSession") as Node).clear()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_movilidad: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _boot(open_all: bool) -> void:
	var resources := root.get_node("ResourceManager") as ResourceManager
	resources.reset_resources(500, 500, 500, 500)
	seed(3)
	main2d = (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.standalone_floor = 3
	root.add_child(main2d)
	await process_frame
	rm = main2d.room_manager
	pac = main2d.player_action_controller
	if open_all:
		var progress := true
		while progress:
			progress = false
			for door in rm.get_all_doors():
				if door.is_open or door.is_secret or not rm.is_zone_revealed(door.from_zone_id):
					continue
				main2d.door_turn_system.open_room(door.target_room_id)
				door.disable_door()
				progress = true
		await process_frame
		for enemy in main2d.enemy_manager.get_enemies():
			enemy.queue_free()
		await process_frame
	_tough()


func _free() -> void:
	Engine.time_scale = 1.0
	paused = false
	main2d.queue_free()
	await process_frame
	await process_frame


func _tough() -> void:
	for hero: Player in main2d.heroes:
		hero.stats.max_hp = HUGE_HP
		if hero.stats.is_alive():
			hero.stats.current_hp = HUGE_HP


func _ids(heroes: Array) -> Array[String]:
	var out: Array[String] = []
	for hero: Player in heroes:
		out.append(hero.stats.hero_id)
	return out


func _move(heroes: Array, zone_id: String) -> String:
	cmds._rate.clear()
	return await cmds.request("move", {"heroes": _ids(heroes), "zone": zone_id})


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


## Waits (real frames) until no given hero walks; false on timeout.
func _wait_idle(heroes: Array, max_frames: int = 3000) -> bool:
	for _i in max_frames:
		if not heroes.any(func(h: Player) -> bool: return pac.is_busy(h)):
			return true
		await process_frame
		_tough()
	return false


## Farthest revealed zone (by path length) from `from`, never the exit (a carrier would win there).
func _far_zone(from: String) -> String:
	var best := ""
	var best_len := 0
	for id in rm.get_zone_ids():
		if not rm.is_zone_revealed(id) or rm.is_exit_room(id):
			continue
		var path := rm.find_zone_path(from, id)
		if path.size() > best_len:
			best_len = path.size()
			best = id
	return best


## Game seconds MoveAction should take along `path` (from the hero's spot).
func _expected_time(hero: Player, path: Array, speed: float) -> float:
	var t := 0.0
	var from := hero.global_position
	for id in path.slice(1):
		var to := rm.get_center(id)
		t += maxf(MoveAction.MIN_STEP_DURATION, from.distance_to(to) / speed)
		from = to
	return t


# ---------------- refusals (map with closed doors) ----------------

func _check_refusals() -> void:
	var hero: Player = main2d.heroes[0]
	var hidden := ""
	for id in rm.get_zone_ids():
		if not rm.is_zone_revealed(id):
			hidden = id
	var at := hero.global_position
	var zone := hero.current_zone_id
	var changes := [0]
	hero.zone_changed.connect(func(_z: String) -> void: changes[0] += 1)
	_expect(await _move([hero], "no_such_zone") == CoopCommands.INVALID, "unknown zone not refused")
	_expect(hidden != "" and await _move([hero], hidden) == "Sala sin descubrir", "fog zone not refused")
	_expect(rm.find_zone_path(zone, hidden).is_empty(), "find_zone_path crossed the fog to '%s'" % hidden)
	_expect(await _move([hero], zone) == "", "own zone refused")
	await _frames(3)
	_expect(hero.global_position == at and hero.current_zone_id == zone and changes[0] == 0 and not pac.is_busy(hero),
		"a refused / no-op move moved the hero (%s -> %s, %d zone changes)" % [at, hero.global_position, changes[0]])
	# The zone click handler (right click) on the hero's own zone: nothing either.
	selection.select_only(hero.stats.hero_id)
	await pac._on_zone_clicked(zone)
	_expect(hero.global_position == at and changes[0] == 0, "clicking the own zone moved the hero")


# ---------------- path ----------------

func _check_path() -> void:
	var hero: Player = main2d.heroes[0]
	var start := hero.current_zone_id
	var target := _far_zone(start)
	var path := rm.find_zone_path(start, target)
	_expect(path.size() >= 4, "test map too small: path %s" % [path])
	for id in path:
		_expect(rm.is_zone_revealed(id), "path crosses unrevealed '%s'" % id)
	var entered: Array[String] = []
	var record := func(z: String) -> void: entered.append(z)
	hero.zone_changed.connect(record)
	var speed := MoveAction.DEFAULT_SPEED_PX * hero.move_speed_mult()
	Engine.time_scale = SCALE
	_move([hero], target)  # not awaited: sampled frame by frame
	var samples: Array[Vector2] = [hero.global_position]
	var max_jump := 0.0
	var prev_dt := 0.0
	for _i in 3000:
		await process_frame
		# Game delta (time_scale applied). process_frame fires before the tweens step,
		# so a sample can hold the previous frame's motion: take the larger of the two.
		var cur_dt := main2d.get_process_delta_time()
		var dt := maxf(cur_dt, prev_dt)
		prev_dt = cur_dt
		var jump := hero.global_position.distance_to(samples[-1])
		# Sine easing peaks at pi/2 x the mean speed; 2x + 4 px covers frame jitter.
		if jump > 2.0 * speed * dt + 4.0:
			max_jump = maxf(max_jump, jump)
		samples.append(hero.global_position)
		if not pac.is_busy(hero):
			break
	Engine.time_scale = 1.0
	hero.zone_changed.disconnect(record)
	_expect(entered == path.slice(1), "zones entered %s, want %s" % [entered, path.slice(1)])
	_expect(max_jump == 0.0, "the hero jumped %.0f px in one frame" % max_jump)
	_expect(hero.current_zone_id == target and hero.global_position == rm.get_center(target), "landed on '%s' at %s (center %s)" % [hero.current_zone_id, hero.global_position, rm.get_center(target)])
	for id in path.slice(1):
		var best := INF
		for p in samples:
			best = minf(best, p.distance_to(rm.get_center(id)))
		_expect(best < 12.0, "the glide passed %.0f px from the center of '%s'" % [best, id])
	await _move([hero], start)  # back with the others


# ---------------- speed ----------------

func _measure(hero: Player, target: String) -> float:
	Engine.time_scale = SCALE
	var t0 := Time.get_ticks_usec()
	await _move([hero], target)
	var game := (Time.get_ticks_usec() - t0) / 1000000.0 * SCALE
	Engine.time_scale = 1.0
	return game


func _check_speeds() -> void:
	var start: String = main2d.heroes[0].current_zone_id
	var target := _far_zone(start)
	var path := rm.find_zone_path(start, target)
	var carrier_mult: float = main2d.floor_manager.carrier_speed_mult()
	for hero: Player in main2d.heroes:
		for carrying in [false, true]:
			if carrying and hero != main2d.heroes[0]:
				continue
			hero.is_carrying_relic = carrying
			var speed := MoveAction.DEFAULT_SPEED_PX * hero.move_speed_mult() * (carrier_mult if carrying else 1.0)
			var want := _expected_time(hero, path, speed)
			var got := await _measure(hero, target)
			_expect(absf(got - want) <= want * SPEED_TOLERANCE + 0.1,
				"%s%s: %.2f s of game time, want %.2f (x%.2f)" % [hero.stats.hero_id, " carrying" if carrying else "", got, want, speed / MoveAction.DEFAULT_SPEED_PX])
			hero.is_carrying_relic = false
			Engine.time_scale = SCALE
			await _move([hero], start)
			Engine.time_scale = 1.0
	_expect(main2d.heroes.all(func(h: Player) -> bool: return h.current_zone_id == start), "speed walks did not come back to '%s'" % start)


# ---------------- re-order ----------------

func _check_reorder() -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var start := a.current_zone_id
	var target := _far_zone(start)
	var other := rm.find_zone_path(start, target)[1]
	Engine.time_scale = SCALE
	_move([a], target)
	await _frames(4)
	_expect(pac.is_busy(a), "the first order is not walking")
	var before := a.global_position
	var tweens := get_processed_tweens().size()
	_expect(await _move([a], other) == "Ya hay una orden en curso", "a second order mid-walk was not refused")
	_expect(await _move([b], other) == "Ya hay una orden en curso", "the same player's second hero took an order mid-walk")
	_expect(a.global_position.distance_to(before) < MoveAction.DEFAULT_SPEED_PX, "the refused order teleported the hero")
	_expect(get_processed_tweens().size() <= tweens, "the refused orders added tweens (%d -> %d)" % [tweens, get_processed_tweens().size()])
	await _wait_idle([a])
	Engine.time_scale = 1.0
	_expect(a.current_zone_id == target, "the first order ended at '%s', want '%s'" % [a.current_zone_id, target])
	await _move([a], start)


# ---------------- selection / groups / sprites ----------------

func _check_selection() -> void:
	var heroes: Array = main2d.heroes
	var start: String = heroes[0].current_zone_id
	var target := _far_zone(start)
	selection.set_selection(_ids(heroes))
	Engine.time_scale = SCALE
	await pac._on_zone_clicked(target)
	await _wait_idle(heroes)
	_expect(heroes.all(func(h: Player) -> bool: return h.current_zone_id == target), "not every selected hero reached '%s': %s" % [target, heroes.map(func(h: Player) -> String: return h.current_zone_id)])
	for i in heroes.size():
		for j in range(i + 1, heroes.size()):
			var gap: float = heroes[i].animated_sprite.global_position.distance_to(heroes[j].animated_sprite.global_position)
			_expect(gap >= 20.0, "heroes %d and %d stand %.0f px apart in '%s'" % [i, j, gap, target])
	# Control group 1 = heroes 2 and 3: only they walk back.
	selection.set_selection(_ids([heroes[2], heroes[3]]))
	selection.assign_group(1)
	selection.select_only(heroes[0].stats.hero_id)
	_expect(selection.select_group(1) and selection.get_selected_ids() == _ids([heroes[2], heroes[3]]), "group 1 recalled %s" % [selection.get_selected_ids()])
	await pac._on_zone_clicked(start)
	await _wait_idle(heroes)
	_expect(heroes[2].current_zone_id == start and heroes[3].current_zone_id == start and heroes[0].current_zone_id == target and heroes[1].current_zone_id == target,
		"group 1 order moved %s" % [heroes.map(func(h: Player) -> String: return h.current_zone_id)])
	selection.set_selection(_ids([heroes[0], heroes[1]]))
	await pac._on_zone_clicked(start)
	await _wait_idle(heroes)
	Engine.time_scale = 1.0
	selection.set_selection(_ids(heroes))


# ---------------- downed ----------------

func _check_downed() -> void:
	var hero: Player = main2d.heroes[1]
	var start := hero.current_zone_id
	var target := _far_zone(start)
	hero.stats.max_hp = 50
	hero.stats.current_hp = 50
	hero.take_hit(1000)
	_expect(hero.is_downed(), "take_hit did not down the hero")
	var at := hero.global_position
	_expect(await _move([hero], target) == "Ningún héroe puede moverse", "a downed hero took a move order")
	await _frames(3)
	_expect(hero.global_position == at, "the downed hero moved")
	_expect(root.get_node("PlayerStats").revive_hero(hero.stats.hero_id), "revive refused (an ally shares the room)")
	_tough()
	Engine.time_scale = SCALE
	_expect(await _move([hero], target) == "" and hero.current_zone_id == target, "the revived hero did not walk (at '%s')" % hero.current_zone_id)
	await _move([hero], start)
	Engine.time_scale = 1.0


# ---------------- pauses ----------------

func _check_pauses() -> void:
	var hero: Player = main2d.heroes[0]
	var start := hero.current_zone_id
	var target := _far_zone(start)
	for mode in ["tactical", "menu"]:
		Engine.time_scale = SCALE
		_move([hero], target)
		await _frames(6)
		if mode == "tactical":
			Engine.time_scale = 0.0
		else:
			paused = true
		await _frames(2)
		var frozen := hero.global_position
		await _frames(20)
		_expect(hero.global_position == frozen and pac.is_busy(hero), "%s pause: the glide went on (%s -> %s)" % [mode, frozen, hero.global_position])
		Engine.time_scale = SCALE
		paused = false
		_expect(await _wait_idle([hero]) and hero.current_zone_id == target, "%s pause: did not resume to '%s' (at '%s')" % [mode, target, hero.current_zone_id])
		await _move([hero], start)
		Engine.time_scale = 1.0


# ---------------- enemies ----------------

func _check_enemy_follows() -> void:
	var heroes: Array = main2d.heroes
	var start: String = heroes[0].current_zone_id
	var far := _far_zone(start)
	var enemies: EnemyManager = main2d.enemy_manager
	var type: EnemyType = main2d.floor_manager.roll_enemy_type(EnemyType.Role.HUNTER)
	var enemy := enemies._spawn_enemy(far, rm.get_center(far), type, true)
	if enemy == null:
		failures.append("could not spawn a hunter in '%s'" % far)
		return
	enemy.max_hp = HUGE_HP
	enemy.current_hp = HUGE_HP
	Engine.time_scale = SCALE
	var reached := false
	for _i in 4000:
		await process_frame
		_tough()
		if not is_instance_valid(enemy):
			break
		enemy.current_hp = HUGE_HP
		if enemy.current_zone_id == start:
			reached = true
			break
	_expect(reached, "the hunter never reached the party in '%s' (at '%s')" % [start, enemy.current_zone_id if is_instance_valid(enemy) else "freed"])
	# The party leaves: the hunter follows into the new zone.
	var dest := rm.find_zone_path(start, far)[2] if rm.find_zone_path(start, far).size() > 2 else far
	selection.set_selection(_ids(heroes))
	await pac._on_zone_clicked(dest)
	await _wait_idle(heroes)
	var followed := false
	for _i in 4000:
		await process_frame
		_tough()
		if not is_instance_valid(enemy):
			break
		enemy.current_hp = HUGE_HP
		if enemy.current_zone_id == dest:
			followed = true
			break
	Engine.time_scale = 1.0
	_expect(followed, "the hunter did not follow the party into '%s' (at '%s')" % [dest, enemy.current_zone_id if is_instance_valid(enemy) else "freed"])

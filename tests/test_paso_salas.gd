extends SceneTree

## juego-35: "a veces el clic derecho no mueve al héroe a ninguna sala". Barrido de
## N semillas x 5 pisos sobre el Main2d real, con operaciones al azar (RNG propio, el
## global queda intacto): abrir puertas caminando hasta ellas, prender/apagar salas,
## pausa táctica a mitad de camino y orden dada en pausa, pausa de menú (árbol en
## pausa), héroe que cae a mitad de camino y se revive, reclutar, cambiar la selección.
## Tras cada paso:
##   - ningún héroe ni jugador queda "ocupado" (PlayerActionController._busy/_busy_peers)
##   - cada héroe vivo está en una zona revelada y tiene camino a cada zona revelada
##   - un clic derecho real (Input -> picking -> RoomZone) lleva a la selección a una zona
##     al azar; varias órdenes a mitad de camino: gana la última (juego-35)
## Las órdenes no se esperan con await: un cuelgue sale por timeout, no traba el test.
##   godot --headless --path . --script res://tests/test_paso_salas.gd [-- --seeds=N --steps=M]  (suite: 1 x 8)

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"
const HEROES: Array[String] = ["warrior", "mage", "rogue", "tank"]
const HUGE_HP := 100000
const SPEED := 8.0
## Frames reales de espera por orden a SPEED x antes de declararla colgada.
const IDLE_FRAMES := 2400
const OPS: Array[String] = ["door", "door", "walk", "light", "pause_walk", "order_in_pause",
	"menu_pause_walk", "down_mid_walk", "down_idle", "recruit", "select", "door_while_walking", "redirect"]

var seeds := 1
var steps := 8
var failures: Array[String] = []
var cmds: CoopCommands
var selection: Node
var ps: Node
var resources: ResourceManager
var main2d: Node
var hud: HUDController
var clicked_zone := ""
var rm: RoomManager
var pac: PlayerActionController
var rng := RandomNumberGenerator.new()
var label := ""
var last_refusal := ""
var steps_run := 0
var walks_checked := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
		elif arg.begins_with("--steps="):
			steps = int(arg.get_slice("=", 1))
	cmds = root.get_node("NetCommands") as CoopCommands
	selection = root.get_node("SelectionManager")
	ps = root.get_node("PlayerStats")
	resources = root.get_node("ResourceManager") as ResourceManager
	cmds.refused.connect(func(cmd: String, reason: String) -> void: last_refusal = "%s: %s" % [cmd, reason])
	var session := root.get_node("GameSession")
	for s in seeds:
		for f in range(1, 6):
			session.set_selection(HEROES.slice(0, 2) as Array[String])
			session.recruited_ids.clear()
			rng.seed = hash([s, f, "paso_salas"])
			label = "seed %d floor %d" % [s, f]
			await _boot(s, f)
			var ok := await _check_after("boot")
			for _i in steps:
				if not ok:
					break
				resources.reset_resources(500, 500, 500, 500)
				var op: String = OPS[rng.randi() % OPS.size()]
				var what: String = await call("_op_" + op)
				steps_run += 1
				ok = await _check_after(what)
			print("test_paso_salas: %s done at %d ms, frame %d" % [label, Time.get_ticks_msec(), Engine.get_process_frames()])
			await _free()
	session.clear()
	print("test_paso_salas: %d seeds x 5 floors, %d steps, %d real walks checked" % [seeds, steps_run, walks_checked])
	for failure in failures.slice(0, 40):
		printerr("FAIL: ", failure)
	var ok_all := failures.is_empty() and walks_checked > seeds * 5
	print("test_paso_salas: %s (%d failures)" % ["OK" if ok_all else "FAILED", failures.size()])
	quit(0 if ok_all else 1)


func _fail(what: String) -> void:
	failures.append("%s: %s" % [label, what])


# ─── floor ───────────────────────────────────────────────────

func _boot(s: int, f: int) -> void:
	resources.reset_resources(500, 500, 500, 500)
	resources.reset_research()
	seed(s)
	main2d = (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.standalone_floor = f
	root.add_child(main2d)
	await process_frame
	hud = (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	var camera: GameCamera = main2d.camera
	camera.config = camera.config.duplicate()
	camera.config.edge_scroll_enabled = false
	rm = main2d.room_manager
	pac = main2d.player_action_controller
	rm.zone_clicked.connect(func(zone_id: String) -> void: clicked_zone = zone_id)
	_tough()
	Engine.time_scale = SPEED


func _free() -> void:
	Engine.time_scale = 1.0
	paused = false
	main2d.queue_free()
	hud.queue_free()
	await process_frame
	await process_frame


## Enemies keep hitting; only the downs this test asks for drop a hero.
func _tough() -> void:
	for hero: Player in main2d.heroes:
		hero.stats.max_hp = HUGE_HP
		if hero.stats.is_alive():
			hero.stats.current_hp = HUGE_HP


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
		_tough()


func _idle() -> bool:
	return pac._busy.is_empty() and pac._busy_peers.is_empty()


func _wait_idle() -> bool:
	for _i in IDLE_FRAMES:
		if _idle():
			return true
		await process_frame
		_tough()
	return _idle()


func _live() -> Array[Player]:
	var out: Array[Player] = []
	for hero: Player in main2d.heroes:
		if hero.can_accept_input():
			out.append(hero)
	return out


func _ids(heroes: Array) -> Array[String]:
	var out: Array[String] = []
	for hero: Player in heroes:
		out.append(hero.stats.hero_id)
	return out


func _selected() -> Array[Player]:
	var out: Array[Player] = []
	for hero in _live():
		if selection.is_selected(hero.stats.hero_id):
			out.append(hero)
	return out


func _revealed_zones() -> Array[String]:
	var out: Array[String] = []
	for id in rm.get_zone_ids():
		if rm.is_zone_revealed(id):
			out.append(id)
	return out


func _pick(items: Array) -> Variant:
	return items[rng.randi() % items.size()] if not items.is_empty() else null


func _pick_id(items: Array) -> String:
	return _pick(items) if not items.is_empty() else ""


## Fires a command without waiting for its walk ("" = taken, else the refusal).
func _fire(cmd: String, args: Dictionary) -> String:
	cmds._rate.clear()
	last_refusal = ""
	cmds.request(cmd, args)
	return last_refusal


func _move(heroes: Array, zone_id: String) -> String:
	return _fire("move", {"heroes": _ids(heroes), "zone": zone_id})


func _far_zone(from: String) -> String:
	var best := ""
	var best_len := 0
	for id in _revealed_zones():
		var n := rm.find_zone_path(from, id).size()
		if n > best_len and not rm.is_exit_room(id):
			best_len = n
			best = id
	return best


# ─── operations (each returns what it did) ───────────────────

func _openable_doors() -> Array:
	return rm.get_all_doors().filter(func(d: Door) -> bool:
		return not d.is_open and not d.is_secret and rm.is_zone_revealed(d.from_zone_id) and not rm.is_group_revealed(d.target_room_id))


func _op_door() -> String:
	var door: Door = _pick(_openable_doors())
	var party := _selected()
	if door == null or party.is_empty():
		return "door (none)"
	_move(party, door.from_zone_id)
	if not await _wait_idle():
		return "door: walk to '%s'" % door.from_zone_id
	var reason := _fire("open_door", {"door": door.door_id, "heroes": _ids(_selected())})
	return "door '%s' -> '%s' %s" % [door.door_id, door.target_room_id, reason]


func _op_door_while_walking() -> String:
	var live := _live()
	if live.size() < 2:
		return await _op_door()
	var walker: Player = live[0]
	_move([walker], _far_zone(walker.current_zone_id))
	await _frames(rng.randi_range(1, 6))
	selection.set_selection(_ids(live.slice(1)))
	var what := await _op_door()
	return "door while %s walks / %s" % [walker.stats.hero_id, what]


func _op_walk() -> String:
	var zone: String = _pick_id(_revealed_zones())
	return "walk to '%s' %s" % [zone, _move(_selected(), zone)]


## juego-35: orders given mid-walk replace the walk; the last one wins.
func _op_redirect() -> String:
	var party := _selected()
	var last := ""
	for _i in rng.randi_range(2, 4):
		last = _pick_id(_revealed_zones())
		_move(party, last)
		await _frames(rng.randi_range(1, 10))
	if not await _wait_idle():
		return "redirect: stuck"
	for hero in party:
		if hero.can_accept_input() and hero.current_zone_id != last:
			_fail("redirect: %s ended at '%s', the last order was '%s'" % [hero.stats.hero_id, hero.current_zone_id, last])
	return "redirect x%d, last '%s'" % [party.size(), last]


func _op_light() -> String:
	var rooms := _revealed_zones().filter(func(id: String) -> bool: return rm.get_zone_kind(id) == "room")
	var zone: String = _pick_id(rooms)
	return "light '%s' %s" % [zone, _fire("toggle_light", {"zone": zone})]


func _op_pause_walk() -> String:
	var party := _selected()
	var zone := _far_zone(party[0].current_zone_id) if not party.is_empty() else ""
	_move(party, zone)
	await _frames(rng.randi_range(1, 12))
	main2d.pause_controller.toggle()
	await _frames(20)
	var second := _move(party, _pick_id(_revealed_zones()))
	main2d.pause_controller.toggle()
	return "pause mid-walk to '%s' (2nd order: %s)" % [zone, second]


func _op_order_in_pause() -> String:
	main2d.pause_controller.toggle()
	var zone: String = _pick_id(_revealed_zones())
	var reason := _move(_selected(), zone)
	await _frames(rng.randi_range(2, 30))
	main2d.pause_controller.toggle()
	return "order in pause to '%s' %s" % [zone, reason]


func _op_menu_pause_walk() -> String:
	var party := _selected()
	var zone := _far_zone(party[0].current_zone_id) if not party.is_empty() else ""
	_move(party, zone)
	await _frames(rng.randi_range(1, 12))
	main2d.game_state_manager.request_pause()
	paused = true
	await _frames(15)
	paused = false
	main2d.game_state_manager.request_resume()
	return "menu pause mid-walk to '%s'" % zone


func _down(hero: Player) -> void:
	hero.stats.take_damage(hero.stats.current_hp)


func _revive_all() -> String:
	var done := []
	for hero: Player in main2d.heroes:
		if hero.can_accept_input():
			continue
		var ally: Player = _pick(_live())
		if ally == null:
			break
		_move([ally], hero.current_zone_id)
		if not await _wait_idle():
			return "revive: walk stuck"
		var reason := _fire("revive", {"hero": hero.stats.hero_id})
		done.append("%s %s" % [hero.stats.hero_id, reason])
	return "revive %s" % [done]


func _op_down_mid_walk() -> String:
	var live := _live()
	if live.size() < 2:
		return "down mid-walk (alone)"
	selection.set_selection(_ids(live))
	_move(live, _far_zone(live[0].current_zone_id))
	await _frames(rng.randi_range(2, 20))
	var victim: Player = live[rng.randi() % (live.size() - 1) + 1]
	_down(victim)
	if not await _wait_idle():
		return "down mid-walk (%s): stuck before the revive" % victim.stats.hero_id
	var what := "down mid-walk %s at '%s'" % [victim.stats.hero_id, victim.current_zone_id]
	if rng.randf() < 0.7:
		what += " / " + await _revive_all()
	return what


func _op_down_idle() -> String:
	var live := _live()
	if live.size() < 2:
		return "down idle (alone)"
	var victim: Player = live[-1]
	_down(victim)
	await _frames(3)
	return "down idle %s / %s" % [victim.stats.hero_id, await _revive_all()]


func _op_recruit() -> String:
	if main2d.heroes.size() >= 4:
		return "recruit (party full)"
	var free := HEROES.filter(func(id: String) -> bool: return main2d.heroes.all(func(h: Player) -> bool: return h.stats.hero_id != id))
	var zone: String = _pick_id(_revealed_zones().filter(func(id: String) -> bool: return rm.get_zone_kind(id) == "room"))
	var hero: Player = main2d.recruit_hero(free[0], zone)
	_tough()
	return "recruit %s in '%s' %s" % [free[0], zone, "ok" if hero else "refused"]


func _op_select() -> String:
	var live := _live()
	if rng.randf() < 0.5:
		selection.set_selection(_ids(live))
		return "select all"
	var hero: Player = _pick(live)
	selection.select_only(hero.stats.hero_id)
	return "select %s" % hero.stats.hero_id


# ─── the check ───────────────────────────────────────────────

func _areas_at(point: Vector2) -> Array:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return main2d.get_world_2d().direct_space_state.intersect_point(query, 16).map(func(hit: Dictionary) -> String:
		var c: Object = hit["collider"]
		return "%s(%s pickable=%s)" % [c.get_class(), (c as Node).name, (c as CollisionObject2D).input_pickable])


## A real right click (press + release through Input) on the zone's centre, the camera
## brought over it first. true when RoomManager.zone_clicked named that zone.
func _right_click(zone_id: String) -> bool:
	var world := rm.get_center(zone_id)
	var view := main2d.get_viewport()
	# Centred, and only once the camera stopped gliding: picking runs a frame later.
	main2d.camera.focus_on(world)
	main2d.camera.reset_smoothing()
	var screen := view.get_canvas_transform() * world
	for _i in 240:
		await process_frame
		var now := view.get_canvas_transform() * world
		var still := now.distance_to(screen) < 0.25
		screen = now
		if still and view.get_visible_rect().grow(-40.0).has_point(screen):
			break
	clicked_zone = ""
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	root.push_input(motion, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_RIGHT
		ev.pressed = pressed
		ev.position = screen
		ev.global_position = screen
		root.push_input(ev, true)
		await physics_frame
		await process_frame
	return clicked_zone == zone_id

func _busy_text() -> String:
	return "busy peers %s, busy heroes %s, time_scale %.1f, paused %s, state %s" % [pac._busy_peers.keys(),
		pac._busy.keys().map(func(h: Player) -> String: return "%s@%s" % [h.stats.hero_id, h.current_zone_id]),
		Engine.time_scale, paused, GameStateManager.State.keys()[main2d.game_state_manager.current_state]]


func _check_after(what: String) -> bool:
	if not await _wait_idle():
		_fail("STUCK after [%s]: %s" % [what, _busy_text()])
		return false
	var gsm: GameStateManager = main2d.game_state_manager
	if not gsm.is_active():
		_fail("after [%s] the floor is %s" % [what, GameStateManager.State.keys()[gsm.current_state]])
		return false
	var zones := _revealed_zones()
	for hero in _live():
		if not rm.is_zone_revealed(hero.current_zone_id):
			_fail("after [%s] %s stands in unrevealed '%s'" % [what, hero.stats.hero_id, hero.current_zone_id])
			return false
		for id in zones:
			if rm.find_zone_path(hero.current_zone_id, id).is_empty():
				_fail("after [%s] no path %s '%s' -> '%s'" % [what, hero.stats.hero_id, hero.current_zone_id, id])
				return false
	# The real right click: the handler RoomZone.clicked reaches.
	var party := _selected()
	if party.is_empty():
		_fail("after [%s] nobody selected (selection %s, live %s)" % [what, selection.get_selected_ids(), _ids(_live())])
		return false
	var target: String = _pick_id(zones.filter(func(id: String) -> bool: return id != party[0].current_zone_id))
	if target == "":
		return true
	if not pac._can_act():
		_fail("after [%s] a right click is refused (_can_act false): %s" % [what, _busy_text()])
		return false
	last_refusal = ""
	cmds._rate.clear()
	if not await _right_click(target):
		_fail("after [%s] a right click on '%s' never reached its RoomZone (got '%s'; GUI under the mouse: %s; areas there: %s; picking %s)" % [what, target, clicked_zone, root.gui_get_hovered_control(), _areas_at(rm.get_center(target)), root.physics_object_picking])
		return false
	if not await _wait_idle():
		_fail("STUCK walking to '%s' after [%s]: %s" % [target, what, _busy_text()])
		return false
	for hero in party:
		if hero.can_accept_input() and hero.current_zone_id != target:
			_fail("after [%s] %s ended at '%s', clicked '%s' (%s)" % [what, hero.stats.hero_id, hero.current_zone_id, target, last_refusal])
			return false
	walks_checked += 1
	return true

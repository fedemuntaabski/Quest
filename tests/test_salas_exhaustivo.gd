extends SceneTree

## juego-22: salas, lo que no cubrían test_map_generator / test_map_flow / test_rooms /
## test_progresion_rooms / test_build_costs / test_estabilizar:
##   - 200 semillas x pisos 1-5: el árbol (sin loops) une todas las salas no secretas,
##     tiene salas - 1 corredores, y cada loop une dos salas ya unidas por el árbol
##   - Main2d real en mapas elegidos para ver los 10 RoomType: cada grupo se revela una
##     sola vez (room_revealed), reabrir / revelar de nuevo no paga nada, un loop no da
##     brasas de sala ni cartel
##   - luz: LIGHT_COST + light_cost_step por sala encendida, apagar devuelve lo pagado,
##     la inicial es gratis, sin brasas se rechaza sin gastar (también por NetCommands)
##   - obras por NetCommands en cada hueco de una sala: construir, ocupado, reparar,
##     demoler; is_working sigue requires_light; los Talleres pagan solo al pasar turno
##   - extracción: las puertas se rechazan por NetCommands; un héroe sin la Reliquia que
##     entra a la salida no gana
##   godot --headless --path . --script res://tests/test_salas_exhaustivo.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const FLOOR_CONFIG_PATH := "res://resources/floors/default_floor_config.tres"
const SEEDS := 200
const FLOORS := 5
const HUGE_HP := 100000

var failures: Array[String] = []
var resources: ResourceManager
var cmds: CoopCommands


func _initialize() -> void:
	resources = root.get_node("ResourceManager") as ResourceManager
	cmds = root.get_node("NetCommands") as CoopCommands
	var config := load(FLOOR_CONFIG_PATH) as FloorConfig
	_check_trees(config)
	var types_seen: Dictionary = {}
	for pick in _pick_maps(config):
		var main2d := await _boot(pick[0], pick[1])
		await _sweep(main2d, "seed %d floor %d" % pick, types_seen)
		await _free(main2d)
	for type in RoomData.RoomType.values():
		if not types_seen.has(type):
			failures.append("sweep never revealed a %s room" % RoomData.RoomType.find_key(type))

	var main2d := await _boot(0, 1)
	_open_all(main2d)
	await process_frame
	await _check_lighting(main2d)
	await _check_buildings(main2d)
	await _free(main2d)
	for n in range(1, 20):
		main2d = await _boot(n, 2)
		var tried := await _check_extraction(main2d)
		await _free(main2d)
		if tried:
			break
		if n == 19:
			failures.append("extraction: no map < 20 keeps a closed door after finding the exit")

	for failure in failures.slice(0, 30):
		printerr("FAIL: ", failure)
	print("test_salas_exhaustivo: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


# ---------------- generación ----------------

func _check_trees(config: FloorConfig) -> void:
	for f in range(1, FLOORS + 1):
		for s in SEEDS:
			var layout := MapGenerator.generate_floor(s * 7919 + f, config, f)
			var where := "floor %d seed %d" % [f, s]
			var rooms: Array[String] = []
			for room in layout.rooms:
				if room.get_room_type() != RoomData.RoomType.SECRET:
					rooms.append(room.id)
			var tree := layout.corridors.filter(func(c: CorridorData) -> bool: return not c.is_loop and not c.is_secret)
			_expect(tree.size() == rooms.size() - 1, "%s: %d tree corridors for %d rooms" % [where, tree.size(), rooms.size()])
			var reached := _reach(layout.get_start_room_id(), tree)
			_expect(reached.size() == rooms.size(), "%s: the tree reaches %d of %d rooms" % [where, reached.size(), rooms.size()])
			_expect(layout.get_start_room_id() != "" and layout.get_start_room_id() != _exit_id(layout), "%s: start == exit" % where)
			for c in layout.corridors:
				if c.is_loop and not c.is_secret:
					_expect(reached.has(c.room_a) and reached.has(c.room_b), "%s: loop '%s' joins a room outside the tree" % [where, c.id])


func _reach(from: String, corridors: Array) -> Dictionary:
	var seen := {from: true}
	var frontier := [from]
	while not frontier.is_empty():
		var at: String = frontier.pop_back()
		for c: CorridorData in corridors:
			var other := c.room_b if c.room_a == at else (c.room_a if c.room_b == at else "")
			if other != "" and not seen.has(other):
				seen[other] = true
				frontier.append(other)
	return seen


func _exit_id(layout: MapLayout) -> String:
	for room in layout.rooms:
		if room.is_exit:
			return room.id
	return ""


## [seed, floor] pairs: floors 1-5 of seed 0, plus the first map that has each room type
## (same randi() -> hash([run_seed, floor]) path a standalone Main2d uses).
func _pick_maps(config: FloorConfig) -> Array:
	var picks: Array = [[0, 1], [0, 2], [0, 3], [0, 4], [0, 5]]
	var wanted := RoomData.RoomType.values()
	for n in 400:
		for f in range(1, FLOORS + 1):
			seed(n)
			var layout := MapGenerator.generate_floor(hash([randi(), f]), config, f)
			var adds := false
			for room in layout.rooms:
				if wanted.has(room.get_room_type()):
					wanted.erase(room.get_room_type())
					adds = true
			if adds and not picks.has([n, f]):
				picks.append([n, f])
		if wanted.is_empty():
			break
	return picks


# ---------------- Main2d ----------------

func _boot(n: int, f: int) -> Node:
	resources.reset_resources(500, 500, 500, 500)
	resources.reset_research()
	seed(n)
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.standalone_floor = f
	root.add_child(main2d)
	await process_frame
	_tough(main2d)
	return main2d


func _free(main2d: Node) -> void:
	Engine.time_scale = 1.0
	paused = false
	main2d.queue_free()
	await process_frame
	await process_frame


func _tough(main2d: Node) -> void:
	for hero: Player in main2d.heroes:
		hero.stats.max_hp = HUGE_HP
		hero.stats.current_hp = HUGE_HP


func _request(cmd: String, args: Dictionary) -> String:
	cmds._rate.clear()
	return await cmds.request(cmd, args)


func _snapshot() -> Array:
	return ResourceManager.KEYS.map(func(k: String) -> int: return resources.get_resource(k))


## Opens every clickable door in reveal order (no walking); returns how many.
func _open_all(main2d: Node) -> int:
	var rm: RoomManager = main2d.room_manager
	var opened := 0
	var progress := true
	while progress:
		progress = false
		for door in rm.get_all_doors():
			if door.is_open or door.is_secret or not rm.is_zone_revealed(door.from_zone_id):
				continue
			main2d.door_turn_system.open_room(door.target_room_id)
			door.disable_door()
			opened += 1
			progress = true
	return opened


func _sweep(main2d: Node, label: String, types_seen: Dictionary) -> void:
	var rm: RoomManager = main2d.room_manager
	var doors: DoorTurnSystem = main2d.door_turn_system
	var fm: FloorManager = main2d.floor_manager
	var revealed: Dictionary = {}
	doors.room_revealed.connect(func(id: String, _cells: Array[Vector2i]) -> void: revealed[id] = int(revealed.get(id, 0)) + 1)
	var banners := _banner_texts(rm)
	var progress := true
	while progress:
		progress = false
		for door in rm.get_all_doors():
			if door.is_open or door.is_secret or not rm.is_zone_revealed(door.from_zone_id):
				continue
			var group := door.target_room_id
			var loop := rm.get_zone_kind(group) == "corridor"
			var embers_before := resources.get_resource("embers")
			var banners_before := _count_texts(banners)
			_expect(doors.open_room(group), "%s: open_room('%s') refused" % [label, group])
			door.disable_door()
			progress = true
			if loop:
				var bonus: Dictionary = fm.door_bonus(group)
				var want: int = (bonus["amount"] if bonus["key"] == "embers" else 0) + resources.get_turn_yield("embers")
				_expect(resources.get_resource("embers") - embers_before == want, "%s: loop '%s' gave %d embers, want %d" % [label, group, resources.get_resource("embers") - embers_before, want])
				_expect(_count_texts(banners) == banners_before, "%s: loop '%s' showed a room banner" % [label, group])
			else:
				types_seen[rm.get_room_type(group)] = true
			var after := _snapshot()
			_expect(not doors.open_room(group) and not doors.reveal_room(group), "%s: '%s' opened twice" % [label, group])
			_expect(_snapshot() == after, "%s: reopening '%s' paid %s -> %s" % [label, group, after, _snapshot()])
	await process_frame
	for group in rm.get_group_ids():
		if rm.get_zone_kind(group) == "room" and rm.is_group_revealed(group):
			types_seen[rm.get_room_type(group)] = true
		if group == rm.get_group_id(rm.get_start_zone_id()):
			continue
		_expect(rm.is_group_revealed(group), "%s: group '%s' never revealed" % [label, group])
		_expect(int(revealed.get(group, 0)) == 1, "%s: group '%s' revealed %d times" % [label, group, int(revealed.get(group, 0))])


func _banner_texts(rm: RoomManager) -> Array[String]:
	var out: Array[String] = []
	for type in RoomData.RoomType.values():
		var visual := rm.visual_config.room_type_visual(type)
		if visual and visual.banner_text != "":
			out.append(visual.banner_text)
	return out


func _count_texts(texts: Array[String]) -> int:
	var count := 0
	for manager in get_nodes_in_group("floating_text_manager"):
		for child in manager.get_children():
			if child is FloatingText and (child as FloatingText).label.text in texts:
				count += 1
	return count


# ---------------- luz ----------------

func _dark_rooms(main2d: Node, count: int) -> Array[RoomZone]:
	var rm: RoomManager = main2d.room_manager
	var out: Array[RoomZone] = []
	for id in rm.get_zone_ids():
		var zone := rm.get_zone_node(id)
		if zone.kind == "room" and rm.is_zone_revealed(id) and not zone.is_lit and out.size() < count:
			out.append(zone)
	return out


func _check_lighting(main2d: Node) -> void:
	var rm: RoomManager = main2d.room_manager
	var start := rm.get_zone_node(rm.get_start_zone_id())
	_expect(start.is_lit and start.get_light_paid() == 0 and rm.get_lit_count() == 0, "start room not lit for free (paid %d, lit count %d)" % [start.get_light_paid(), rm.get_lit_count()])
	var rooms := _dark_rooms(main2d, 3)
	if rooms.size() < 3:
		failures.append("lighting: only %d dark rooms to test" % rooms.size())
		return
	var step: int = main2d.floor_manager.config.light_cost_step
	var e0 := resources.get_resource("embers")
	var paid := 0
	for i in 3:
		var cost := RoomZone.LIGHT_COST + step * i
		_expect(rooms[i].next_light_cost() == cost, "room %d costs %d, want %d" % [i, rooms[i].next_light_cost(), cost])
		_expect(await _request("toggle_light", {"zone": rooms[i].zone_id}) == "", "toggle_light %d refused" % i)
		paid += cost
		_expect(rooms[i].is_lit and rooms[i].get_light_paid() == cost and resources.get_resource("embers") == e0 - paid, "lighting room %d: paid %d, embers %d (want %d)" % [i, rooms[i].get_light_paid(), resources.get_resource("embers"), e0 - paid])
	# Off then on again: the refund is what was paid, the new price follows the count.
	await _request("toggle_light", {"zone": rooms[0].zone_id})
	paid -= RoomZone.LIGHT_COST
	_expect(not rooms[0].is_lit and resources.get_resource("embers") == e0 - paid, "switching off refunded %d, want %d" % [resources.get_resource("embers") - (e0 - paid - RoomZone.LIGHT_COST), RoomZone.LIGHT_COST])
	var relight := RoomZone.LIGHT_COST + step * 2
	await _request("toggle_light", {"zone": rooms[0].zone_id})
	paid += relight
	_expect(rooms[0].get_light_paid() == relight and resources.get_resource("embers") == e0 - paid, "relighting paid %d, want %d" % [rooms[0].get_light_paid(), relight])
	for zone in rooms:
		await _request("toggle_light", {"zone": zone.zone_id})
	_expect(resources.get_resource("embers") == e0 and rm.get_lit_count() == 0, "all off: embers %d (want %d), lit count %d" % [resources.get_resource("embers"), e0, rm.get_lit_count()])
	# Short of embers: refused, nothing spent, by command and by the raw toggle.
	resources.spend_resource("embers", resources.get_resource("embers") - (RoomZone.LIGHT_COST - 1))
	_expect(await _request("toggle_light", {"zone": rooms[0].zone_id}) == "Brasas insuficientes", "no embers: command not refused")
	rooms[0].toggle_light()
	_expect(not rooms[0].is_lit and resources.get_resource("embers") == RoomZone.LIGHT_COST - 1, "no embers: lit or spent (%d)" % resources.get_resource("embers"))
	resources.add_resource("embers", 500)


# ---------------- obras ----------------

func _check_buildings(main2d: Node) -> void:
	for entry in resources.research_config.entries:
		resources.research_state.add(entry.id)
	var zone: RoomZone = _dark_rooms(main2d, 1)[0] if not _dark_rooms(main2d, 1).is_empty() else null
	if zone == null:
		failures.append("buildings: no dark room")
		return
	_expect(await _request("build", {"zone": zone.zone_id, "slot": 0, "type": Building.BuildingType.FORJA}) == "Sala apagada", "built in a dark room")
	await _request("toggle_light", {"zone": zone.zone_id})
	var majors := [Building.BuildingType.FORJA, Building.BuildingType.GRANJA, Building.BuildingType.SCRIPTORIUM]
	var minors := [Building.BuildingType.BALLESTA, Building.BuildingType.PINCHOS, Building.BuildingType.BRASERO]
	var built: Array[Building] = []
	var i := 0
	while zone.get_slot(i) != null:
		var slot := zone.get_slot(i)
		var pool := majors if int(slot.slot_type) == int(BuildingSlot.SlotType.MAJOR) else minors
		var type: Building.BuildingType = pool[i % pool.size()]
		var wrong: Building.BuildingType = (minors if pool == majors else majors)[0]
		_expect(await _request("build", {"zone": zone.zone_id, "slot": i, "type": wrong}) != "", "slot %d took a wrong-size building" % i)
		var iron := resources.get_resource("iron")
		var cost := Building.get_cost(type)
		_expect(await _request("build", {"zone": zone.zone_id, "slot": i, "type": type}) == "", "build %s in slot %d refused" % [Building.CATALOG[type]["label"], i])
		_expect(not slot.is_empty() and resources.get_resource("iron") == iron - cost, "slot %d: built %s, iron %d -> %d (cost %d)" % [i, not slot.is_empty(), iron, resources.get_resource("iron"), cost])
		_expect(await _request("build", {"zone": zone.zone_id, "slot": i, "type": type}) == "Hueco ocupado", "slot %d built twice" % i)
		if not slot.is_empty():
			built.append(slot.built_building)
		i += 1
	_expect(i >= 3, "a room offers %d slots" % i)
	# Talleres: only a turn pays; switched off they stop (requires_light), on they come back.
	var before := _snapshot()
	for _f in 30:
		await process_frame
	_expect(_snapshot() == before, "resources moved without a turn: %s -> %s" % [before, _snapshot()])
	var yields := ResourceManager.KEYS.map(func(k: String) -> int: return resources.get_turn_yield(k))
	_expect(yields.any(func(y: int) -> bool: return y > 0), "workshops yield nothing: %s" % [yields])
	main2d.door_turn_system.advance_turn("")
	for k in ResourceManager.KEYS.size():
		_expect(_snapshot()[k] - before[k] == yields[k], "turn paid %d %s, want %d" % [_snapshot()[k] - before[k], ResourceManager.KEYS[k], yields[k]])
	await _request("toggle_light", {"zone": zone.zone_id})
	for b in built:
		var needs := bool(Building.CATALOG[b.building_type].get("requires_light", true))
		_expect(b.is_working() == not needs, "%s dark: working %s (requires_light %s)" % [Building.CATALOG[b.building_type]["label"], b.is_working(), needs])
	for k in ResourceManager.KEYS:
		var workshop_dark := get_nodes_in_group("workshops").any(func(w: Node) -> bool: return w.resource_type == k and w.is_working())
		_expect(workshop_dark or resources.get_turn_yield(k) == 0, "dark room still yields %d %s" % [resources.get_turn_yield(k), k])
	await _request("toggle_light", {"zone": zone.zone_id})
	_expect(built.all(func(b: Building) -> bool: return b.is_working()), "relit: not every building works again")
	# Repair and demolish every one.
	for n in built.size():
		var b := built[n]
		var slot_index := n
		_expect(await _request("repair", {"zone": zone.zone_id, "slot": slot_index}) == "No está dañado", "repaired an intact building")
		b.take_damage(1)
		var iron := resources.get_resource("iron")
		var rcost := b.repair_cost()
		_expect(await _request("repair", {"zone": zone.zone_id, "slot": slot_index}) == "" and b.current_hp == b.max_hp and resources.get_resource("iron") == iron - rcost, "repair slot %d: hp %d/%d, iron %d -> %d (cost %d)" % [slot_index, b.current_hp, b.max_hp, iron, resources.get_resource("iron"), rcost])
		iron = resources.get_resource("iron")
		var refund := b.refund_value()
		_expect(await _request("demolish", {"zone": zone.zone_id, "slot": slot_index}) == "" and resources.get_resource("iron") == iron + refund, "demolish slot %d: iron %d -> %d (refund %d)" % [slot_index, iron, resources.get_resource("iron"), refund])
	await process_frame
	await process_frame
	for n in built.size():
		_expect(zone.get_slot(n).is_empty(), "slot %d still taken after demolishing" % n)
	resources.reset_research()


# ---------------- extracción ----------------

## False (nothing checked) when the exit was the last door of the map.
func _check_extraction(main2d: Node) -> bool:
	var rm: RoomManager = main2d.room_manager
	var doors: DoorTurnSystem = main2d.door_turn_system
	# Reveal until the exit is found, keeping one closed door next to a revealed zone.
	var closed: Door = null
	var progress := true
	while progress and not rm.is_zone_revealed(rm.get_exit_zone_id()):
		progress = false
		for door in rm.get_all_doors():
			if door.is_open or door.is_secret or not rm.is_zone_revealed(door.from_zone_id):
				continue
			doors.open_room(door.target_room_id)
			door.disable_door()
			progress = true
			break
	for door in rm.get_all_doors():
		if not door.is_open and not door.is_secret and rm.is_zone_revealed(door.from_zone_id) and rm.zones.has(door.from_zone_id):
			closed = door
	if closed == null:
		return false
	var hero: Player = main2d.heroes[0]
	var other: Player = main2d.heroes[1]
	main2d.relic_controller.confirm_pickup(hero)
	_expect(main2d.extraction_manager.current_phase == ExtractionManager.Phase.EXTRACTION and hero.is_carrying_relic, "pickup did not start the extraction")
	var reason := await _request("open_door", {"door": closed.door_id, "heroes": [hero.stats.hero_id, other.stats.hero_id]})
	_expect(reason != "" and not rm.is_group_revealed(closed.target_room_id), "a door opened during the extraction (%s)" % reason)
	_expect(main2d.player_action_controller.door_block_reason(closed, [other] as Array[Player]) == "Durante la extracción no se abren puertas" or closed.get_target_room_for(other.current_zone_id) == "",
		"extraction block reason: %s" % main2d.player_action_controller.door_block_reason(closed, [other] as Array[Player]))
	# A hero without the Reliquia walks into the exit: no victory.
	Engine.time_scale = 6.0
	_expect(await _request("move", {"heroes": [other.stats.hero_id], "zone": rm.get_exit_zone_id()}) == "", "move to the exit refused")
	Engine.time_scale = 1.0
	_tough(main2d)
	_expect(other.current_zone_id == rm.get_exit_zone_id(), "the walker stopped at '%s'" % other.current_zone_id)
	_expect(main2d.game_state_manager.current_state == GameStateManager.State.ACTIVE, "a hero without the Reliquia won (state %s)" % main2d.game_state_manager.current_state)
	return true

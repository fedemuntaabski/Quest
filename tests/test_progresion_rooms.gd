extends SceneTree

## progresion-10 rooms/events over a live Main2d:
##   - Altar: the primary hero in the room pays 30 % max HP for a RARE+ item, once;
##     refused when the price would down the hero or nobody is inside
##   - Secret room: opens by itself (no turn) once both neighbors are discovered,
##     its doors stay unclickable, it always holds a chest
##   - Boss: wakes when the exit room is discovered (floors 3/5), ignores the cap,
##     blocks the victory while alive; its death lets a waiting carrier win.
##     Embestida hurts heroes near the aimed point; phase 2 summons.
##   - Floor trap: hurts the first hero entering the corridor, once
##   godot --headless --path . --script res://tests/test_progresion_rooms.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	await _test_altar()
	await _test_secret_room()
	await _test_boss_gate(3)
	await _test_final_boss()
	await _test_hazard()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_progresion_rooms: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _live_main2d(floor_index: int, fallback: bool = true) -> Node:
	paused = false
	root.get_node("GameSession").reset_run()
	root.get_node("PartyInventory").reset()
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = fallback
	main2d.standalone_floor = floor_index
	root.add_child(main2d)
	await process_frame
	main2d.nexo.max_hp = 100000
	main2d.nexo.current_hp = 100000
	return main2d


func _free(main2d: Node) -> void:
	main2d.queue_free()
	await process_frame
	paused = false


func _test_altar() -> void:
	var main2d := await _live_main2d(1)
	var zone: String = main2d.room_manager.get_start_zone_id()
	var altar: AltarShrine = main2d._spawn_altar(zone)
	var hero: Player = main2d.heroes[0]
	root.get_node("SelectionManager").select_only(hero.stats.hero_id)
	_expect(altar.offering_hero() == hero, "the primary hero in the room offers")
	var before := hero.stats.current_hp
	var cost := altar.hp_cost(hero)
	_expect(cost == roundi(hero.stats.max_hp * 0.3), "cost = 30 percent of max HP (%d)" % cost)
	var item := altar.sacrifice()
	_expect(item != null and item.rarity >= ItemData.Rarity.RARE, "altar gives a RARE+ item: %s" % (item.id if item else "null"))
	_expect(hero.stats.current_hp == before - cost, "hero paid %d HP (%d -> %d)" % [cost, before, hero.stats.current_hp])
	_expect(root.get_node("PartyInventory").stash.size() == 1, "item in the stash")
	_expect(altar.sacrifice() == null and altar.get_block_reason() != "", "one use only")
	var altar_2: AltarShrine = main2d._spawn_altar("room_b" if main2d.room_manager.get_zone("room_b") else zone)
	altar_2.zone_id = zone
	hero.stats.current_hp = altar_2.hp_cost(hero)
	for other in main2d.heroes:
		if other != hero:
			other.stats.current_hp = altar_2.hp_cost(other)
	_expect(altar_2.sacrifice() == null and altar_2.get_block_reason().contains("vida"), "refused when it would down the hero: '%s'" % altar_2.get_block_reason())
	altar_2.zone_id = "nowhere"
	_expect(altar_2.get_block_reason() == "Un héroe tiene que estar en la sala", "refused with nobody inside")
	await _free(main2d)


func _test_secret_room() -> void:
	var main2d: Node = null
	var secret: RoomData = null
	for attempt in 12:
		main2d = await _live_main2d(2, false)
		for room in main2d.map_layout.rooms:
			if room.get_room_type() == RoomData.RoomType.SECRET:
				secret = room
		if secret:
			break
		await _free(main2d)
	if secret == null:
		failures.append("no generated floor got a secret room in 12 tries")
		return
	var rm: RoomManager = main2d.room_manager
	var doors: DoorTurnSystem = main2d.door_turn_system
	for door in rm.get_all_doors():
		if door.is_secret:
			_expect(not door.visible, "secret door '%s' hidden before the reveal" % door.door_id)
	var turn_before := -1
	var neighbors: PackedStringArray = secret.neighbors
	for i in neighbors.size():
		_open_path_to(main2d, neighbors[i])
		await process_frame
		if i == 0 and not rm.is_zone_revealed(neighbors[1]):  # the path to one may cross the other
			_expect(not rm.is_zone_revealed(secret.id), "one neighbor is not enough")
		turn_before = doors.current_turn
	await process_frame
	_expect(rm.is_zone_revealed(secret.id), "secret room revealed once both neighbors are discovered")
	_expect(doors.current_turn == turn_before, "the secret reveal does not tick the turn")
	for door in rm.get_all_doors():
		if door.is_secret:
			_expect(door.is_opened() and door.visible, "secret door '%s' shown open after the reveal" % door.door_id)
	var chest: Chest = main2d.loot_spawner.chests.get(secret.id)
	_expect(chest != null and chest.item.rarity >= ItemData.Rarity.UNCOMMON, "secret room holds an uncommon+ chest")
	await _free(main2d)


## Opens (without walking) every group on the tree path from the start to `room_id`.
func _open_path_to(main2d: Node, room_id: String) -> void:
	var layout: MapLayout = main2d.map_layout
	var chain: Array[String] = []
	var current := room_id
	while current != "" and current != layout.get_start_room_id():
		chain.push_front(current)
		var entry := layout.get_entry_corridor(current)
		current = entry.room_a if entry else ""
	for group in chain:
		main2d.door_turn_system.open_room(group)
		var door: Door = main2d.room_manager.get_door_for_group(group)
		if door:
			door.disable_door()


func _test_boss_gate(floor_index: int) -> void:
	var main2d := await _live_main2d(floor_index)
	var rm: RoomManager = main2d.room_manager
	var em: EnemyManager = main2d.enemy_manager
	var exit_zone := rm.get_exit_zone_id()
	_expect(em.boss == null, "floor %d: no boss before the exit is found" % floor_index)
	em.floor_manager.config = em.floor_manager.config.duplicate()
	em.floor_manager.config.run_curve = em.floor_manager.config.run_curve.duplicate(true)
	em.floor_manager.config.theme(floor_index).max_enemies = 0  # the boss ignores the cap
	_open_path_to(main2d, rm.get_group_id(exit_zone))
	await process_frame
	_expect(em.is_boss_alive() and em.boss.boss_brain != null and em.boss.current_zone_id == exit_zone, "floor %d: boss wakes in the exit room despite a 0 cap" % floor_index)
	var hero: Player = main2d.heroes[0]
	hero.is_carrying_nexo = true
	hero.set_zone(exit_zone, rm.get_center(exit_zone), main2d.floor_layer)
	main2d.extraction_manager.declare_victory()
	await process_frame
	_expect(main2d.game_state_manager.is_active(), "floor %d: victory refused while the boss lives" % floor_index)
	em.boss.take_damage(999999)
	await process_frame
	_expect(main2d.game_state_manager.current_state == GameStateManager.State.VICTORY, "floor %d: boss death lets the waiting carrier win" % floor_index)
	await _free(main2d)


func _test_final_boss() -> void:
	var main2d := await _live_main2d(5)
	var rm: RoomManager = main2d.room_manager
	var em: EnemyManager = main2d.enemy_manager
	em.floor_manager.config = em.floor_manager.config.duplicate()
	var exit_zone := rm.get_exit_zone_id()
	_open_path_to(main2d, rm.get_group_id(exit_zone))
	await process_frame
	var boss := em.boss
	_expect(boss != null and boss.type.boss_tier == 1, "floor 5: the final boss")
	if boss == null:
		await _free(main2d)
		return
	var brain := boss.boss_brain
	# Embestida: a hero right next to the boss takes the hit.
	var hero: Player = main2d.heroes[0]
	hero.set_zone(exit_zone, boss.global_position + Vector2(40, 0), main2d.floor_layer)
	var hp_before := hero.stats.current_hp
	_expect(brain.try_charge(), "charge starts with a hero in range")
	await create_timer(BossBrain.TELEGRAPH_SEC + BossBrain.DASH_SEC + 0.2).timeout
	_expect(hero.stats.current_hp < hp_before, "embestida hurt the hero (%d -> %d)" % [hp_before, hero.stats.current_hp])
	# Phase 2 below half HP: summons right away.
	var before := em.alive_count()
	boss.take_damage(boss.max_hp - boss.max_hp / 2 + 1)
	for i in 3:
		await process_frame
	_expect(brain.phase == 2, "phase 2 below half HP")
	_expect(em.alive_count() > before, "phase 2 summons minions (%d -> %d)" % [before, em.alive_count()])
	await _free(main2d)


func _test_hazard() -> void:
	var main2d := await _live_main2d(2)
	var rm: RoomManager = main2d.room_manager
	var spawner: HazardSpawner = main2d.hazard_spawner
	var corridor := ""
	for zone_id in rm.get_zone_ids():
		if rm.get_zone_kind(zone_id) == "corridor":
			corridor = zone_id
			break
	spawner.arm(corridor)
	var hero: Player = main2d.heroes[0]
	var other: Player = main2d.heroes[1]
	var before := hero.stats.current_hp
	hero.set_zone(corridor, rm.get_center(corridor), main2d.floor_layer)
	_expect(hero.stats.current_hp < before and not spawner.traps.has(corridor), "trap hurt the first hero and broke")
	var other_before := other.stats.current_hp
	other.set_zone(corridor, rm.get_center(corridor), main2d.floor_layer)
	_expect(other.stats.current_hp == other_before, "a broken trap hurts nobody else")
	await _free(main2d)

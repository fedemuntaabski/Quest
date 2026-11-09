extends SceneTree

## juego-23: the floor-3 boss with its real HP against a level-2 Guerrero + Mago, with or
## without one Ballesta in the start room (needs a real window, NOT --headless). The boss is
## spawned in the room next to the start room and walks in; nobody gives orders (auto-combat
## only, so the Embestida is never dodged: the worst case). Saves j23_boss_<mode>_<s>s.png and
## prints a 1 s timeline (boss HP, hero HP) and the outcome.
##   godot --path . --resolution 1920x1080 --script res://tests/tools/shot_jefe.gd -- <out_dir> ballesta|sin

const SHOTS_AT := [3, 8, 15]
const MAX_SEC := 60


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var mode: String = args[1] if args.size() > 1 else "ballesta"
	var session := root.get_node("GameSession")
	session.clear()
	session.set_selection(["warrior", "mage"] as Array[String])
	var resources := root.get_node("ResourceManager") as ResourceManager
	resources.reset_resources(200, 200, 50, 50)
	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.standalone_floor = 3
	root.add_child(main2d)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false
	var rm: RoomManager = main2d.room_manager
	var start := rm.get_start_zone_id()
	for door in rm.get_all_doors():  # reveal the start room's neighbours only
		if not door.is_open and not door.is_secret and door.from_zone_id == start:
			main2d.door_turn_system.open_room(door.target_room_id)
			door.disable_door()
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	var stats := root.get_node("PlayerStats")
	for hero: Player in main2d.heroes:
		for i in 2:
			stats.level_up_hero(hero.stats.hero_id)
		hero.stats.current_hp = hero.stats.max_hp
	if mode == "ballesta":
		resources.research_state.add("ballesta")  # "Planos de ballesta" (Saber + a Scriptorium)
		var zone: RoomZone = rm.get_zone_node(start)
		var i := 0
		while zone.get_slot(i) != null and int(zone.get_slot(i).slot_type) != int(BuildingSlot.SlotType.MINOR):
			i += 1
		var err: String = await root.get_node("NetCommands").request("build", {"zone": start, "slot": i, "type": Building.BuildingType.BALLESTA})
		print("ballesta in slot %d: %s" % [i, "ok" if err == "" else err])
	var boss_room := ""
	for id in rm.get_zone_ids():
		if id != start and rm.get_zone_kind(id) == "room" and rm.is_zone_revealed(id):
			boss_room = id
			break
	var theme: FloorTheme = main2d.floor_manager.config.theme(3)
	var boss: Enemy = main2d.enemy_manager.spawn_boss(boss_room, theme.boss)
	print("floor %d, boss %s HP %d in %s; heroes %s" % [main2d.floor_manager.floor_index, boss.type.id, boss.current_hp, boss_room,
		main2d.heroes.map(func(h: Player) -> String: return "%s lvl %d HP %d" % [h.stats.hero_id, stats.get_hero_level(h.stats.hero_id), h.stats.max_hp])])
	main2d.camera.set_target_zoom(2.0)
	main2d.camera.focus_on((rm.get_center(start) + rm.get_center(boss_room)) * 0.5)
	var outcome := "time out"
	for sec in range(1, MAX_SEC + 1):
		await create_timer(1.0).timeout
		var alive: Array = main2d.heroes.filter(func(h: Player) -> bool: return h.stats.current_hp > 0)
		print("  t=%2ds boss %3d  %s" % [sec, boss.current_hp if is_instance_valid(boss) else 0,
			"  ".join(main2d.heroes.map(func(h: Player) -> String: return "%s %d" % [h.stats.hero_id, h.stats.current_hp]))])
		if SHOTS_AT.has(sec):
			root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("j23_boss_%s_%02ds.png" % [mode, sec]))
		if not is_instance_valid(boss) or not boss.is_alive():
			outcome = "boss dead at %d s" % sec
			break
		if alive.is_empty():
			outcome = "party down at %d s (boss %d HP left)" % [sec, boss.current_hp]
			break
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("j23_boss_%s_end.png" % mode))
	print("RESULT %s: %s" % [mode, outcome])
	session.clear()
	quit()

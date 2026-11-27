extends SceneTree

## personajes-46: a floor-3 fight in a real window (NOT --headless), 1920x1080. Four heroes (Clériga,
## Ballestero + Guerrero, Mago freed), a Ballesta and a Catapulta in the start room, and a wave with the
## two new enemies (Calabacero, Curandero del Pantano) closing in with their AI on. Saves
## <out_dir>/combate_<n>.png while they fight: everyone should be visible (enemies on the ring above and
## below the heroes' row), heroes in their attack frames, Defensas turned to their targets.
##   godot --path . --script res://tests/tools/shot_combate.gd -- <out_dir>

const WAVE := ["goblin", "skelet", "masked_orc", "pumpkin", "swampy", "pumpkin", "imp", "goblin"]


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	root.mode = Window.MODE_WINDOWED
	for i in 10:
		await process_frame
	root.size = Vector2i(1920, 1080)
	var session := root.get_node("GameSession")
	session.clear()
	session.set_selection(["cleric", "ranger"] as Array[String])
	var rm := root.get_node("ResourceManager")
	rm.reset_resources(500, 500, 500, 500)
	for entry in load("res://resources/research/research_config.tres").entries:
		rm.researched[entry.id] = true
	root.get_node("PlayerStats").reset_run_upgrades()
	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.standalone_floor = 3
	root.add_child(main2d)
	await process_frame
	var hud := (load("res://scenes/hud/HUD.tscn") as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false
	var start: String = main2d.room_manager.get_start_zone_id()
	for id in ["warrior", "mage"]:
		main2d.recruit_hero(id, start)
	main2d.relic.max_hp = 100000
	main2d.relic.current_hp = 100000
	for hero: Player in main2d.heroes:
		hero.stats.max_hp = 400
		hero.stats.current_hp = 400
	var cmds := root.get_node("NetCommands")
	for type in [Building.BuildingType.BALLESTA, Building.BuildingType.CATAPULTA]:
		for slot in 12:
			await create_timer(0.35).timeout
			if str(await cmds.request("build", {"zone": start, "slot": slot, "type": type})) == "":
				break
	var center: Vector2 = main2d.room_manager.get_center(start)
	for i in WAVE.size():
		var enemy := EnemyManager.ENEMY_SCENE.instantiate() as Enemy
		main2d.enemy_manager._enemies_root.add_child(enemy)
		enemy.setup(center + Vector2.from_angle(i * TAU / WAVE.size()) * 170.0)
		enemy.slot = i
		enemy.configure(Enemy.Variant.SWARM, start, 4.0, 1.0, load("res://resources/enemies/%s.tres" % WAVE[i]))
	main2d.camera.zoom = Vector2(1.8, 1.8)
	main2d.camera.global_position = center
	var shots := 0
	for wait in [1.6, 0.7, 0.9]:
		await create_timer(wait).timeout
		shots += 1
		root.get_texture().get_image().save_png(out_dir.path_join("combate_%d.png" % shots))
		print("shot combate_%d, %d enemies" % [shots, main2d.enemy_manager._enemies_root.get_child_count()])
	quit()

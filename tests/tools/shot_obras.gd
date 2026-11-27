extends SceneTree

## personajes-46: Obras built on the map show their menu icon (real window, NOT --headless). Boots Main2d +
## HUD, unlocks every research, builds every Obra type it can in the start room through NetCommands
## "build", picks a Clériga perk, and saves <out_dir>/obras_mapa.png, obras_menu.png (Mayores tab
## armed) and obras_ficha.png (sheet with the perk icons).
##   godot --path . --script res://tests/tools/shot_obras.gd -- <out_dir>

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
	var research := load("res://resources/research/research_config.tres")
	for entry in research.entries:
		rm.researched[entry.id] = true
	var ps := root.get_node("PlayerStats")
	ps.reset_run_upgrades()
	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var hud := (load("res://scenes/hud/HUD.tscn") as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false
	var start: String = main2d.room_manager.get_start_zone_id()
	var cmds := root.get_node("NetCommands")
	var built := 0
	for type: int in Building.CATALOG:
		for slot in 12:
			await create_timer(0.35).timeout  # NetCommands rate limit ("Demasiadas órdenes")
			var reason = await cmds.request("build", {"zone": start, "slot": slot, "type": type})
			if str(reason) == "":
				built += 1
				break
	print("built ", built, " Obras")
	for i in 2:
		ps.level_up_hero("cleric")
	var pending: Array = ps.get_pending_perk_choices("cleric")
	if not pending.is_empty():
		ps.choose_perk("cleric", pending[0].id)
	for i in 2:
		ps.level_up_hero("cleric")
	main2d.camera.zoom = Vector2(1.6, 1.6)
	main2d.camera.global_position = main2d.room_manager.get_center(start)
	for hero: Player in main2d.heroes:
		hero.global_position += Vector2(0, -150)
	for i in 30:
		await process_frame
	_save(out_dir, "obras_mapa")
	hud.open_hero_sheet(hud.portraits.get_child(0))
	for i in 15:
		await process_frame
	_save(out_dir, "obras_ficha")
	hud.character_popup.close()
	var menu := hud.find_child("BuildingMenu", true, false)
	if menu and menu.has_method("open_tab"):
		menu.open_tab(0)
	for i in 15:
		await process_frame
	_save(out_dir, "obras_menu")
	quit()


func _save(out_dir: String, name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)

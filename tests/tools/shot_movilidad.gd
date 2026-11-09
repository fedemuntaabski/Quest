extends SceneTree

## Visual check for juego-22 movement (needs a real window, NOT --headless):
##   j22_corridor.png  zoom 3 on the first hero frozen halfway through a corridor (does it
##                     stay inside the walls?), the second one behind it
##   j22_party.png     the party of 4 (2 picked + 2 recruits) standing in one room: the
##                     sprites side by side, not stacked
##   j22_vertical.png  the 4 standing in a vertical corridor (the sprite offset is horizontal)
##   godot --path . --resolution 1920x1080 --script res://tests/tools/shot_movilidad.gd -- <out_dir>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var session := root.get_node("GameSession")
	session.clear()
	session.set_selection(["warrior", "mage"] as Array[String])
	session.recruited_ids.assign(["rogue", "tank"])
	(root.get_node("ResourceManager") as ResourceManager).reset_resources(200, 200, 50, 50)
	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	var rm: RoomManager = main2d.room_manager
	var start := rm.get_start_zone_id()
	for door in rm.get_all_doors():
		if not door.is_open and not door.is_secret and rm.is_zone_revealed(door.from_zone_id):
			main2d.door_turn_system.open_room(door.target_room_id)
			door.disable_door()
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()

	# 4 heroes in the start room.
	main2d.camera.set_target_zoom(3.0)
	main2d.camera.focus_on(rm.get_center(start))
	await create_timer(1.2).timeout
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("j22_party.png"))

	# Two heroes walk to the farthest revealed room; freeze when the first is mid-corridor.
	var target := start
	for id in rm.get_zone_ids():
		if rm.get_zone_kind(id) == "room" and rm.is_zone_revealed(id) and rm.find_zone_path(start, id).size() > rm.find_zone_path(start, target).size():
			target = id
	var walkers: Array[Player] = [main2d.heroes[0], main2d.heroes[1]]
	main2d.player_action_controller.move_heroes(walkers, target)
	var lead: Player = walkers[0]
	for i in 600:
		await process_frame
		var zone := lead.current_zone_id
		if rm.get_zone_kind(zone) == "corridor" and lead.global_position.distance_to(rm.get_center(zone)) < 40.0:
			break
	main2d.camera.focus_on(lead.global_position)
	Engine.time_scale = 0.0
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("j22_corridor.png"))
	Engine.time_scale = 1.0
	await create_timer(8.0).timeout
	# The 4 ordered into a vertical corridor (taller than wide), if the map has one.
	var vertical := ""
	for id in rm.get_zone_ids():
		var rect: Rect2i = rm.zones[id]["rect"]
		if rm.get_zone_kind(id) == "corridor" and rm.is_zone_revealed(id) and rect.size.y > rect.size.x:
			vertical = id
	if vertical != "":
		var all: Array[Player] = []
		all.assign(main2d.heroes)
		await main2d.player_action_controller.move_heroes(all, vertical)
		main2d.camera.focus_on(rm.get_center(vertical))
		await create_timer(0.8).timeout
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("j22_vertical.png"))
	print("vertical corridor: '%s' center %s" % [vertical, rm.get_center(vertical) if vertical != "" else Vector2.ZERO])
	for h: Player in main2d.heroes:
		print("  %s zone %s pos %s sprite %s visible %s" % [h.stats.hero_id, h.current_zone_id, h.global_position, h.animated_sprite.global_position, h.visible])
	session.clear()
	print("saved ", out_dir, " corridor ", lead.current_zone_id)
	quit()

extends SceneTree

## Visual check for juego-21 (needs a real window, NOT --headless):
##   j21_fx.png     start room at zoom 3: the 4 new effects in a row (room_lit,
##                  relic_pickup, enemy_spawn, door_dust) frozen mid-play, a hero
##                  downed (tipped over), an enemy lunging, a corpse falling, a
##                  Botín chest and a door leaf (sheets moved out of _source/)
##   godot --path . --resolution 1920x1080 --script res://tests/tools/shot_juego21.gd -- <out_dir>

const EFFECTS := [&"room_lit", &"relic_pickup", &"enemy_spawn", &"door_dust"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var session := root.get_node("GameSession")
	session.clear()
	session.set_selection(["warrior", "mage"] as Array[String])
	(root.get_node("ResourceManager") as ResourceManager).reset_resources(200, 200, 50, 50)

	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false

	var rm: RoomManager = main2d.room_manager
	var start := rm.get_start_zone_id()
	var center := rm.get_center(start)
	for hero: Player in main2d.heroes:
		hero.hitbox.set_active(false)
	var catalog := load(ItemCatalog.DEFAULT_PATH) as ItemCatalog
	var chest := (load("res://scenes/world/Pickup.tscn") as PackedScene).instantiate() as Pickup
	chest.kind = Pickup.Kind.CHEST
	chest.item = catalog.items[0]
	chest.position = center + Vector2(110, -60)
	main2d.add_child(chest)

	main2d.camera.set_target_zoom(3.0)
	main2d.camera.focus_on(center + Vector2(0, 20))
	await create_timer(1.6).timeout  # spawn portals of earlier enemies fade out

	var downed: Player = main2d.heroes[1]
	downed.stats.take_damage(downed.stats.max_hp)
	var em: EnemyManager = main2d.enemy_manager
	var lunger := em._spawn_enemy(start, center + Vector2(-110, 70)) as Enemy
	var dying := em._spawn_enemy(start, center + Vector2(110, 70)) as Enemy
	for e in [lunger, dying]:
		e.set_physics_process(false)
		e.set_process(false)
	await create_timer(0.7).timeout  # their own portals end; the downed hero has tipped over
	var vfx := ManagerLocator.get_vfx_manager()
	for i in EFFECTS.size():
		vfx.play(EFFECTS[i], center + Vector2(-150 + i * 100, 110) + (RoomZone.ROOM_LIT_FX_OFFSET if i == 0 else Vector2.ZERO))
	await create_timer(0.3).timeout  # effects near their peak
	lunger.visual.lunge(Vector2.RIGHT)
	dying.take_damage(9999)
	for i in 4:
		await process_frame
	Engine.time_scale = 0.0  # freeze mid-animation
	for i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("j21_fx.png"))
	Engine.time_scale = 1.0
	print("saved ", out_dir)
	quit()

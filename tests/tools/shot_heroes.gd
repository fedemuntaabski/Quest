extends SceneTree

## Visual check for heroes-9 (needs a real window, NOT --headless). Boots Main2d +
## HUD with 2 picked heroes, frees 2 prisoners (4 portraits), leaves one hero at
## low HP (blinking bar), downs another (grey + Reanimar), puts the Warrior's
## ability on cooldown (radial), damages an enemy (HP bar), fires a Mage
## projectile and spawns a Prisoner cage; saves <dir>/heroes_hud.png, then opens
## the hero sheet and saves <dir>/heroes_popup.png.
##   godot --path . --script res://tests/tools/shot_heroes.gd -- <out_dir>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var session := root.get_node("GameSession")
	session.clear()
	session.set_selection(["warrior", "mage"] as Array[String])
	var resources := root.get_node("ResourceManager") as ResourceManager
	resources.reset_resources(200, 200, 50, 50)
	root.get_node("PlayerStats").reset_run_upgrades()

	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var hud := (load("res://scenes/hud/HUD.tscn") as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false

	var rm: RoomManager = main2d.room_manager
	var start := rm.get_start_zone_id()
	# Two prisoners freed -> 4 heroes; a third cage stays visible (empty party slot? no: full).
	for i in 2:
		var cage: PrisonerCage = main2d.prisoner_spawner.spawn_for(start)
		if cage:
			cage.free_with("industry")
	main2d.heroes[1].stats.take_damage(main2d.heroes[1].stats.max_hp - 3)  # low HP: blink
	main2d.heroes[2].stats.take_damage(main2d.heroes[2].stats.max_hp)  # downed
	main2d.heroes[0].abilities.try_activate()
	main2d.heroes[0].abilities.cooldown_left *= 0.6

	# A cage drawn next to the party (decor only: the party is full).
	var cage := PrisonerCage.new()
	cage.setup("rogue", start, {"industry": 20, "food": 15}, Callable())
	cage.position = rm.get_center(start) + Vector2(110, -40)
	main2d.prisoner_spawner.add_child(cage)

	var enemy := (load("res://scenes/entities/Enemy.tscn") as PackedScene).instantiate() as Enemy
	main2d.add_child(enemy)
	var pool := main2d.floor_manager.config.enemy_pool(1) as EnemyPool
	enemy.setup(rm.get_center(start) + Vector2(-110, 30))
	enemy.configure(Enemy.Variant.SWARM, start, 1.0, 1.0, pool.types[1])
	enemy.ai_timer.stop()
	enemy.hitbox.set_active(false)
	enemy.take_damage(2)
	var mage: Player = main2d.heroes[1]
	for hero: Player in main2d.heroes:  # keep the damaged enemy alive for the shot
		hero.hitbox.set_active(false)

	main2d.camera.set_target_zoom(2.0)
	main2d.camera.focus_on(rm.get_center(start))
	await create_timer(1.6).timeout  # level-up auras of the recruits fade out
	Projectile.fire(main2d, mage.global_position + Vector2(0, -30), enemy.hurtbox, mage.hitbox, 0, 60.0, mage.vfx_color())
	for i in 20:
		await process_frame
	Engine.time_scale = 0.0  # freeze the shot (UI pulses run on real time)
	for i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("heroes_hud.png"))

	hud.open_hero_sheet(hud._portraits["warrior"])
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("heroes_popup.png"))
	hud.character_popup.close()
	hud.open_hero_sheet(hud._portraits[main2d.heroes[2].stats.hero_id])
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("heroes_popup_downed.png"))
	Engine.time_scale = 1.0
	print("saved ", out_dir)
	quit()

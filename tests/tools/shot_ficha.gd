extends SceneTree

## personajes-46: the hero sheet (CharacterPopup) in a real window (NOT --headless), for the mockups.
## (Two mockups were shot with it; the owner picked "Libro abierto", the only one left.)
## Boots Main2d + HUD with Clériga + Ballestero, gives Comida, buys 2 levels (a perk choice pending),
## opens the Clériga's sheet and saves <out_dir>/ficha_<tag>.png.
##   godot --path . --script res://tests/tools/shot_ficha.gd -- <out_dir> <w> <h> <text_scale> <tag>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var size := Vector2i(int(args[1]), int(args[2]))
	var tag: String = args[4]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	root.get_node("SettingsManager").text_scale = float(args[3])
	root.mode = Window.MODE_WINDOWED
	for i in 10:
		await process_frame
	root.size = size
	for i in 10:
		await process_frame
	var session := root.get_node("GameSession")
	session.clear()
	session.set_selection(["cleric", "ranger"] as Array[String])
	root.get_node("ResourceManager").reset_resources(40, 200, 60, 30)
	var ps := root.get_node("PlayerStats")
	ps.reset_run_upgrades()
	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var hud := (load("res://scenes/hud/HUD.tscn") as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	for i in 2:
		ps.level_up_hero("cleric")
	main2d.heroes[0].stats.take_damage(6)
	for i in 20:
		await process_frame
	hud.open_hero_sheet(hud.portraits.get_child(0))
	for i in 20:
		await process_frame
	_save(out_dir, "ficha_" + tag)
	quit()


func _save(out_dir: String, name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", img.get_size())

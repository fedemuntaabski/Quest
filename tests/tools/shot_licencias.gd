extends SceneTree

## Visual check for licencias-20 (needs a real window, NOT --headless): the art
## that replaced the unknown-licence sheets. Boots Main2d + HUD with 2 heroes,
## fills the party stash with all 18 items, equips sword/armour/talisman/potion on
## the Warrior and saves:
##   lic_hud.png     HUD + world: Reliquia (own gem), a Botín chest with an item,
##                   the 8 own VFX playing in a row
##   lic_relic.png   close-up of the Reliquia and the VFX row
##   lic_sheet.png   hero sheet (stats, ability icons, equipment)
##   lic_backpack.png  same sheet scrolled down: the Mochila with every item icon
##   godot --path . --resolution 1920x1080 --script res://tests/tools/shot_licencias.gd -- <out_dir>

const EFFECTS := [&"hit_slash", &"hit_sparks", &"death_dust", &"heal_glow", &"buff_attack", &"buff_shield", &"buff_building", &"level_up"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var session := root.get_node("GameSession")
	session.clear()
	session.set_selection(["warrior", "mage"] as Array[String])
	(root.get_node("ResourceManager") as ResourceManager).reset_resources(200, 200, 50, 50)
	root.get_node("PlayerStats").reset_run_upgrades()
	var inv: Node = root.get_node("PartyInventory")
	inv.reset()

	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var hud := (load("res://scenes/hud/HUD.tscn") as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false

	var catalog := load(ItemCatalog.DEFAULT_PATH) as ItemCatalog
	for item: ItemData in catalog.items:
		inv.add_item(item)
	for id: String in ["sword_gold", "armor_jade", "potion_health"]:
		for item: ItemData in catalog.items:
			if item.id == id:
				inv.equip("warrior", item)

	var rm: RoomManager = main2d.room_manager
	var start := rm.get_start_zone_id()
	var center := rm.get_center(start)
	for hero: Player in main2d.heroes:
		hero.hitbox.set_active(false)
	var chest := (load("res://scenes/world/Pickup.tscn") as PackedScene).instantiate() as Pickup
	chest.kind = Pickup.Kind.CHEST
	chest.item = catalog.items[0]
	chest.position = center + Vector2(110, 40)
	main2d.add_child(chest)

	main2d.camera.set_target_zoom(2.0)
	main2d.camera.focus_on(center)
	await create_timer(1.6).timeout  # spawn auras fade out
	var vfx := ManagerLocator.get_vfx_manager()
	for i in EFFECTS.size():
		vfx.play(EFFECTS[i], center + Vector2(-140 + i * 40, 90), Color(1.0, 0.85, 0.6))
	for i in 5:
		await process_frame
	Engine.time_scale = 0.0  # freeze mid-animation (UI runs on real time)
	for i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("lic_hud.png"))

	main2d.camera.set_target_zoom(4.0)
	main2d.camera.focus_on(center + Vector2(0, 30))
	await create_timer(0.8, true, false, true).timeout
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("lic_relic.png"))

	hud.open_hero_sheet(hud._portraits["warrior"])
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("lic_sheet.png"))
	for scroll in hud.character_popup.find_children("*", "ScrollContainer", true, false):
		(scroll as ScrollContainer).scroll_vertical = 100000
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("lic_backpack.png"))
	Engine.time_scale = 1.0
	print("saved ", out_dir)
	quit()

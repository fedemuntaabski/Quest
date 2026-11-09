extends SceneTree

## visual-24: sweep of every menu screen and HUD piece (needs a real window, NOT --headless),
## through the real Main orchestrator. Saves <out_dir>/<cfg>_<shot>.png.
##   godot --path . --script res://tests/tools/shot_barrido.gd -- <out_dir>          # every cfg, one process each
##   godot --path . --script res://tests/tools/shot_barrido.gd -- <out_dir> 720      # one cfg
## cfg: 720 = 1280x720, 1080 = 1920x1080, 1080x15 = 1920x1080 with the accessibility text
## scale at its max (SettingsManager.TEXT_SCALE_MAX). The stretch is canvas_items/keep, so
## every 16:9 size shares one layout: 720 checks legibility, 1080x15 checks overflow.

const CFGS := {"720": [Vector2i(1280, 720), 1.0], "1080": [Vector2i(1920, 1080), 1.0], "1080x15": [Vector2i(1920, 1080), 1.5]}
const SLOT := 94
const PORT := 24941
const POTION := "res://resources/items/potion_health.tres"
const LONG_HINT := "Una pista larga de prueba: la Reliquia sigue en la sala inicial y la salida ya está descubierta."

var _dir: String
var _cfg: String
var _main: Main


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "user://"
	DirAccess.make_dir_recursive_absolute(_dir)
	if args.size() < 2:
		_run_all()
		return
	_cfg = args[1]
	await process_frame  # SettingsManager._ready applies the player's settings.cfg first
	await process_frame
	var size: Vector2i = CFGS[_cfg][0]
	var settings := root.get_node("SettingsManager")
	settings.text_scale = CFGS[_cfg][1]
	root.mode = Window.MODE_WINDOWED
	for i in 20:  # the mode change resizes the window late: set the size after it
		await process_frame
	root.size = size  # the root viewport renders at this size even if the OS keeps the window fullscreen
	for i in 20:
		await process_frame
	if root.get_texture().get_image().get_size() != size:
		print("WARNING window is %s, wanted %s" % [root.get_texture().get_image().get_size(), size])
	await _sweep()


func _run_all() -> void:
	for cfg: String in CFGS:
		var out: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/tools/shot_barrido.gd", "--", _dir, cfg], out, true)
		print("cfg %s: exit %d, %d shots" % [cfg, code, "\n".join(out).count("saved ")])
	quit()


func _sweep() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _wait(3.0)
	await _menus()
	await _waiting_room()
	await _intro_and_tutorial()
	await _floor_one()
	await _floor_five()
	root.get_node("SaveManager").delete_save(SLOT)
	paused = false
	Engine.time_scale = 1.0
	quit()


func _menus() -> void:
	var menu: Node = _main.ui_container.get_child(0)
	var flow: MainMenuFlow = menu.flow
	await _shot("menu")
	menu.start_button.grab_focus()
	await _shot("menu_focus")
	flow.start_pressed()
	await _wait(0.8)
	await _shot("network_mode")
	flow.network_mode_select.host_button.grab_focus()
	await _shot("network_mode_focus")
	flow._on_offline_selected()
	await _wait(0.8)
	await _shot("slots")
	flow.slot_selector.slot_buttons[0].grab_focus()
	await _shot("slots_focus")
	flow._ask_continue(2)
	await _wait(0.4)
	await _shot("continue_dialog")
	flow.continue_dialog.hide()
	flow.continue_dialog.queue_free()
	flow._open_hero_select()
	await _wait(0.8)
	await _shot("hero_select")
	flow.show_main_menu()
	await _wait(0.6)
	flow.show_options_menu()
	await _wait(0.8)
	var tabs := flow.options_menu.options_tabs
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		await _wait(0.2)
		await _shot("options_%d_%s" % [i, tabs.get_tab_title(i).to_lower()])
	flow.show_main_menu()
	await _wait(0.6)


func _waiting_room() -> void:
	var net := root.get_node("NetSession") as CoopSession
	var transport := EnetTransport.new(net.api)
	transport.port = PORT
	if net.host(4, transport) != OK:
		print("waiting room: host failed")
		return
	await _wait(1.5)
	if _find(_main.ui_container, "WaitingRoom") == null:
		await _main.go_to_waiting_room()
	await _wait(1.0)
	await _shot("waiting_room")
	net.leave("menu")
	await _main.return_to_main_menu()
	await _wait(1.0)


func _intro_and_tutorial() -> void:
	root.get_node("SettingsManager").reset_help()
	_main.play_intro = true
	_main.start_tutorial()
	while _main.intro_screen == null:
		await process_frame
	await _wait(7.5)
	await _shot("intro")
	_main.intro_screen.skip()
	while _main.world_container.get_child_count() == 0:
		await process_frame
	await _wait(1.5)
	await _shot("tutorial")
	_main.play_intro = false
	await _main.return_to_main_menu()
	await _wait(1.0)


func _floor_one() -> void:
	root.get_node("SaveManager").load_game(SLOT)
	root.get_node("GameSession").set_selection(["warrior", "mage"] as Array[String])
	await _main.start_gameplay()
	await _wait(1.5)
	await _shot("f1_start")  # floor label, ObjectivePanel, HelpCard, portraits, minimap
	var world := _world()
	var hud: HUDController = ManagerLocator.get_hud()
	_four_heroes(world)
	await _wait(1.0)
	await _shot("f1_portraits")  # 4 heroes: low HP, downed + Reanimar, consumables
	hud.open_hero_sheet(hud._portraits["warrior"])
	await _wait(0.4)
	await _shot("f1_sheet")
	hud.character_popup.close()
	hud.open_hero_sheet(hud._portraits[world.heroes[2].stats.hero_id])
	await _wait(0.4)
	await _shot("f1_sheet_downed")
	hud.character_popup.close()
	for tab: int in [0, 1, hud.building_menu.RESEARCH_TAB]:
		hud.building_menu.open_category(tab)
		await _wait(0.4)
		await _shot("f1_build_tab%d" % tab)
	hud.building_menu.close_menu()
	hud.research_panel.open()
	await _wait(0.4)
	await _shot("f1_research_panel")
	hud.research_panel.close()
	var building := await _build_one(world)
	if building:
		hud.building_popup.open_for(building)
		await _wait(0.4)
		await _shot("f1_building_popup")
		hud.building_popup.close()
	hud.show_hint("Sala de Descanso", LONG_HINT, QuestPalette.GOLD_LIGHT)
	await _wait(0.4)
	await _shot("f1_hint")
	hud.show_refusal("No alcanza el Hierro: faltan 12 para construir esta Obra en la sala.")
	await _wait(0.4)
	await _shot("f1_refusal")
	root.push_input(_action(&"ui_cancel"))
	await _wait(0.5)
	await _shot("pause")
	var pause := get_first_node_in_group("pause_menu")
	if pause == null:
		pause = _find(root, "PauseMenu")
	if pause:
		pause.options_button.pressed.emit()
		await _wait(0.6)
		await _shot("pause_options")
		pause._set_panel(0)
		await _wait(0.3)
	root.push_input(_action(&"ui_cancel"))
	await _wait(0.5)
	world.extraction_manager.declare_victory()
	await _wait(2.4)
	await _shot("victory")
	paused = false
	await _main.reload_gameplay()
	await _wait(0.5)
	_world()._on_player_died()
	await _wait(2.4)
	await _shot("death")
	paused = false


func _floor_five() -> void:
	root.get_node("GameSession").set_selection(["warrior", "mage"] as Array[String])
	await _main.start_gameplay(5)
	await _wait(1.5)
	var world := _world()
	_four_heroes(world)
	for i in 60:
		if not _open_next_door(world):
			break
	await _wait(1.5)
	await _shot("f5_boss")  # boss bar + its hint, 4 portraits
	paused = false
	var boss: Enemy = world.enemy_manager.boss
	if is_instance_valid(boss):
		boss.take_damage(boss.current_hp)  # the exit is refused while the boss lives
	await _wait(0.5)
	world.extraction_manager.declare_victory()
	await _wait(2.4)
	await _shot("victory_final")
	paused = false


## 2 picked + 2 recruits; one low, one downed, potions on the first.
func _four_heroes(world: Node) -> void:
	var start: String = world.room_manager.get_start_zone_id()
	for id: String in ["rogue", "tank"]:
		world.recruit_hero(id, start)
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	var heroes: Array = world.heroes
	heroes[1].stats.take_damage(heroes[1].stats.max_hp - 3)
	heroes[2].stats.take_damage(heroes[2].stats.max_hp)
	var party := root.get_node("PartyInventory")
	for i in 2:
		var potion := (load(POTION) as ItemData).duplicate()
		party.add_item(potion)
		party.equip(heroes[0].stats.hero_id, potion)


## A Taller in a major slot of the start room (resources topped up first).
func _build_one(world: Node) -> Building:
	(root.get_node("ResourceManager") as ResourceManager).reset_resources(500, 500, 500, 500)
	var rm: RoomManager = world.room_manager
	var start := rm.get_start_zone_id()
	var zone: RoomZone = rm.get_zone_node(start)
	var i := 0
	while zone.get_slot(i) != null and int(zone.get_slot(i).slot_type) != int(BuildingSlot.SlotType.MAJOR):
		i += 1
	if zone.get_slot(i) == null:
		return null
	var err: String = await root.get_node("NetCommands").request("build", {"zone": start, "slot": i, "type": Building.BuildingType.FORJA})
	if err != "":
		print("build refused: ", err)
	return zone.get_slot(i).built_building


func _open_next_door(world: Node) -> bool:
	var rm: RoomManager = world.room_manager
	for door: Door in world.doors_root.get_children():
		if door.is_open or door.is_secret:
			continue
		if rm.is_group_revealed(door.target_room_id) or not rm.is_zone_revealed(door.from_zone_id):
			continue
		door.disable_door()
		world.door_turn_system.open_room(door.target_room_id)
		return true
	return false


func _world() -> Node:
	return _main.world_container.get_child(_main.world_container.get_child_count() - 1)


func _find(from: Node, class_id: String) -> Node:
	for n in from.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s and s.get_global_name() == class_id:
			return n
	return null


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s_%s.png" % [_dir, _cfg, shot_name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

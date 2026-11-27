extends SceneTree

## juego-45: a floor-1 game in a real window (NOT --headless) at 1920x1080 with text x1.5, played
## only through the player's commands (NetCommands move / open_door / build, no forced hints).
## Every hint or refusal the HUD shows is saved as <out_dir>/partida_<n>_<title>.png, with the
## card's rect and its labels' rects printed. Stops once an Invasión, a refusal and a room-type
## hint were seen, or after MAX_DOORS doors.
##   godot --path . --script res://tests/tools/shot_partida.gd -- <out_dir>

const SLOT := 95
const MAX_DOORS := 25
const ROOM_HINTS := ["Descanso", "Botín", "Élite", "Prisionero", "Altar", "Salida", "¡Sala secreta!"]

var _dir: String
var _main: Main
var _hud: HUDController
var _seen: Array[String] = []
var _n := 0
var _busy := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "user://"
	DirAccess.make_dir_recursive_absolute(_dir)
	await process_frame
	await process_frame
	var settings := root.get_node("SettingsManager")
	settings.text_scale = 1.5
	settings.reset_help()
	root.mode = Window.MODE_WINDOWED
	for i in 20:
		await process_frame
	root.size = Vector2i(1920, 1080)
	for i in 20:
		await process_frame
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _wait(3.0)
	root.get_node("SaveManager").load_game(SLOT)
	root.get_node("GameSession").set_selection(["warrior", "mage"] as Array[String])
	await _main.start_gameplay()
	await _wait(1.5)
	_hud = ManagerLocator.get_hud()
	_watch()
	await _play()
	print("seen: ", _seen)
	root.get_node("SaveManager").delete_save(SLOT)
	paused = false
	Engine.time_scale = 1.0
	quit()


func _play() -> void:
	var world: Node = _main.world_container.get_child(_main.world_container.get_child_count() - 1)
	var rm: RoomManager = world.room_manager
	var cmds := root.get_node("NetCommands")
	var tried_build := false
	for d in MAX_DOORS:
		if _done():
			break
		var heroes: Array[String] = []
		for hero: Player in world.heroes:
			if hero.can_accept_input():
				heroes.append(hero.stats.hero_id)
		if heroes.is_empty():
			print("every hero is down")
			break
		var door: Door = null
		for candidate: Door in rm.get_all_doors():
			if not candidate.is_open and not candidate.is_secret and rm.is_zone_revealed(candidate.from_zone_id) and not rm.is_group_revealed(candidate.target_room_id):
				door = candidate
				break
		if door == null:
			print("no door left")
			break
		var err: String = await cmds.request("move", {"heroes": heroes, "zone": door.from_zone_id})
		await _wait(2.5)
		err = await cmds.request("open_door", {"door": door.door_id, "heroes": heroes})
		print("door %d %s -> %s: '%s'" % [d, door.door_id, door.target_room_id, err])
		await _wait(6.0)  # the floor runs: invasions, fights, hints
		if not tried_build:  # a Taller with too little Hierro, through the build command
			tried_build = true
			var res := root.get_node("ResourceManager") as ResourceManager
			res.spend_resource("iron", res.get_resource("iron"))
			var zone: RoomZone = rm.get_zone_node(rm.get_start_zone_id())
			var i := 0
			while zone.get_slot(i) != null and not zone.get_slot(i).is_empty():
				i += 1
			if zone.get_slot(i) != null:
				print("build with 0 Hierro: '%s'" % await cmds.request("build", {"zone": zone.zone_id, "slot": i, "type": Building.BuildingType.FORJA}))
			await _wait(1.5)


func _done() -> bool:
	var invasion := _seen.any(func(t: String) -> bool: return t.begins_with("Invasión"))
	var refusal := _seen.any(func(t: String) -> bool: return t.begins_with("No se puede"))
	var room := _seen.any(func(t: String) -> bool: return ROOM_HINTS.any(func(r: String) -> bool: return t.begins_with(r)))
	return invasion and refusal and room


func _watch() -> void:
	var last := ""
	while true:
		await process_frame
		var panel: Control = _hud._hint_panel
		if panel == null or not panel.visible or _busy:
			continue
		var key: String = _hud._hint_title.text + "|" + _hud._hint_body.text
		if key == last:
			continue
		last = key
		_busy = true
		await _wait(0.4)
		_n += 1
		var title: String = _hud._hint_title.text
		_seen.append(title)
		var file_name := "partida_%02d_%s" % [_n, title.to_lower().replace(" ", "_").replace("¡", "").replace("!", "")]
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [_dir, file_name])
		var ok := true
		for l: Label in [_hud._hint_title, _hud._hint_body]:
			ok = ok and panel.get_global_rect().encloses(l.get_global_rect()) and l.get_visible_line_count() == l.get_line_count()
		print("saved %s: '%s' card %s text inside %s" % [file_name, _hud._hint_body.text, panel.get_global_rect(), ok])
		_busy = false


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	var frames := 0
	while Time.get_ticks_msec() < end or frames < 3:
		await process_frame
		frames += 1

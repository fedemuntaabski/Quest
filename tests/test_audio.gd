extends SceneTree

## audio-18: game audio on the real Main orchestrator.
##  1. Every AudioDirector key (SFX_PATHS, MUSIC_*, each floor's FloorTheme.music_path)
##     points under assets/audio/ and, when the file exists, loads as an AudioStream.
##     Missing files are listed as PENDIENTE; `-- --audio-strict` makes them a FAIL.
##  2. Each event fires its sound exactly once (AudioDirector.fired), driven by the
##     same paths a player's input takes: door click, light, build, chest, hit, tower,
##     invasion alert, Reliquia pickup, victory, defeat.
##  3. Music: menu (and intro), Tutorial = floor 1, extraction theme, next floor, silence on defeat.
##  4. Bus volumes from Opciones reach AudioServer, and the players sit on their buses.
## Two processes over ENet: tests/test_audio_net.gd.
##   godot --headless --path . --script res://tests/test_audio.gd

const HUGE_HP := 100000

var failures: Array[String] = []
var _main: Main
var main2d: Node
var rm: RoomManager
var audio: Node


func _initialize() -> void:
	await process_frame
	audio = root.get_node("AudioDirector")
	_check_files()
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _frames(30)
	_expect(audio.music_path == audio.MUSIC_MENU, "menu plays the menu theme (%s)" % audio.music_path)
	_check_buses()

	await _main.start_tutorial()
	await _frames(10)
	main2d = _main.world_container.get_child(0)
	rm = main2d.room_manager
	_expect(audio.music_path == main2d.floor_manager.theme().music_path and audio.music_path.ends_with("floor_1.ogg"),
		"Tutorial plays floor 1 (%s)" % audio.music_path)
	_tough()
	await _event_door()
	await _event_light()
	await _event_build()
	await _open_all()
	await _event_alert_tower_hit()
	await _event_chest()
	await _event_relic()
	await _event_victory()

	paused = false
	Engine.time_scale = 1.0
	await _main.return_to_main_menu()
	await _frames(10)
	_expect(audio.music_path == audio.MUSIC_MENU, "back to the menu theme (%s)" % audio.music_path)

	await _main.start_gameplay(1)
	await _frames(10)
	_expect(audio.music_path.ends_with("floor_1.ogg"), "a run starts on floor 1 music (%s)" % audio.music_path)
	await _main.advance_floor()
	await _frames(10)
	_expect(audio.music_path.ends_with("floor_2.ogg"), "next floor fades to floor 2 music (%s)" % audio.music_path)
	main2d = _main.world_container.get_child(0)
	await _once(&"defeat", func() -> void: main2d._on_player_died())
	_expect(audio.music_path == "", "defeat stops the music")

	paused = false
	Engine.time_scale = 1.0
	await _main.return_to_main_menu()
	await _frames(10)
	_main.queue_free()
	await _frames(5)
	print("sonidos disparados (clave: veces): ", audio.fired)
	for f in failures:
		printerr("FAIL: ", f)
	print("test_audio: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


# ─── 1. files ─────────────────────────────────────────────────

func _check_files() -> void:
	var strict := "--audio-strict" in OS.get_cmdline_user_args()
	var paths: Dictionary = {}
	for key in audio.SFX_PATHS:
		paths["sfx " + String(key)] = audio.SFX_PATHS[key]
	paths["music menu"] = audio.MUSIC_MENU
	paths["music extraction"] = audio.MUSIC_EXTRACTION
	var curve := load("res://resources/floors/run_curve.tres") as RunCurve
	for f in range(1, 6):
		var theme: FloorTheme = curve.theme(f) if curve else null
		paths["music floor %d" % f] = theme.music_path if theme else ""
	var missing: Array[String] = []
	for label in paths:
		var path: String = paths[label]
		_expect(path.begins_with("res://assets/audio/"), "%s: path under assets/audio (%s)" % [label, path])
		var stream: AudioStream = audio.load_stream(path)
		if stream == null:
			missing.append(path)
		elif stream.get_length() <= 0.0:
			failures.append("%s: %s loads but is empty" % [label, path])
	for path in missing:
		print("PENDIENTE: falta ", path, " (o .wav/.mp3)")
	if strict:
		_expect(missing.is_empty(), "every audio key has a file (%d missing)" % missing.size())


# ─── 2. events ────────────────────────────────────────────────

## Runs `action` and expects `key` fired exactly once more.
func _once(key: StringName, action: Callable, label: String = "") -> void:
	await create_timer(0.1).timeout  # past SFX_MIN_GAP_MSEC of anything before
	var before := int(audio.fired.get(key, 0))
	await action.call()
	await create_timer(0.1).timeout
	var n := int(audio.fired.get(key, 0)) - before
	_expect(n == 1, "%s: '%s' fired %d times (want 1)" % [label if label else String(key), key, n])


func _event_door() -> void:
	var door: Door = null
	for d in rm.get_all_doors():
		if d.from_zone_id == rm.get_start_zone_id():
			door = d
	await _once(&"door", func() -> void:
		door.door_clicked.emit(door)
		await _walk_done(), "door click")


func _event_light() -> void:
	var hub := ""
	for zone_id in rm.get_group_zone_ids("hub_room"):
		if rm.get_zone_kind(zone_id) == "room":
			hub = zone_id
	root.get_node("ResourceManager").add_resource("embers", 100)
	await _once(&"light", func() -> void: rm.get_zone_node(hub).toggle_light(), "light a room")
	var before := int(audio.fired.get(&"light", 0))
	rm.get_zone_node(hub).toggle_light()  # off: refund, no sound
	await create_timer(0.1).timeout
	rm.get_zone_node(hub).toggle_light()
	_expect(int(audio.fired.get(&"light", 0)) - before == 1, "switching off is silent, on again sounds")


func _event_build() -> void:
	root.get_node("ResourceManager").add_resource("iron", 200)
	var menu: BuildingMenu = (_main.hud_container.get_child(0) as HUDController).building_menu
	await _once(&"build", func() -> void:
		menu.open_category(0)
		(menu.options.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
		if not menu._armed_slots.is_empty():
			menu.open_menu(menu._armed_slots[0])
		await process_frame
		menu.close_menu(), "build from the menu")


func _open_all() -> void:
	var opened := true
	while opened:
		opened = false
		for door in rm.get_all_doors():
			if door.is_open or not rm.is_zone_revealed(door.from_zone_id):
				continue
			main2d.door_turn_system.open_room(door.target_room_id)
			door.disable_door()
			opened = true
			await process_frame
	_tough()


func _event_alert_tower_hit() -> void:
	var em: EnemyManager = main2d.enemy_manager
	for e in em.get_enemies():  # the doors' invasions may have reached the cap
		e.queue_free()
	await process_frame
	var spawned := [0]
	await _once(&"alert", func() -> void: spawned[0] = em.spawn_wave(1), "invasion alert")
	_expect(spawned[0] == 1, "spawn_wave(1) spawned %d (dark rooms: %d)" % [spawned[0], em.get_spawn_rooms().size()])
	var enemies := em.get_enemies()
	_expect(not enemies.is_empty(), "the wave spawned an enemy")
	if enemies.is_empty():
		return
	var enemy: Enemy = enemies[0]
	enemy.max_hp = HUGE_HP
	enemy.current_hp = HUGE_HP
	var slot: BuildingSlot = null
	for s in rm.find_children("*", "BuildingSlot", true, false):
		if s.is_empty() and s.slot_type == BuildingSlot.SlotType.MINOR:
			slot = s
	_expect(slot != null, "a free slot for a Ballesta")
	if slot:
		var tower := slot.build(Building.BuildingType.BALLESTA) as DefenseBuilding
		await _frames(6)
		tower.current_targets = [enemy]
		await _once(&"tower", func() -> void: tower._on_fire_timer_timeout(), "tower shot")
	var hero: Player = main2d.heroes[0]
	await _once(&"hit", func() -> void: hero.hitbox.hit_landed.emit(enemy.hurtbox, 1), "hero hit")
	for e in em.get_enemies():
		e.queue_free()
	await process_frame


func _event_chest() -> void:
	var chest := Chest.new()
	chest.setup(ItemCatalog.get_default().items[0], rm.get_start_zone_id())
	main2d.add_child(chest)
	await process_frame
	await _once(&"chest", func() -> void: chest.try_open(), "open a chest")
	chest.queue_free()


func _event_relic() -> void:
	var hero: Player = main2d.heroes[0]
	hero.set_zone(rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()), main2d.floor_layer)
	await _once(&"relic", func() -> void: main2d.relic_controller.confirm_pickup(hero), "take the Reliquia")
	_expect(audio.music_path == audio.MUSIC_EXTRACTION, "extraction theme after the pickup (%s)" % audio.music_path)


func _event_victory() -> void:
	var hero: Player = main2d.heroes[0]
	await _once(&"victory", func() -> void:
		_tough()
		Engine.time_scale = 4.0
		await main2d.player_action_controller.move_heroes([hero] as Array[Player], rm.get_exit_zone_id())
		Engine.time_scale = 1.0
		await _frames(20), "carry the Reliquia out")


# ─── 4. buses ─────────────────────────────────────────────────

func _check_buses() -> void:
	var settings := root.get_node("SettingsManager")
	var saved := [settings.master_volume, settings.music_volume, settings.sfx_volume, settings.ui_volume]
	var props := {"Master": "master_volume", "Music": "music_volume", "SFX": "sfx_volume", "UI": "ui_volume"}
	for bus in props:
		var idx := AudioServer.get_bus_index(bus)
		_expect(idx >= 0, "bus %s exists" % bus)
		settings.set(props[bus], 0.25)
		_expect(is_equal_approx(AudioServer.get_bus_volume_db(idx), linear_to_db(0.25)), "Opciones %s 25%% -> bus %.1f dB" % [bus, AudioServer.get_bus_volume_db(idx)])
	settings.master_volume = saved[0]
	settings.music_volume = saved[1]
	settings.sfx_volume = saved[2]
	settings.ui_volume = saved[3]
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(maxf(saved[1], 0.001))), "music volume restored")
	_expect(audio._music.bus == &"Music", "music player on the Music bus")
	for voice in audio._voices:
		_expect(voice.bus == &"SFX", "%s on the SFX bus" % voice.name)


# ─── helpers ──────────────────────────────────────────────────

func _tough() -> void:
	for hero: Player in main2d.heroes:
		hero.stats.max_hp = HUGE_HP
		hero.stats.current_hp = HUGE_HP
	var relic := ManagerLocator.get_relic()
	if relic:
		relic.max_hp = HUGE_HP
		relic.current_hp = HUGE_HP


func _walk_done() -> void:
	await _frames(2)
	for i in 600:
		if main2d.player_action_controller._busy.is_empty():
			return
		_tough()
		await process_frame


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame

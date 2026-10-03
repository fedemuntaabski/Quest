extends SceneTree

## Tactical pause + speed (session bucle-7): Space pauses, X toggles 1x/2x, the HUD
## label follows, a paused game still accepts a walk order (it runs on resume) but
## opens no doors; the slow/retaliation windows count game time.
##   godot --headless --path . --script res://tests/test_tactical_pause.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	await _run()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_tactical_pause: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run() -> void:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.standalone_floor = 1
	root.add_child(main2d)
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false
	var pause: PauseController = main2d.pause_controller
	var rm: RoomManager = main2d.room_manager
	var controller: PlayerActionController = main2d.player_action_controller
	var doors: DoorTurnSystem = main2d.door_turn_system

	_expect(Engine.time_scale == 1.0 and not hud.pause_label.visible, "starts at 1x without a banner")
	pause.toggle_speed()
	_expect(Engine.time_scale == 2.0 and pause.get_speed() == 2 and hud.pause_label.visible and hud.pause_label.text == "2x", "X: 2x and the banner says so (%f '%s')" % [Engine.time_scale, hud.pause_label.text])
	pause.toggle()
	_expect(Engine.time_scale == 0.0 and pause.is_paused() and hud.pause_label.text.begins_with("PAUSA"), "Space freezes the game")
	pause.toggle_speed()
	_expect(Engine.time_scale == 0.0 and pause.get_speed() == 1, "changing the speed in pause keeps it frozen")
	pause.toggle()
	_expect(Engine.time_scale == 1.0 and not hud.pause_label.visible, "resume runs at the chosen speed (1x, no banner)")
	pause.toggle_speed()
	_expect(Engine.time_scale == 2.0, "back to 2x")
	pause.toggle_speed()

	# --- orders while paused: a walk is accepted but frozen, doors stay shut ---
	for group_id in doors.rooms.keys():
		doors.rooms[group_id]["visited"] = true
	rm.refresh_visibility()
	controller.refresh_zones()
	var hero: Player = main2d.heroes[0]
	var start := rm.get_start_zone_id()
	var neighbor := ""
	for zone_id: String in rm.get_zone(start)["neighbors"]:
		neighbor = zone_id
		break
	var before := hero.global_position
	var turn_before := doors.current_turn
	pause.toggle()
	controller._on_zone_clicked(neighbor)
	_expect(controller._action_in_flight, "a walk order given in pause should be accepted")
	await process_frame  # time_scale reaches the engine loop one frame late
	var frozen_at := hero.global_position
	for i in 5:
		await process_frame
	_expect(hero.global_position == frozen_at, "the paused hero should not move")

	var door: Door = rm.get_all_doors()[0]
	door.is_open = false
	var in_flight := controller._action_in_flight
	controller._action_in_flight = false
	controller._open_group(door)
	_expect(doors.current_turn == turn_before, "a door opened during the pause (turn %d -> %d)" % [turn_before, doors.current_turn])
	controller._action_in_flight = in_flight

	# --- resume: the order runs ---
	pause.toggle()
	for i in 12:
		await process_frame
	_expect(hero.global_position != before, "the walk should run once the game resumes")

	# --- slow / retaliation windows follow game time ---
	Engine.time_scale = 0.0
	await process_frame  # time_scale reaches the engine loop one frame late
	var start_msec := Enemy.game_msec()
	await process_frame
	await process_frame
	_expect(Enemy.game_msec() == start_msec, "game_msec should not advance at time_scale 0")
	Engine.time_scale = 1.0
	await process_frame
	await process_frame
	await process_frame
	_expect(Enemy.game_msec() > start_msec, "game_msec should advance at time_scale 1")

	hud.free()
	main2d.queue_free()
	await process_frame

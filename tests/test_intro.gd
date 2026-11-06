extends SceneTree

## intro-tutorial-17: the premise screen, on the real Main orchestrator.
##   1. A new run's first floor waits on the intro; "Saltar" lets the floor load.
##   2. Once seen it never comes back (same first-time help store, id "intro").
##   3. Esc skips it; the Options switch silences it.
##   4. --script never spends it on disk, and Main.play_intro is off by default.
##   godot --headless --path . --script res://tests/test_intro.gd

const MAIN_PATH := "res://scenes/Main.tscn"

var failures: Array[String] = []
var _main: Main
var settings: Node


func _initialize() -> void:
	settings = root.get_node("SettingsManager")
	await process_frame
	_expect(not settings.help_persist, "--script runs must not persist the seen intro")
	var disk_before := _disk_seen()
	_main = (load(MAIN_PATH) as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _frames(20)
	_expect(not _main.play_intro, "play_intro must be off under --script (tests would wait on it)")
	_main.play_intro = true
	settings.reset_help()
	root.get_node("GameSession").set_selection(["warrior", "mage"] as Array[String])

	await _check_shown_and_skipped()
	await _check_seen_once()
	await _check_esc_and_switch()
	_expect(_disk_seen() == disk_before, "the intro reached user://first_help.cfg under --script")

	paused = false
	Engine.time_scale = 1.0
	await _main.return_to_main_menu()
	await _frames(10)
	_main.queue_free()
	await _frames(5)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_intro: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _disk_seen() -> PackedStringArray:
	var cfg := ConfigFile.new()
	if cfg.load(settings.HELP_PATH) != OK:
		return PackedStringArray()
	return cfg.get_value("help", "seen", PackedStringArray())


func _has_world() -> bool:
	return _main.world_container.get_child_count() > 0 and not _main.world_container.get_child(0).is_queued_for_deletion()


func _wait_for(cond: Callable, max_frames: int = 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return false


func _check_shown_and_skipped() -> void:
	_main.start_gameplay()
	var shown := await _wait_for(func() -> bool: return _main.intro_screen != null)
	_expect(shown, "a new run did not show the intro")
	if not shown:
		return
	var intro := _main.intro_screen
	_expect(not _has_world(), "the floor loaded under the intro")
	_expect("cinco reliquias" in intro.paragraphs[0].text, "the premise does not tell the five relics")
	_expect(intro.button.text == "Saltar", "the intro button is not 'Saltar' at first")
	_expect(not settings.should_show_help(IntroScreen.HELP_ID), "the intro was not marked seen")
	intro.button.pressed.emit()
	_expect(await _wait_for(_has_world), "skipping the intro did not load the floor")
	await _wait_for(func() -> bool: return not _main._is_transitioning)


func _check_seen_once() -> void:
	await _main.return_to_main_menu()
	_main.start_gameplay()
	var shown := await _wait_for(func() -> bool: return _main.intro_screen != null or _has_world())
	_expect(shown and _main.intro_screen == null, "the intro came back on a second run")
	await _wait_for(func() -> bool: return not _main._is_transitioning)


func _check_esc_and_switch() -> void:
	settings.reset_help()
	await _main.return_to_main_menu()
	_main.start_gameplay()
	if not await _wait_for(func() -> bool: return _main.intro_screen != null):
		failures.append("reset_help did not bring the intro back")
		return
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	_expect(await _wait_for(_has_world, 120), "Esc did not skip the intro")
	await _wait_for(func() -> bool: return not _main._is_transitioning)

	settings.reset_help()
	settings.first_help_enabled = false
	await _main.return_to_main_menu()
	_main.start_gameplay()
	await _wait_for(func() -> bool: return _main.intro_screen != null or _has_world())
	_expect(_main.intro_screen == null, "the Options switch does not silence the intro")
	await _wait_for(func() -> bool: return not _main._is_transitioning)
	settings.first_help_enabled = true

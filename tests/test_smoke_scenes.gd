extends SceneTree

## Session calidad-13: smoke test of every main screen through the real Main
## orchestrator, with a clean console (ErrorProbe: no ERROR / WARNING).
##   main menu -> options (every tab) -> slot list -> hero select -> floor ->
##   pause menu (+ controls help) -> resume -> defeat overlay -> retry ->
##   victory overlay -> back to the main menu
##   godot --headless --path . --script res://tests/test_smoke_scenes.gd

const MAIN_PATH := "res://scenes/Main.tscn"
const SLOT := 92

var failures: Array[String] = []
var _main: Main
var _probe: ErrorProbe


func _initialize() -> void:
	_probe = ErrorProbe.install()
	_main = (load(MAIN_PATH) as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _frames(30)
	await _test_menu()
	await _test_floor()
	await _test_pause()
	await _test_defeat()
	await _test_victory()
	_main.queue_free()
	await _frames(5)
	_probe.uninstall()
	for m in _probe.messages:
		failures.append("console: " + m)
	root.get_node("SaveManager").delete_save(SLOT)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_smoke_scenes: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _main2d() -> Node:
	return _main.world_container.get_child(0) if _main.world_container.get_child_count() > 0 else null


func _test_menu() -> void:
	var menu := _menu()
	_expect(menu != null and menu.visible, "main menu shown at boot")
	if menu == null:
		return
	var options: OptionsMenu = menu.find_child("OptionsMenu", true, false)
	_expect(options != null, "options menu present")
	if options:
		await options.open()
		for tab in options.options_tabs.get_tab_count():
			options.options_tabs.current_tab = tab
			await process_frame
		_expect(options.options_tabs.get_tab_count() == 5, "options tabs: %d (Video, Audio, Jugabilidad, Accesibilidad, Controles)" % options.options_tabs.get_tab_count())
		await options.close(false)
	var flow: MainMenuFlow = menu.flow if "flow" in menu else null
	if flow and flow.slot_selector:
		flow.slot_selector.open()
		await _frames(5)
		_expect(flow.slot_selector.visible, "slot list opens")
		flow.slot_selector.close(false)
	if flow and flow.hero_select:
		flow.hero_select.open()
		await _frames(5)
		_expect(flow.hero_select.visible, "hero select opens")
		flow.hero_select.close(false)


func _test_floor() -> void:
	root.get_node("SaveManager").load_game(SLOT)
	var session := root.get_node("GameSession")
	session.set_selection(["warrior", "mage"] as Array[String])
	await _main.start_gameplay()
	await _frames(10)
	var main2d := _main2d()
	_expect(main2d != null and main2d.heroes.size() == 2, "floor booted with 2 heroes")
	_expect(_main.hud_container.get_child_count() == 1, "HUD present")


func _test_pause() -> void:
	var main2d := _main2d()
	if main2d == null:
		return
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	main2d._input(esc)
	await _frames(10)
	_expect(main2d.pause_menu.is_open and paused, "Esc opens the pause menu and pauses")
	_expect(main2d.pause_menu.controls_button != null, "pause menu has Controles")
	main2d.pause_menu.controls_help.open()
	await process_frame
	_expect(main2d.pause_menu.controls_help.visible, "controls help opens from pause")
	main2d.pause_menu.controls_help.hide()
	main2d._input(esc)
	await create_timer(0.6).timeout
	_expect(not main2d.pause_menu.is_open and not paused, "Esc again resumes")


func _test_defeat() -> void:
	var main2d := _main2d()
	if main2d == null:
		return
	main2d._on_player_died()
	await _frames(20)
	_expect(main2d.death_overlay.visible, "defeat overlay shown")
	await _main.reload_gameplay()
	await _frames(10)
	_expect(_main2d() != null and _main2d() != main2d and not paused, "retry boots a new floor")


func _test_victory() -> void:
	var main2d := _main2d()
	if main2d == null:
		return
	ManagerLocator.get_extraction_manager().declare_victory()
	await _frames(20)
	_expect(main2d.victory_overlay.visible, "victory overlay shown")
	await _main.return_to_main_menu()
	await _frames(10)
	_expect(_menu() != null and _main.world_container.get_child_count() == 0, "back at the main menu")


func _menu() -> Node:
	for child in _main.ui_container.get_children():
		if child.get("flow") != null or child.name == "MainMenu":
			return child
	return null

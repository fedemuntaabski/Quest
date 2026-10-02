extends SceneTree

## Main2d must boot COMPLETE under --script: pause menu, death/victory overlays,
## retry button and their handlers resolved (they used to be null when an autoload
## identifier broke the PauseMenu compile). Then pause/death/victory presentation.
##   godot --headless --path . --script res://tests/test_main2d_overlays.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame

	_expect(main2d.pause_menu != null, "pause_menu not resolved")
	_expect(main2d.death_overlay != null, "death_overlay not resolved")
	_expect(main2d.victory_overlay != null, "victory_overlay not resolved")
	_expect(main2d.retry_button != null, "retry_button not resolved")
	_expect(main2d.death_handler != null and main2d.death_handler.death_overlay == main2d.death_overlay, "death handler has no overlay")
	_expect(main2d.victory_handler != null, "victory handler missing")
	if failures.is_empty():
		_expect(not main2d.death_overlay.visible and not main2d.victory_overlay.visible, "overlays visible at start")
		_expect(main2d.retry_button.pressed.get_connections().size() > 0, "retry button not connected")
		_expect(main2d.pause_menu.exit_requested.get_connections().size() > 0, "pause menu exit not connected")

		var gsm: GameStateManager = main2d.game_state_manager
		gsm.request_pause()
		_expect(paused and gsm.current_state == GameStateManager.State.PAUSED, "request_pause did not pause the tree")
		gsm.request_resume()
		_expect(not paused and gsm.is_active(), "request_resume did not resume")

		main2d._on_victory()
		_expect(main2d.victory_overlay.visible, "victory overlay not shown")
		main2d.victory_overlay.visible = false
		main2d._on_player_died()
		_expect(gsm.is_dead() and main2d.death_overlay.visible, "death did not show the overlay")
		paused = false

	main2d.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_main2d_overlays: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

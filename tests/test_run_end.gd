extends SceneTree

## End of run (progresion-10) over a live Main2d:
##   - defeat (every hero down): DeathOverlay shows the RunSummary (floors, time,
##     kills, items, fallen heroes, new bestiary entries), "Nueva run" + "Volver al menú",
##     and the run lands in the slot's records
##   - victory on the final floor: summary + "Nueva run" / "Volver al menú", no "Descender"
##   - victory on an earlier floor: "Descender", no summary
##   - run time only counts while the run is ACTIVE; reset_run clears the stats
##   godot --headless --path . --script res://tests/test_run_end.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const SLOT := 94

var failures: Array[String] = []
var _session: Node
var _save: Node


func _initialize() -> void:
	_session = root.get_node("GameSession")
	_save = root.get_node("SaveManager")
	_save.delete_save(SLOT)
	_save.load_game(SLOT)
	await _test_defeat()
	await _test_final_victory()
	await _test_floor_victory()
	_test_reset()
	_save.slot_loaded = false
	_save.current_slot = 1
	_save.delete_save(SLOT)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_run_end: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _live_main2d(floor_index: int) -> Node:
	paused = false
	_session.reset_run()
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.standalone_floor = floor_index
	root.add_child(main2d)
	await process_frame
	await process_frame
	return main2d


func _summary_text(summary: RunSummary) -> String:
	var parts: Array[String] = []
	for child in summary.get_children():
		if child is Label and not child.is_queued_for_deletion():
			parts.append(child.text)
	return "\n".join(parts)


func _test_defeat() -> void:
	var main2d := await _live_main2d(2)
	for i in 3:
		await process_frame
	_expect(float(_session.run_stats["elapsed_sec"]) > 0.0, "run time grows while ACTIVE")
	_session.add_stat("kills", 7)
	_session.add_stat("items", 2)
	_session.add_stat("bestiary_new", 3)
	for hero in main2d.heroes:
		hero.stats.take_damage(99999)
	await process_frame
	var overlay: DeathOverlay = main2d.death_overlay
	_expect(overlay.visible, "death overlay shown when every hero is down")
	var text := _summary_text(overlay.summary)
	for needle in ["Dificultad: Normal", "llegaste al 2", "Tiempo: ", "Enemigos derrotados: 7", "Objetos obtenidos: 2", "Registros nuevos del bestiario: 3", "Héroes caídos: "]:
		_expect(text.contains(needle), "defeat summary lacks '%s':\n%s" % [needle, text])
	_expect(not text.contains("Héroes caídos: ninguno"), "every hero fell: the summary must name them")
	_expect(overlay._retry_button.text == "Nueva run" and overlay._exit_button.text == "Volver al menú", "defeat buttons: %s / %s" % [overlay._retry_button.text, overlay._exit_button.text])
	var rec: Dictionary = _save.get_records("normal")
	_expect(int(rec.get("runs", 0)) == 1 and int(rec.get("best_floor", 0)) == 2 and int(rec.get("victories", 0)) == 0, "defeat recorded: %s" % rec)
	var frozen := float(_session.run_stats["elapsed_sec"])
	await process_frame
	await process_frame
	_expect(is_equal_approx(frozen, float(_session.run_stats["elapsed_sec"])), "run time stops once the run is over")
	main2d.queue_free()
	await process_frame


func _test_final_victory() -> void:
	var main2d := await _live_main2d(5)
	main2d.extraction_manager.declare_victory()
	await process_frame
	var overlay: VictoryOverlay = main2d.victory_overlay
	_expect(overlay.visible and overlay.summary.visible, "final victory shows the summary")
	_expect(overlay._new_run_button.visible and overlay._return_button.visible and not overlay._next_floor_button.visible, "final victory: Nueva run + menu, no Descender")
	var text := _summary_text(overlay.summary)
	_expect(text.contains("superaste 1") and text.contains("llegaste al 5"), "victory summary floors:\n%s" % text)
	var rec: Dictionary = _save.get_records("normal")
	_expect(int(rec.get("victories", 0)) == 1 and int(rec.get("runs", 0)) == 2, "victory recorded: %s" % rec)
	_expect(text.contains("¡Nuevo récord! Piso más profundo"), "deeper than the first run = new record:\n%s" % text)
	main2d.queue_free()
	await process_frame


func _test_floor_victory() -> void:
	var main2d := await _live_main2d(1)
	main2d.extraction_manager.declare_victory()
	await process_frame
	var overlay: VictoryOverlay = main2d.victory_overlay
	_expect(overlay.visible and not overlay.summary.visible, "floor 1 cleared: no run summary")
	_expect(overlay._next_floor_button.visible and not overlay._new_run_button.visible, "floor 1 cleared: Descender only")
	_expect(int(_save.get_records("normal").get("runs", 0)) == 2, "a cleared floor is not a finished run")
	main2d.queue_free()
	await process_frame
	paused = false


func _test_reset() -> void:
	_session.add_stat("kills", 3)
	_session.reset_run()
	_expect(int(_session.run_stats["kills"]) == 0 and float(_session.run_stats["elapsed_sec"]) == 0.0 and int(_session.run_stats["floor_reached"]) == 1, "reset_run clears the run stats")

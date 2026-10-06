extends SceneTree

## Per-slot run records (progresion-10, SaveManager.record_run/get_records):
##   - records live in [records] of the slot file, one Dictionary per difficulty
##   - the first run of a difficulty sets the marks but beats nothing
##   - later runs report exactly the marks they beat (best floor, kills, fastest win)
##   - two slots stay apart; the [bestiary] and [save_data] sections survive
##   - nothing is written while no slot is loaded
##   godot --headless --path . --script res://tests/test_run_records.gd

const SLOT_A := 95
const SLOT_B := 96

var failures: Array[String] = []
var _save: Node


func _initialize() -> void:
	_save = root.get_node("SaveManager")
	for slot in [SLOT_A, SLOT_B]:
		_save.delete_save(slot)
	_test_needs_slot()
	_test_records()
	_test_slots_apart()
	_save.slot_loaded = false
	_save.current_slot = 1
	for slot in [SLOT_A, SLOT_B]:
		_save.delete_save(slot)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_run_records: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run(floor_reached: int, kills: int, victory: bool, time: float, difficulty: String = "normal") -> Dictionary:
	return {"floor_reached": floor_reached, "floors_cleared": floor_reached - (0 if victory else 1), "kills": kills,
		"victory": victory, "elapsed_sec": time, "difficulty": difficulty, "items": 0, "bestiary_new": 0}


func _test_needs_slot() -> void:
	_save.slot_loaded = false
	_save.current_slot = SLOT_A
	var beaten: Array[String] = _save.record_run(_run(3, 10, false, 100.0))
	_expect(beaten.is_empty() and not _save.has_save(SLOT_A), "no slot loaded: nothing recorded")


func _test_records() -> void:
	_save.load_game(SLOT_A)
	_save.save_game(SLOT_A)
	var bestiary := root.get_node("BestiaryService")
	bestiary.register_seen(load("res://resources/enemies/goblin.tres"), 1)
	_save.save_game(SLOT_A)
	var with_bestiary := ConfigFile.new()
	with_bestiary.load(_save.get_save_path(SLOT_A))
	_expect(with_bestiary.has_section("bestiary"), "bestiary written before the runs")

	var first: Array[String] = _save.record_run(_run(2, 5, false, 300.0))
	_expect(first.is_empty(), "first run beats nothing: %s" % [first])
	var rec: Dictionary = _save.get_records("normal")
	_expect(int(rec.get("runs", 0)) == 1 and int(rec.get("best_floor", 0)) == 2 and int(rec.get("most_kills", 0)) == 5 and int(rec.get("victories", 0)) == 0, "first marks: %s" % rec)

	var second: Array[String] = _save.record_run(_run(4, 3, false, 200.0))
	_expect(second.size() == 1 and second[0] == "best_floor", "deeper run beats only best_floor: %s" % [second])

	var win: Array[String] = _save.record_run(_run(5, 30, true, 900.0))
	_expect(win.has("best_floor") and win.has("most_kills") and win.has("fastest_victory_sec"), "winning run: %s" % [win])
	var slow_win: Array[String] = _save.record_run(_run(5, 1, true, 1200.0))
	_expect(slow_win.is_empty(), "slower win beats nothing: %s" % [slow_win])
	rec = _save.get_records("normal")
	_expect(int(rec["runs"]) == 4 and int(rec["victories"]) == 2 and is_equal_approx(float(rec["fastest_victory_sec"]), 900.0), "after 4 runs: %s" % rec)

	var hard_first: Array[String] = _save.record_run(_run(1, 0, false, 50.0, "hard"))
	_expect(hard_first.is_empty() and int(_save.get_records("hard").get("runs", 0)) == 1 and int(_save.get_records("normal")["runs"]) == 4, "difficulties kept apart")

	# Reload from disk: records + the other sections are still there.
	_save.load_game(SLOT_A)
	_expect(int(_save.get_records("normal")["victories"]) == 2, "records survive a reload")
	var cfg := ConfigFile.new()
	cfg.load(_save.get_save_path(SLOT_A))
	_expect(cfg.has_section("save_data") and cfg.has_section("bestiary"), "[save_data] and [bestiary] kept next to [records]")
	_save.save_game(SLOT_A)
	cfg.load(_save.get_save_path(SLOT_A))
	_expect(cfg.has_section("records"), "save_game keeps [records]")


func _test_slots_apart() -> void:
	_save.load_game(SLOT_B)
	_expect(_save.get_records("normal").is_empty(), "slot B starts without records")
	_save.record_run(_run(1, 2, false, 10.0))
	_expect(int(_save.get_records("normal")["runs"]) == 1, "slot B has its own run")
	_expect(int(_save.get_records("normal", SLOT_A)["runs"]) == 4, "slot A untouched by slot B")

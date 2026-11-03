extends SceneTree

## Session calidad-13: save robustness.
##   - save/load round trip (version written, playtime/hero kept)
##   - v1 -> v2 migration of a fixture (legacy keys dropped, records kept)
##   - atomic write: no .tmp left, .bak = previous version
##   - corrupt file with a backup -> restored + save_corrupted(restored = true)
##   - corrupt file without a backup -> fresh slot, .corrupt kept, signal(false)
##   - crash between remove and rename (.tmp only) -> recovered
##   - settings.cfg corrupt -> defaults
##   godot --headless --path . --script res://tests/test_save.gd

const SLOT := 93

var failures: Array[String] = []
var _save: Node
var _events: Array = []


func _initialize() -> void:
	_save = root.get_node("SaveManager")
	_save.save_corrupted.connect(func(slot: int, restored: bool) -> void: _events.append([slot, restored]))
	_save.delete_save(SLOT)
	_test_roundtrip()
	_test_migration()
	_test_pre_medieval_slot()
	_test_atomic()
	_test_corrupt_with_backup()
	_test_corrupt_without_backup()
	_test_tmp_recovery()
	_test_settings_corrupt()
	_save.delete_save(SLOT)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_save: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _path() -> String:
	return _save.get_save_path(SLOT)


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _test_roundtrip() -> void:
	_save.load_game(SLOT)
	_expect(_save.last_load_status == SafeConfig.Status.MISSING, "fresh slot is MISSING")
	_save.selected_character_id = "mage"
	_save.playtime_seconds = 123.0
	_save.save_game(SLOT)
	_save.selected_character_id = ""
	_save.load_game(SLOT)
	_expect(_save.selected_character_id == "mage", "hero kept: %s" % _save.selected_character_id)
	_expect(_save.playtime_seconds >= 123.0, "playtime kept: %s" % _save.playtime_seconds)
	var cfg := ConfigFile.new()
	cfg.load(_path())
	_expect(int(cfg.get_value("save_data", "version", 0)) == _save.SAVE_VERSION, "version written")


func _test_migration() -> void:
	_save.delete_save(SLOT)
	_write_raw(_path(), "[save_data]\nbase_hp=60\nselected_character_id=\"rogue\"\nrun_cycle=3\ngold=250\n\n[records]\nnormal={\"runs\": 2, \"victories\": 1}\n")
	var fixture := ConfigFile.new()
	fixture.load(_path())
	var from: int = _save.migrate(fixture)
	_expect(from == 1, "unversioned file is v1 (got %d)" % from)
	_expect(not fixture.has_section_key("save_data", "run_cycle") and not fixture.has_section_key("save_data", "gold"), "legacy keys dropped")
	_expect(int(fixture.get_value("save_data", "version")) == _save.SAVE_VERSION, "migrated to SAVE_VERSION")
	_save.load_game(SLOT)
	_expect(_save.selected_character_id == "rogue", "v1 slot loads")
	_expect(int(_save.get_records("normal", SLOT).get("runs", 0)) == 2, "records survive migration")
	_save.save_game(SLOT)
	var cfg := ConfigFile.new()
	cfg.load(_path())
	_expect(not cfg.has_section_key("save_data", "gold") and int(cfg.get_value("save_data", "version", 0)) == _save.SAVE_VERSION, "saved file is v%d without legacy keys" % _save.SAVE_VERSION)


## medieval-15 renamed resources/buildings/the Relic, but a slot holds none of those
## names: a slot written before the rename (v2, hero id "tank") must load untouched.
func _test_pre_medieval_slot() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save_data", "version", 2)
	cfg.set_value("save_data", "base_hp", 120)
	cfg.set_value("save_data", "selected_character_id", "tank")
	cfg.set_value("save_data", "first_time_player", false)
	cfg.set_value("save_data", "playtime_seconds", 321.0)
	cfg.set_value("records", "normal", {"runs": 3, "victories": 1, "best_floor": 4, "most_kills": 50, "fastest_victory_sec": 900.0})
	cfg.set_value("bestiary", "goblin", {"seen": 1, "kills": 3})
	_expect(cfg.save(_save.get_save_path(SLOT)) == OK, "pre-medieval fixture written")
	_save.load_game(SLOT)
	_expect(_save.get_selected_character_id() == "tank", "old hero id survives (%s)" % _save.get_selected_character_id())
	_expect(is_equal_approx(_save.playtime_seconds, 321.0), "old playtime survives")
	_expect(int(_save.read_slot(SLOT).get_value("records", "normal", {}).get("best_floor", 0)) == 4, "old records survive")
	_expect(CharacterDatabase.get_by_id("tank").display_name == "Paladín", "the old hero id is the Paladin")
	_save.delete_save(SLOT)


func _test_atomic() -> void:
	_save.selected_character_id = "warrior"
	_save.save_game(SLOT)
	_save.selected_character_id = "tank"
	_save.save_game(SLOT)
	_expect(not FileAccess.file_exists(_path() + ".tmp"), "no .tmp left after save")
	var bak := ConfigFile.new()
	_expect(bak.load(_path() + ".bak") == OK and bak.get_value("save_data", "selected_character_id") == "warrior", ".bak holds the previous save")


func _test_corrupt_with_backup() -> void:
	_events.clear()
	_write_raw(_path(), "[save_data\n@@@ garbage = = =")
	_save.load_game(SLOT)
	_expect(_save.last_load_status == SafeConfig.Status.RESTORED, "corrupt + backup -> RESTORED (got %d)" % _save.last_load_status)
	_expect(_events == [[SLOT, true]], "save_corrupted(slot, true): %s" % [_events])
	_expect(_save.selected_character_id == "warrior", "backup data loaded")
	_expect(FileAccess.file_exists(_path() + ".corrupt"), "damaged file kept as .corrupt")


func _test_corrupt_without_backup() -> void:
	_save.delete_save(SLOT)
	_events.clear()
	_write_raw(_path(), "[save_data\nbase_hp=")  # truncated mid-write
	_save.load_game(SLOT)
	_expect(_save.last_load_status == SafeConfig.Status.CORRUPT, "corrupt, no backup -> CORRUPT")
	_expect(_events == [[SLOT, false]], "save_corrupted(slot, false): %s" % [_events])
	_expect(_save.first_time_player, "fresh slot after unrecoverable file")
	_expect(FileAccess.file_exists(_path() + ".corrupt") and not FileAccess.file_exists(_path()), "damaged file moved, not overwritten")


func _test_tmp_recovery() -> void:
	_save.delete_save(SLOT)
	_write_raw(_path() + ".tmp", "[save_data]\nselected_character_id=\"mage\"\nversion=2\n")
	_save.load_game(SLOT)
	_expect(_save.last_load_status == SafeConfig.Status.OK and _save.selected_character_id == "mage", "complete .tmp recovered")
	_expect(FileAccess.file_exists(_path()) and not FileAccess.file_exists(_path() + ".tmp"), ".tmp renamed into place")


func _test_settings_corrupt() -> void:
	var path := "user://test_settings_calidad.cfg"
	SafeConfig.remove(path)
	_write_raw(path, "[audio\nmaster_volume=1")
	var cfg := ConfigFile.new()
	_expect(SafeConfig.load_into(cfg, path) == SafeConfig.Status.CORRUPT, "settings-style corrupt file -> CORRUPT")
	_expect(cfg.get_sections().is_empty(), "corrupt load leaves an empty config (defaults)")
	cfg.set_value("a", "b", 1)
	_expect(SafeConfig.save(cfg, path) == OK, "SafeConfig.save writes")
	var back := ConfigFile.new()
	_expect(SafeConfig.load_into(back, path) == SafeConfig.Status.OK and back.get_value("a", "b") == 1, "round trip")
	SafeConfig.remove(path)

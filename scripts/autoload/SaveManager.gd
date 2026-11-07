extends Node

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")
const CharacterDatabase = preload("res://scripts/core/stats/CharacterDatabase.gd")

## SaveManager — Autoload singleton
## Responsibilities:
## - Persist per-slot data to `user://slot_<id>.cfg`: base HP, selected hero,
##   playtime, flags and (session impl-6) the bestiary, the only progress that
##   outlives a run.
## - Slot management (load/save/delete).
## save_game() starts from the slot's existing file and overwrites its keys, so
## a section it does not own (a bestiary of a slot that was never loaded) survives.

const SAVE_PATH_TEMPLATE := "user://slot_%d.cfg"
const SAVE_SECTION := "save_data"
## calidad-13: format version in [save_data] version; files without it are v1.
## Bump it and add a step to _migrate() whenever the format changes.
const SAVE_VERSION := 3
## Keys of older formats, dropped by the v1 -> v2 migration.
const LEGACY_KEYS := ["run_cycle", "contracts_completed", "post_victory_popup_pending", "active_upgrades", "gold"]

## A slot file could not be read: restored = its backup was used, else it started
## fresh (the damaged file is kept as slot_N.cfg.corrupt). SlotSelection shows it.
signal save_corrupted(slot: int, restored: bool)

var current_slot: int = 1
## SafeConfig.Status of the last read_slot() (tests and the slot menu read it).
var last_load_status: int = SafeConfig.Status.OK
## True once load_game() ran: autosaves (bestiary) only write after a slot was picked.
var slot_loaded: bool = false
var first_time_player: bool = true

var selected_character_id: String = ""
var playtime_seconds: float = 0.0
var _session_start_msec: int = 0


func _ready() -> void:
	_session_start_msec = Time.get_ticks_msec()
	QuestLogger.info(QuestLogger.Category.SAVE, "Initialized.")


func get_save_path(slot: int = current_slot) -> String:
	return SAVE_PATH_TEMPLATE % slot


func get_selected_character_id() -> String:
	return selected_character_id if selected_character_id != "" else CharacterDatabase.get_default_id()


func apply_character_selection(character_id: String) -> void:
	var data := CharacterDatabase.get_by_id(character_id)
	selected_character_id = data.character_id

	var player_stats_autoload = ManagerLocator.get_player_stats()
	if player_stats_autoload:
		player_stats_autoload.base_hp = data.base_hp
		player_stats_autoload.refresh_stats()

	save_game(current_slot)


## The slot's file, migrated to SAVE_VERSION (missing: empty; corrupt: backup or
## empty + save_corrupted). Every reader goes through here.
func read_slot(slot: int) -> ConfigFile:
	var cfg := ConfigFile.new()
	last_load_status = SafeConfig.load_into(cfg, get_save_path(slot))
	if last_load_status == SafeConfig.Status.RESTORED or last_load_status == SafeConfig.Status.CORRUPT:
		var restored := last_load_status == SafeConfig.Status.RESTORED
		QuestLogger.warn(QuestLogger.Category.SAVE, "Slot %d was damaged: %s." % [slot, "backup restored" if restored else "started fresh, kept as .corrupt"])
		save_corrupted.emit(slot, restored)
	if last_load_status != SafeConfig.Status.MISSING:
		migrate(cfg)
	return cfg


## Upgrades `cfg` in place to SAVE_VERSION, one step per version; returns the
## version it had. Static so tests can feed fixtures.
static func migrate(cfg: ConfigFile) -> int:
	var from := int(cfg.get_value(SAVE_SECTION, "version", 1))
	if from < 2:  # v1 (pre calidad-13): drop dead keys
		for key in LEGACY_KEYS:
			if cfg.has_section_key(SAVE_SECTION, key):
				cfg.erase_section_key(SAVE_SECTION, key)
	if from < 3:  # v2 (pre guardado-19): [run] did not exist; a stray one is not ours
		if cfg.has_section(RUN_SECTION):
			cfg.erase_section(RUN_SECTION)
	# next step: if from < 4: ...
	cfg.set_value(SAVE_SECTION, "version", SAVE_VERSION)
	return from


func _write(cfg: ConfigFile, slot: int) -> Error:
	cfg.set_value(SAVE_SECTION, "version", SAVE_VERSION)
	var err := SafeConfig.save(cfg, get_save_path(slot))
	if err != OK:
		QuestLogger.error(QuestLogger.Category.SAVE, "Failed to save to slot %d (Error code: %d)." % [slot, err])
	return err


func save_game(slot: int = current_slot) -> void:
	var cfg := read_slot(slot)  # keep whatever this call does not own (missing file: empty)

	var now_msec := Time.get_ticks_msec()
	playtime_seconds += (now_msec - _session_start_msec) / 1000.0
	_session_start_msec = now_msec

	var player_stats_autoload = ManagerLocator.get_player_stats()
	var base_hp: int = player_stats_autoload.base_hp if player_stats_autoload else CharacterDatabase.get_by_id(get_selected_character_id()).base_hp
	cfg.set_value(SAVE_SECTION, "base_hp", clampi(base_hp, StatBalance.PLAYER_BASE_HP, StatBalance.PLAYER_MAX_HP))
	cfg.set_value(SAVE_SECTION, "selected_character_id", selected_character_id)
	cfg.set_value(SAVE_SECTION, "first_time_player", first_time_player)
	cfg.set_value(SAVE_SECTION, "saved_at_unix", Time.get_unix_time_from_system())
	cfg.set_value(SAVE_SECTION, "playtime_seconds", playtime_seconds)

	var bestiary := ManagerLocator.get_bestiary()
	if bestiary and bestiary.slot == slot:
		bestiary.write_to(cfg)

	if _write(cfg, slot) == OK:
		QuestLogger.info(QuestLogger.Category.SAVE, "Saved successfully to slot %d." % slot)


func load_game(slot: int = current_slot) -> void:
	current_slot = slot
	slot_loaded = true
	var cfg := read_slot(slot)
	var err := OK if last_load_status in [SafeConfig.Status.OK, SafeConfig.Status.RESTORED] else ERR_FILE_NOT_FOUND

	var player_stats_autoload = ManagerLocator.get_player_stats()
	var bestiary := ManagerLocator.get_bestiary()
	if bestiary:
		bestiary.reset()
		bestiary.slot = slot

	if err == OK:
		QuestLogger.info(QuestLogger.Category.SAVE, "Loaded save from slot %d." % slot)
		first_time_player = bool(cfg.get_value(SAVE_SECTION, "first_time_player", false))
		selected_character_id = str(cfg.get_value(SAVE_SECTION, "selected_character_id", CharacterDatabase.get_default_id()))
		playtime_seconds = float(cfg.get_value(SAVE_SECTION, "playtime_seconds", 0.0))
		_session_start_msec = Time.get_ticks_msec()
		if bestiary:
			bestiary.read_from(cfg)

		if player_stats_autoload:
			var loaded_base_hp := int(cfg.get_value(SAVE_SECTION, "base_hp", StatBalance.PLAYER_BASE_HP))
			player_stats_autoload.base_hp = clampi(loaded_base_hp, StatBalance.PLAYER_BASE_HP, StatBalance.PLAYER_MAX_HP)
			player_stats_autoload.refresh_stats()
	else:
		QuestLogger.info(QuestLogger.Category.SAVE, "No save file found for slot %d, starting fresh." % slot)
		first_time_player = true
		selected_character_id = CharacterDatabase.get_default_id()
		playtime_seconds = 0.0
		_session_start_msec = Time.get_ticks_msec()

		if player_stats_autoload:
			var default_data := CharacterDatabase.get_default()
			player_stats_autoload.base_hp = default_data.base_hp
			player_stats_autoload.refresh_stats()


## progresion-10: per-slot records, one Dictionary per difficulty id in [records]:
## runs, victories, best_floor, fastest_victory_sec (0 = none), most_kills.
const RECORDS_SECTION := "records"


func get_records(difficulty: String, slot: int = current_slot) -> Dictionary:
	var cfg := read_slot(slot)
	return cfg.get_value(RECORDS_SECTION, difficulty, {})


## Folds a finished run (GameSession.run_stats) into the slot's records and saves
## them (other sections untouched). Returns the record keys this run beat; the
## first run of a difficulty sets the marks but beats nothing. Needs a loaded slot.
func record_run(stats: Dictionary, slot: int = current_slot) -> Array[String]:
	var beaten: Array[String] = []
	if not slot_loaded:
		QuestLogger.warn(QuestLogger.Category.SAVE, "record_run: no slot loaded, run not recorded.")
		return beaten
	var difficulty := str(stats.get("difficulty", "normal"))
	var cfg := read_slot(slot)
	var rec: Dictionary = cfg.get_value(RECORDS_SECTION, difficulty, {})
	var first := int(rec.get("runs", 0)) == 0
	var victory := bool(stats.get("victory", false))
	var floor_reached := int(stats.get("floor_reached", 1))
	var kills := int(stats.get("kills", 0))
	var time := float(stats.get("elapsed_sec", 0.0))
	if floor_reached > int(rec.get("best_floor", 0)):
		rec["best_floor"] = floor_reached
		beaten.append("best_floor")
	if kills > int(rec.get("most_kills", 0)):
		rec["most_kills"] = kills
		beaten.append("most_kills")
	var fastest := float(rec.get("fastest_victory_sec", 0.0))
	if victory and (fastest <= 0.0 or time < fastest):
		rec["fastest_victory_sec"] = time
		beaten.append("fastest_victory_sec")
	rec["runs"] = int(rec.get("runs", 0)) + 1
	rec["victories"] = int(rec.get("victories", 0)) + int(victory)
	cfg.set_value(RECORDS_SECTION, difficulty, rec)
	_write(cfg, slot)
	QuestLogger.info(QuestLogger.Category.SAVE, "Run recorded in slot %d (%s): %s." % [slot, difficulty, rec])
	if first:
		beaten.clear()
	return beaten


## guardado-19: the offline run in progress, saved at the start of every floor
## from 2 on (Main.advance_floor) so it resumes from that floor's start. One key
## [run] state = the Dictionary Main.capture_run() builds. Cleared when the run
## ends (Main2d.finish_run) or a new one starts (Main.start_gameplay).
const RUN_SECTION := "run"


func save_run(state: Dictionary, slot: int = current_slot) -> void:
	if not slot_loaded:
		return
	var cfg := read_slot(slot)
	cfg.set_value(RUN_SECTION, "state", state)
	if _write(cfg, slot) == OK:
		QuestLogger.info(QuestLogger.Category.SAVE, "Run saved in slot %d (floor %d)." % [slot, int(state.get("floor", 0))])


## The saved run, or {} when there is none (or it is not usable: no heroes, floor < 2).
func get_saved_run(slot: int = current_slot) -> Dictionary:
	if not has_save(slot):
		return {}
	var state: Variant = read_slot(slot).get_value(RUN_SECTION, "state", {})
	if not state is Dictionary or int(state.get("floor", 0)) < 2 or (state.get("heroes", []) as Array).is_empty():
		return {}
	return state


func has_saved_run(slot: int = current_slot) -> bool:
	return not get_saved_run(slot).is_empty()


func clear_run(slot: int = current_slot) -> void:
	if not slot_loaded or not has_save(slot):
		return
	var cfg := read_slot(slot)
	if not cfg.has_section(RUN_SECTION):
		return
	cfg.erase_section(RUN_SECTION)
	if _write(cfg, slot) == OK:
		QuestLogger.info(QuestLogger.Category.SAVE, "Run cleared in slot %d." % slot)


func has_save(slot: int) -> bool:
	var path := get_save_path(slot)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


func delete_save(slot: int) -> void:
	var path := get_save_path(slot)
	if not SafeConfig.remove(path):
		QuestLogger.info(QuestLogger.Category.SAVE, "No save found to delete in slot %d." % slot)
		return
	if FileAccess.file_exists(path):
		QuestLogger.error(QuestLogger.Category.SAVE, "Failed to delete save in slot %d." % slot)
		return
	QuestLogger.info(QuestLogger.Category.SAVE, "Deleted save in slot %d." % slot)
	var bestiary := ManagerLocator.get_bestiary()
	if bestiary and bestiary.slot == slot:
		bestiary.reset()

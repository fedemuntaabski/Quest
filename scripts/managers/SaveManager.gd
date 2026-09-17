extends Node

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")
const CharacterDatabase = preload("res://scripts/core/stats/CharacterDatabase.gd")

## SaveManager — Autoload singleton
## Responsibilities:
## - Persist player progression (base stats, upgrades, run cycle) and slot management.
## - Manage disk serialization to `user://slot_<id>.cfg`.
## - Coordinate with CurrencyManager for persistent gold balances.

const SAVE_PATH_TEMPLATE := "user://slot_%d.cfg"
const SAVE_SECTION := "save_data"

var current_slot: int = 1
var first_time_player: bool = true

var gold: int = 0
var run_cycle: int = 0
var selected_character_id: String = ""
var post_victory_popup_pending: bool = false
var playtime_seconds: float = 0.0
var _session_start_msec: int = 0


func _ready() -> void:
	_session_start_msec = Time.get_ticks_msec()
	QuestLogger.info(QuestLogger.Category.SAVE, "Initialized.")


func get_save_path(slot: int = current_slot) -> String:
	return SAVE_PATH_TEMPLATE % slot


func get_run_cycle() -> int:
	return run_cycle


func set_run_cycle(value: int) -> void:
	run_cycle = max(0, value)


func increment_run_cycle() -> int:
	run_cycle += 1
	return run_cycle


func get_selected_character_id() -> String:
	return selected_character_id if selected_character_id != "" else CharacterDatabase.get_default_id()


func set_selected_character_id(character_id: String) -> void:
	selected_character_id = character_id


func apply_character_selection(character_id: String) -> void:
	var data := CharacterDatabase.get_by_id(character_id)
	selected_character_id = data.character_id

	var player_stats_autoload = ManagerLocator.get_player_stats()
	if player_stats_autoload:
		player_stats_autoload.base_hp = data.base_hp
		player_stats_autoload.base_str = data.base_str
		player_stats_autoload.base_mag = data.base_mag
		player_stats_autoload.base_dex = data.base_dex
		player_stats_autoload.refresh_stats()

	save_game(current_slot)


func save_game(slot: int = current_slot) -> void:
	var cfg := ConfigFile.new()

	var now_msec := Time.get_ticks_msec()
	playtime_seconds += (now_msec - _session_start_msec) / 1000.0
	_session_start_msec = now_msec

	var currency = ManagerLocator.get_currency_manager()
	if currency and currency.has_method("get_gold"):
		gold = currency.get_gold()

	var player_stats_autoload = ManagerLocator.get_player_stats()
	if player_stats_autoload:
		var hp_state = StatBalance.clamp_player_hp(player_stats_autoload.base_hp, player_stats_autoload.base_hp)
		cfg.set_value(SAVE_SECTION, "base_hp", int(hp_state.get("max_hp", player_stats_autoload.base_hp)))
		cfg.set_value(SAVE_SECTION, "base_str", player_stats_autoload.base_str)
		cfg.set_value(SAVE_SECTION, "base_mag", player_stats_autoload.base_mag)
		cfg.set_value(SAVE_SECTION, "base_dex", player_stats_autoload.base_dex)
		cfg.set_value(SAVE_SECTION, "active_upgrades", player_stats_autoload.active_upgrades)
	else:
		var fallback_data := CharacterDatabase.get_by_id(get_selected_character_id())
		cfg.set_value(SAVE_SECTION, "base_hp", fallback_data.base_hp)
		cfg.set_value(SAVE_SECTION, "base_str", fallback_data.base_str)
		cfg.set_value(SAVE_SECTION, "base_mag", fallback_data.base_mag)
		cfg.set_value(SAVE_SECTION, "base_dex", fallback_data.base_dex)
		cfg.set_value(SAVE_SECTION, "active_upgrades", [])

	cfg.set_value(SAVE_SECTION, "selected_character_id", selected_character_id)
	cfg.set_value(SAVE_SECTION, "first_time_player", first_time_player)
	cfg.set_value(SAVE_SECTION, "gold", gold)
	cfg.set_value(SAVE_SECTION, "run_cycle", run_cycle)
	# Backward compatibility for older save formats:
	cfg.set_value(SAVE_SECTION, "contracts_completed", run_cycle)
	cfg.set_value(SAVE_SECTION, "post_victory_popup_pending", post_victory_popup_pending)
	cfg.set_value(SAVE_SECTION, "saved_at_unix", Time.get_unix_time_from_system())
	cfg.set_value(SAVE_SECTION, "playtime_seconds", playtime_seconds)

	var err := cfg.save(get_save_path(slot))
	if err == OK:
		QuestLogger.info(QuestLogger.Category.SAVE, "Saved successfully to slot %d." % slot)
	else:
		QuestLogger.error(QuestLogger.Category.SAVE, "Failed to save to slot %d (Error code: %d)." % [slot, err])


func load_game(slot: int = current_slot) -> void:
	current_slot = slot
	var cfg := ConfigFile.new()
	var err := cfg.load(get_save_path(slot))

	var player_stats_autoload = ManagerLocator.get_player_stats()

	if err == OK:
		QuestLogger.info(QuestLogger.Category.SAVE, "Loaded save from slot %d." % slot)
		first_time_player = bool(cfg.get_value(SAVE_SECTION, "first_time_player", false))
		gold = int(cfg.get_value(SAVE_SECTION, "gold", 0))
		selected_character_id = str(cfg.get_value(SAVE_SECTION, "selected_character_id", CharacterDatabase.get_default_id()))

		# Sync gold with CurrencyManager immediately
		var currency = ManagerLocator.get_currency_manager()
		if currency and currency.has_method("set_gold"):
			currency.set_gold(gold)

		var loaded_cycle := int(cfg.get_value(SAVE_SECTION, "run_cycle", cfg.get_value(SAVE_SECTION, "contracts_completed", 0)))
		run_cycle = max(0, loaded_cycle)
		post_victory_popup_pending = bool(cfg.get_value(SAVE_SECTION, "post_victory_popup_pending", false))
		playtime_seconds = float(cfg.get_value(SAVE_SECTION, "playtime_seconds", 0.0))
		_session_start_msec = Time.get_ticks_msec()

		if player_stats_autoload:
			var loaded_base_hp := int(cfg.get_value(SAVE_SECTION, "base_hp", StatBalance.PLAYER_BASE_HP))
			var hp_state := StatBalance.clamp_player_hp(loaded_base_hp, loaded_base_hp)
			player_stats_autoload.base_hp = int(hp_state.get("max_hp", StatBalance.PLAYER_BASE_HP))
			player_stats_autoload.base_str = int(cfg.get_value(SAVE_SECTION, "base_str", 1))
			player_stats_autoload.base_mag = int(cfg.get_value(SAVE_SECTION, "base_mag", 1))
			player_stats_autoload.base_dex = int(cfg.get_value(SAVE_SECTION, "base_dex", 1))
			player_stats_autoload.active_upgrades = cfg.get_value(SAVE_SECTION, "active_upgrades", [])
			player_stats_autoload.refresh_stats()
	else:
		QuestLogger.info(QuestLogger.Category.SAVE, "No save file found for slot %d, starting fresh." % slot)
		first_time_player = true
		gold = 0
		run_cycle = 0
		selected_character_id = CharacterDatabase.get_default_id()
		post_victory_popup_pending = false
		playtime_seconds = 0.0
		_session_start_msec = Time.get_ticks_msec()

		var currency = ManagerLocator.get_currency_manager()
		if currency and currency.has_method("set_gold"):
			currency.set_gold(0)

		if player_stats_autoload:
			var default_data := CharacterDatabase.get_default()
			player_stats_autoload.base_hp = default_data.base_hp
			player_stats_autoload.base_str = default_data.base_str
			player_stats_autoload.base_mag = default_data.base_mag
			player_stats_autoload.base_dex = default_data.base_dex
			player_stats_autoload.active_upgrades = []
			player_stats_autoload.refresh_stats()


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))


func delete_save(slot: int) -> void:
	var path := get_save_path(slot)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err == OK:
			QuestLogger.info(QuestLogger.Category.SAVE, "Deleted save in slot %d." % slot)
		else:
			QuestLogger.error(QuestLogger.Category.SAVE, "Failed to delete save in slot %d (Error code: %d)." % [slot, err])
	else:
		QuestLogger.warn(QuestLogger.Category.SAVE, "No save found to delete in slot %d." % slot)

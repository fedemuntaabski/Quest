extends Node

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")

## SaveManager — Autoload singleton
## Responsibilities:
## - Persist player progression (base stats, upgrades) and run metadata.
## - Expose `first_time_player`, `gold` and simple save-slot helpers.
## Notes:
## - This module is a small disk-backed holder and is used by `CurrencyManager`
##   and other systems to read/write runtime values; it is *not* the owner
##   of gameplay logic.

const SAVE_PATH_TEMPLATE = "user://slot_%d.cfg"
const SAVE_SECTION = "save_data"

var current_slot: int = 1
var first_time_player: bool = true

var gold: int = 0
var contracts_completed: int = 0
var run_cycle: int = 0
var post_victory_popup_pending: bool = false

func _ready() -> void:
	print("SaveManager initialized.")

func get_save_path(slot: int) -> String:
	return SAVE_PATH_TEMPLATE % slot

func save_game(slot: int = current_slot) -> void:
	var cfg = ConfigFile.new()
	_sync_cycle_aliases_from_contracts()
	
	var player_stats_autoload = ManagerLocator.get_player_stats()
	if player_stats_autoload:
		var hp_state = StatBalance.clamp_player_hp(player_stats_autoload.base_hp, player_stats_autoload.base_hp)
		cfg.set_value(SAVE_SECTION, "base_hp", int(hp_state.get("max_hp", player_stats_autoload.base_hp)))
		cfg.set_value(SAVE_SECTION, "base_str", player_stats_autoload.base_str)
		cfg.set_value(SAVE_SECTION, "base_mag", player_stats_autoload.base_mag)
		cfg.set_value(SAVE_SECTION, "base_dex", player_stats_autoload.base_dex)
		cfg.set_value(SAVE_SECTION, "active_upgrades", player_stats_autoload.active_upgrades)
	else:
		cfg.set_value(SAVE_SECTION, "base_hp", StatBalance.PLAYER_BASE_HP)
		cfg.set_value(SAVE_SECTION, "base_str", 1)
		cfg.set_value(SAVE_SECTION, "base_mag", 1)
		cfg.set_value(SAVE_SECTION, "base_dex", 1)
		cfg.set_value(SAVE_SECTION, "active_upgrades", [])

	cfg.set_value(SAVE_SECTION, "first_time_player", first_time_player)
	cfg.set_value(SAVE_SECTION, "gold", gold)
	cfg.set_value(SAVE_SECTION, "contracts_completed", contracts_completed)
	cfg.set_value(SAVE_SECTION, "run_cycle", run_cycle)
	cfg.set_value(SAVE_SECTION, "post_victory_popup_pending", post_victory_popup_pending)
	
	var err = cfg.save(get_save_path(slot))
	if err == OK:
		print("SaveManager: Saved successfully to slot %d." % slot)
	else:
		push_error("SaveManager: Failed to save to slot %d (Error code: %d)." % [slot, err])

func load_game(slot: int = current_slot) -> void:
	current_slot = slot
	var cfg = ConfigFile.new()
	var err = cfg.load(get_save_path(slot))
	
	var player_stats_autoload = ManagerLocator.get_player_stats()
	
	if err == OK:
		print("SaveManager: Loaded save from slot %d." % slot)
		first_time_player = cfg.get_value(SAVE_SECTION, "first_time_player", false)
		gold = cfg.get_value(SAVE_SECTION, "gold", 0)
		var loaded_contracts := int(cfg.get_value(SAVE_SECTION, "contracts_completed", 0))
		var loaded_cycle := loaded_contracts
		if cfg.has_section_key(SAVE_SECTION, "run_cycle"):
			loaded_cycle = int(cfg.get_value(SAVE_SECTION, "run_cycle", loaded_contracts))
		run_cycle = max(0, loaded_cycle)
		contracts_completed = run_cycle
		post_victory_popup_pending = bool(cfg.get_value(SAVE_SECTION, "post_victory_popup_pending", false))
		
		if player_stats_autoload:
			var loaded_base_hp := int(cfg.get_value(SAVE_SECTION, "base_hp", StatBalance.PLAYER_BASE_HP))
			var hp_state := StatBalance.clamp_player_hp(loaded_base_hp, loaded_base_hp)
			player_stats_autoload.base_hp = int(hp_state.get("max_hp", StatBalance.PLAYER_BASE_HP))
			player_stats_autoload.base_str = cfg.get_value(SAVE_SECTION, "base_str", 1)
			player_stats_autoload.base_mag = cfg.get_value(SAVE_SECTION, "base_mag", 1)
			player_stats_autoload.base_dex = cfg.get_value(SAVE_SECTION, "base_dex", 1)
			player_stats_autoload.active_upgrades = cfg.get_value(SAVE_SECTION, "active_upgrades", [])
			player_stats_autoload.refresh_stats()
	else:
		print("SaveManager: No save file found for slot %d, starting fresh." % slot)
		first_time_player = true
		gold = 0
		contracts_completed = 0
		run_cycle = 0
		post_victory_popup_pending = false
		if player_stats_autoload:
			player_stats_autoload.base_hp = StatBalance.PLAYER_BASE_HP
			player_stats_autoload.base_str = 1
			player_stats_autoload.base_mag = 1
			player_stats_autoload.base_dex = 1
			player_stats_autoload.active_upgrades = []
			player_stats_autoload.refresh_stats()

func get_run_cycle() -> int:
	_sync_cycle_aliases_from_contracts()
	return run_cycle

func set_run_cycle(value: int) -> void:
	run_cycle = max(0, value)
	contracts_completed = run_cycle

func increment_run_cycle() -> int:
	set_run_cycle(get_run_cycle() + 1)
	return run_cycle

func _sync_cycle_aliases_from_contracts() -> void:
	run_cycle = max(0, contracts_completed)

func has_save(slot: int) -> bool:
	var file = FileAccess.open(get_save_path(slot), FileAccess.READ)
	return file != null

func delete_save(slot: int) -> void:
	var path = get_save_path(slot)
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(path)
		if err == OK:
			print("SaveManager: Deleted save in slot %d." % slot)
		else:
			push_error("SaveManager: Failed to delete save in slot %d (Error code: %d)." % [slot, err])
	else:
		print("SaveManager: No save found to delete in slot %d." % slot)

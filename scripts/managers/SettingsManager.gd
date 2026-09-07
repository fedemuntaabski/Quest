extends Node

## SettingsManager — Autoload singleton
## Responsibilities:
## - Persist configuration options (audio volumes, display settings) to `user://settings.cfg`.
## - Expose reactive signals when settings change so UI and audio players update automatically.
## - Decouple OptionsMenu from direct disk I/O and player management.

signal settings_changed(section: String, key: String, value: Variant)
signal volume_changed(type: String, linear_value: float, db_value: float)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_OPTIONS := "options"

var click_volume: float = 1.0:
	set(val):
		click_volume = clampf(val, 0.001, 2.0)
		volume_changed.emit("click", click_volume, get_click_volume_db())
		settings_changed.emit(SECTION_OPTIONS, "click_volume", click_volume)

var hover_volume: float = 1.0:
	set(val):
		hover_volume = clampf(val, 0.001, 2.0)
		volume_changed.emit("hover", hover_volume, get_hover_volume_db())
		settings_changed.emit(SECTION_OPTIONS, "hover_volume", hover_volume)


func _ready() -> void:
	load_settings()


func get_click_volume_db() -> float:
	return linear_to_db(max(click_volume, 0.001))


func get_hover_volume_db() -> float:
	return linear_to_db(max(hover_volume, 0.001))


func apply_volume_to_player(player: AudioStreamPlayer, type: String) -> void:
	if player == null:
		return
	match type:
		"click":
			player.volume_db = get_click_volume_db()
		"hover":
			player.volume_db = get_hover_volume_db()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		# Use defaults
		click_volume = 1.0
		hover_volume = 1.0
		return

	click_volume = float(cfg.get_value(SECTION_OPTIONS, "click_volume", 1.0))
	hover_volume = float(cfg.get_value(SECTION_OPTIONS, "hover_volume", 1.0))


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_OPTIONS, "click_volume", click_volume)
	cfg.set_value(SECTION_OPTIONS, "hover_volume", hover_volume)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: Failed to save settings to %s (Error %s)" % [SETTINGS_PATH, err])
	return err

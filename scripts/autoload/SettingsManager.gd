extends Node

## SettingsManager — Autoload singleton
## Responsibilities:
## - Persist UI SFX volumes (click/hover), audio bus volumes (Master/Music/SFX/UI),
##   video settings (window mode/resolution/vsync/fps limit), gameplay settings
##   (screen shake intensity) and display settings (FPS overlay, locale) to `user://settings.cfg`.
## - Apply video settings to DisplayServer/Engine automatically on startup.
## - Expose reactive signals when settings change so UI and audio players update automatically.
## - Decouple OptionsMenu from direct disk I/O and player management.

signal settings_changed(section: String, key: String, value: Variant)
signal volume_changed(type: String, linear_value: float, db_value: float)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_OPTIONS := "options"
const SECTION_AUDIO := "audio"
const SECTION_VIDEO := "video"
const SECTION_GAMEPLAY := "gameplay"
const SECTION_DISPLAY := "display"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const FPS_LIMITS: Array[int] = [30, 60, 120, 144, 240, 0]
const BASE_VIEWPORT_SIZE := Vector2i(1920, 1080)

enum WindowMode { FULLSCREEN, WINDOWED, BORDERLESS }

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

var master_volume: float = 1.0:
	set(val):
		master_volume = clampf(val, 0.001, 2.0)
		_apply_bus_volume("Master", master_volume)
		settings_changed.emit(SECTION_AUDIO, "master_volume", master_volume)

var music_volume: float = 1.0:
	set(val):
		music_volume = clampf(val, 0.001, 2.0)
		_apply_bus_volume("Music", music_volume)
		settings_changed.emit(SECTION_AUDIO, "music_volume", music_volume)

var sfx_volume: float = 1.0:
	set(val):
		sfx_volume = clampf(val, 0.001, 2.0)
		_apply_bus_volume("SFX", sfx_volume)
		settings_changed.emit(SECTION_AUDIO, "sfx_volume", sfx_volume)

var ui_volume: float = 1.0:
	set(val):
		ui_volume = clampf(val, 0.001, 2.0)
		_apply_bus_volume("UI", ui_volume)
		settings_changed.emit(SECTION_AUDIO, "ui_volume", ui_volume)

var window_mode: int = WindowMode.FULLSCREEN
var resolution_index: int = 2 ## -1 == use native monitor resolution (recomputed on apply, never cached)
var vsync_enabled: bool = true
var fps_limit_index: int = 1

var screen_shake_intensity: float = 1.0:
	set(val):
		screen_shake_intensity = clampf(val, 0.0, 1.0)
		settings_changed.emit(SECTION_GAMEPLAY, "screen_shake_intensity", screen_shake_intensity)

var show_fps_overlay: bool = false:
	set(val):
		show_fps_overlay = val
		settings_changed.emit(SECTION_DISPLAY, "show_fps_overlay", show_fps_overlay)

var locale: String = "es":
	set(val):
		locale = val
		TranslationServer.set_locale(locale)
		settings_changed.emit(SECTION_DISPLAY, "locale", locale)


func _ready() -> void:
	load_settings()
	apply_video_settings()


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


## Real monitor resolution for the screen the game window currently lives on.
func get_native_resolution() -> Vector2i:
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


func _apply_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(max(value, 0.001)))


## Applies window_mode/resolution_index/vsync_enabled/fps_limit_index to
## DisplayServer/Engine. Safe to call multiple times (idempotent).
func apply_video_settings() -> void:
	apply_window_mode()
	apply_resolution()
	apply_vsync()
	apply_fps_limit()


func apply_window_mode() -> void:
	match window_mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)


func _resolved_resolution() -> Vector2i:
	if resolution_index == -1:
		return get_native_resolution()
	return RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]


## Applies resolution_index. Behavior differs by window_mode: DisplayServer.window_set_size
## is a no-op under exclusive fullscreen (OS pins window pixels to the monitor), so
## fullscreen instead rescales the canvas_items stretch base via content_scale_size —
## the only "resolution" lever available for this stretch mode while fullscreen.
func apply_resolution() -> void:
	if window_mode == WindowMode.FULLSCREEN:
		var target := BASE_VIEWPORT_SIZE if resolution_index == -1 else _resolved_resolution()
		get_tree().root.content_scale_size = target
	else:
		get_tree().root.content_scale_size = BASE_VIEWPORT_SIZE
		var size := _resolved_resolution()
		DisplayServer.window_set_size(size)
		var screen_idx := DisplayServer.window_get_current_screen()
		var screen_rect := DisplayServer.screen_get_usable_rect(screen_idx)
		DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - size) / 2)


func apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)


func apply_fps_limit() -> void:
	var fps_idx := clampi(fps_limit_index, 0, FPS_LIMITS.size() - 1)
	Engine.max_fps = FPS_LIMITS[fps_idx]


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		# Use defaults (already set as property initializers)
		return

	click_volume = float(cfg.get_value(SECTION_OPTIONS, "click_volume", 1.0))
	hover_volume = float(cfg.get_value(SECTION_OPTIONS, "hover_volume", 1.0))

	master_volume = float(cfg.get_value(SECTION_AUDIO, "master_volume", 1.0))
	music_volume = float(cfg.get_value(SECTION_AUDIO, "music_volume", 1.0))
	sfx_volume = float(cfg.get_value(SECTION_AUDIO, "sfx_volume", 1.0))
	ui_volume = float(cfg.get_value(SECTION_AUDIO, "ui_volume", 1.0))

	window_mode = int(cfg.get_value(SECTION_VIDEO, "window_mode", WindowMode.FULLSCREEN))
	resolution_index = int(cfg.get_value(SECTION_VIDEO, "resolution_index", 2))
	vsync_enabled = bool(cfg.get_value(SECTION_VIDEO, "vsync_enabled", true))
	fps_limit_index = int(cfg.get_value(SECTION_VIDEO, "fps_limit_index", 1))

	screen_shake_intensity = float(cfg.get_value(SECTION_GAMEPLAY, "screen_shake_intensity", 1.0))

	show_fps_overlay = bool(cfg.get_value(SECTION_DISPLAY, "show_fps_overlay", false))
	locale = String(cfg.get_value(SECTION_DISPLAY, "locale", "es"))


func save_settings() -> Error:
	var cfg := ConfigFile.new()

	cfg.set_value(SECTION_OPTIONS, "click_volume", click_volume)
	cfg.set_value(SECTION_OPTIONS, "hover_volume", hover_volume)

	cfg.set_value(SECTION_AUDIO, "master_volume", master_volume)
	cfg.set_value(SECTION_AUDIO, "music_volume", music_volume)
	cfg.set_value(SECTION_AUDIO, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION_AUDIO, "ui_volume", ui_volume)

	cfg.set_value(SECTION_VIDEO, "window_mode", window_mode)
	cfg.set_value(SECTION_VIDEO, "resolution_index", resolution_index)
	cfg.set_value(SECTION_VIDEO, "vsync_enabled", vsync_enabled)
	cfg.set_value(SECTION_VIDEO, "fps_limit_index", fps_limit_index)

	cfg.set_value(SECTION_GAMEPLAY, "screen_shake_intensity", screen_shake_intensity)

	cfg.set_value(SECTION_DISPLAY, "show_fps_overlay", show_fps_overlay)
	cfg.set_value(SECTION_DISPLAY, "locale", locale)

	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: Failed to save settings to %s (Error %s)" % [SETTINGS_PATH, err])
	return err

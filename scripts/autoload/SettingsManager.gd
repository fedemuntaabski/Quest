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
## calidad-13: accessibility flags (mirrored into the Accessibility statics) and
## the player's control remaps (InputBindings.overrides()).
const SECTION_ACCESSIBILITY := "accessibility"
const SECTION_INPUT := "input"
const SETTINGS_VERSION := 1
## First-time help already shown, per install (own file: never touched by the
## save/discard of the Options menu).
const HELP_PATH := "user://first_help.cfg"
const TEXT_SCALE_MIN := 0.8
const TEXT_SCALE_MAX := 1.5

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

var text_scale: float = 1.0:
	set(val):
		text_scale = clampf(val, TEXT_SCALE_MIN, TEXT_SCALE_MAX)
		Accessibility.text_scale = text_scale
		_apply_root_theme()
		settings_changed.emit(SECTION_ACCESSIBILITY, "text_scale", text_scale)

var colorblind_mode: bool = false:
	set(val):
		colorblind_mode = val
		Accessibility.colorblind = val
		settings_changed.emit(SECTION_ACCESSIBILITY, "colorblind_mode", val)

var reduce_flashes: bool = false:
	set(val):
		reduce_flashes = val
		Accessibility.reduce_flashes = val
		settings_changed.emit(SECTION_ACCESSIBILITY, "reduce_flashes", val)

var sound_captions: bool = false:
	set(val):
		sound_captions = val
		Accessibility.sound_captions = val
		settings_changed.emit(SECTION_ACCESSIBILITY, "sound_captions", val)

var first_help_enabled: bool = true:
	set(val):
		first_help_enabled = val
		settings_changed.emit(SECTION_GAMEPLAY, "first_help_enabled", val)

var help_path: String = HELP_PATH
## Tests and screenshot tools (--script) keep "seen" in memory: a suite run must
## not spend the help of the player's real first game.
var help_persist: bool = not OS.get_cmdline_args().has("--script")
var _seen_help: Dictionary = {}


func _ready() -> void:
	InputBindings.ensure_defaults()
	load_settings()
	load_help()
	apply_video_settings()
	_apply_root_theme()
	get_tree().node_added.connect(_scale_scene_font)


## Font sizes set in .tscn files (theme_override_font_sizes) follow text_scale when
## the scene is instanced. Only nodes with an owner (= came from a scene): code-built
## UI already passes its sizes through Accessibility.font().
func _scale_scene_font(node: Node) -> void:
	if text_scale == 1.0 or node.owner == null or not (node is Control):
		return
	var control := node as Control
	if control.has_theme_font_size_override("font_size") and not control.has_meta(&"a11y_font"):
		control.set_meta(&"a11y_font", true)  # once: a reparent re-enters the tree
		control.add_theme_font_size_override("font_size", Accessibility.font(control.get_theme_font_size("font_size")))


## Default font size of every Control without its own override (overrides go
## through Accessibility.font()). Rebuilt UI picks the new size up. A Control under
## a CanvasLayer (every menu and the whole HUD) doesn't inherit the root window's
## theme, so the engine's default theme carries the size too.
func _apply_root_theme() -> void:
	if not is_inside_tree():
		return
	var root := get_tree().root
	if root.theme == null:
		root.theme = Theme.new()
	root.theme.default_font_size = Accessibility.font(16)
	ThemeDB.get_default_theme().default_font_size = Accessibility.font(16)


func should_show_help(id: String) -> bool:
	return first_help_enabled and not _seen_help.has(id)


func mark_help_seen(id: String) -> void:
	_seen_help[id] = true
	_save_help()


## Opciones: "Volver a ver las ayudas".
func reset_help() -> void:
	_seen_help.clear()
	_save_help()


func load_help() -> void:
	_seen_help.clear()
	var cfg := ConfigFile.new()
	if cfg.load(help_path) == OK:
		for id in cfg.get_value("help", "seen", PackedStringArray()):
			_seen_help[id] = true


func _save_help() -> void:
	if not help_persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("help", "seen", PackedStringArray(_seen_help.keys()))
	if cfg.save(help_path) != OK:
		QuestLogger.warn(QuestLogger.Category.UI, "SettingsManager: failed to save %s." % help_path)


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
	InputBindings.reset_all()  # a discard in Opciones reloads: unsaved remaps go too
	var cfg := ConfigFile.new()
	var status := SafeConfig.load_into(cfg, SETTINGS_PATH)
	if status == SafeConfig.Status.CORRUPT:
		QuestLogger.warn(QuestLogger.Category.UI, "settings.cfg was damaged: defaults used (kept as settings.cfg.corrupt).")
	if status == SafeConfig.Status.MISSING or status == SafeConfig.Status.CORRUPT:
		return  # defaults (property initializers)

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
	first_help_enabled = bool(cfg.get_value(SECTION_GAMEPLAY, "first_help_enabled", true))

	show_fps_overlay = bool(cfg.get_value(SECTION_DISPLAY, "show_fps_overlay", false))
	locale = String(cfg.get_value(SECTION_DISPLAY, "locale", "es"))

	text_scale = float(cfg.get_value(SECTION_ACCESSIBILITY, "text_scale", 1.0))
	colorblind_mode = bool(cfg.get_value(SECTION_ACCESSIBILITY, "colorblind_mode", false))
	reduce_flashes = bool(cfg.get_value(SECTION_ACCESSIBILITY, "reduce_flashes", false))
	sound_captions = bool(cfg.get_value(SECTION_ACCESSIBILITY, "sound_captions", false))

	var remaps := {}
	for action in cfg.get_section_keys(SECTION_INPUT) if cfg.has_section(SECTION_INPUT) else PackedStringArray():
		remaps[action] = cfg.get_value(SECTION_INPUT, action, [])
	InputBindings.apply_overrides(remaps)


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SETTINGS_VERSION)

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
	cfg.set_value(SECTION_GAMEPLAY, "first_help_enabled", first_help_enabled)

	cfg.set_value(SECTION_DISPLAY, "show_fps_overlay", show_fps_overlay)
	cfg.set_value(SECTION_DISPLAY, "locale", locale)

	cfg.set_value(SECTION_ACCESSIBILITY, "text_scale", text_scale)
	cfg.set_value(SECTION_ACCESSIBILITY, "colorblind_mode", colorblind_mode)
	cfg.set_value(SECTION_ACCESSIBILITY, "reduce_flashes", reduce_flashes)
	cfg.set_value(SECTION_ACCESSIBILITY, "sound_captions", sound_captions)

	var remaps := InputBindings.overrides()
	for action in remaps:
		cfg.set_value(SECTION_INPUT, action, remaps[action])

	var err := SafeConfig.save(cfg, SETTINGS_PATH)
	if err != OK:
		QuestLogger.warn(QuestLogger.Category.UI, "SettingsManager: failed to save settings to %s (Error %s)" % [SETTINGS_PATH, err])
	return err

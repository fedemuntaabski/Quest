extends Control
class_name OptionsMenu

## OptionsMenu — Reusable options presentation component.
## Works in both MainMenu and PauseMenu.
## Communicates with SettingsManager for persistence and audio levels.

signal closed

@export var click_player_path: NodePath
@export var hover_player_path: NodePath

@onready var click_player: AudioStreamPlayer = get_node_or_null(click_player_path)
@onready var hover_player: AudioStreamPlayer = get_node_or_null(hover_player_path)

@onready var options_card: Panel = $OptionsCenterContainer/OptionsCard
@onready var options_tabs: TabContainer = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs

# --- Video tab ---
@onready var window_mode_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Video/WindowModeLabel
@onready var window_mode_option: OptionButton = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Video/WindowModeOption
@onready var resolution_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Video/ResolutionLabel
@onready var resolution_option: OptionButton = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Video/ResolutionOption
@onready var vsync_check: CheckButton = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Video/VSyncCheck
@onready var fps_limit_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Video/FpsLimitLabel
@onready var fps_limit_option: OptionButton = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Video/FpsLimitOption
@onready var show_fps_check: CheckButton = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Video/ShowFpsCheck
@onready var language_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Video/LanguageLabel
@onready var language_option: OptionButton = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Video/LanguageOption

# --- Audio tab ---
@onready var master_volume_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/MasterVolumeLabel
@onready var master_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/MasterVolumeRow/MasterVolumeSlider
@onready var master_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/MasterVolumeRow/MasterVolumeValueLabel
@onready var music_volume_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/MusicVolumeLabel
@onready var music_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/MusicVolumeRow/MusicVolumeSlider
@onready var music_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/MusicVolumeRow/MusicVolumeValueLabel
@onready var sfx_volume_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/SfxVolumeLabel
@onready var sfx_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/SfxVolumeRow/SfxVolumeSlider
@onready var sfx_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/SfxVolumeRow/SfxVolumeValueLabel
@onready var ui_volume_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/UiVolumeLabel
@onready var ui_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/UiVolumeRow/UiVolumeSlider
@onready var ui_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/UiVolumeRow/UiVolumeValueLabel
@onready var click_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/ClickVolumeRow/ClickVolumeSlider
@onready var click_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/ClickVolumeRow/ClickVolumeValueLabel
@onready var hover_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/HoverVolumeRow/HoverVolumeSlider
@onready var hover_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/HoverVolumeRow/HoverVolumeValueLabel

# --- Gameplay tab ---
@onready var screen_shake_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Gameplay/ScreenShakeLabel
@onready var screen_shake_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Gameplay/ScreenShakeRow/ScreenShakeSlider
@onready var screen_shake_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Gameplay/ScreenShakeRow/ScreenShakeValueLabel

@onready var save_button: Button = $OptionsCenterContainer/OptionsCard/OptionsVBox/SaveButton
@onready var back_button: Button = $OptionsCenterContainer/OptionsCard/OptionsVBox/BackButton
@onready var unsaved_changes_dialog: ConfirmationDialog = $UnsavedChangesDialog

const WINDOW_MODE_LABELS := ["KEY_WINDOW_FULLSCREEN", "KEY_WINDOW_WINDOWED", "KEY_WINDOW_BORDERLESS"]
const LANGUAGE_LABELS := ["Español", "Inglés"]
const LANGUAGE_CODES := ["es", "en"]

var has_unsaved_changes: bool = false
var suppress_change_tracking: bool = false
var _active_tween: Tween = null
var _button_tweens: Dictionary = {}

var _resolution_choices: Array[Vector2i] = []
var _native_res_is_separate: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_populate_option_buttons()
	_connect_menu_signals()
	_update_ui_text_translations()

	if not unsaved_changes_dialog.confirmed.is_connected(_on_unsaved_discard_confirmed):
		unsaved_changes_dialog.confirmed.connect(_on_unsaved_discard_confirmed)

	_sync_from_settings_manager()

	var settings_mgr := _get_settings_manager()
	if settings_mgr and not settings_mgr.volume_changed.is_connected(_on_settings_volume_changed):
		settings_mgr.volume_changed.connect(_on_settings_volume_changed)


func _get_settings_manager() -> Node:
	return ManagerLocator.get_settings_manager()


func _populate_option_buttons() -> void:
	window_mode_option.clear()
	for label_key in WINDOW_MODE_LABELS:
		window_mode_option.add_item(tr(label_key))

	var settings_mgr := _get_settings_manager()

	resolution_option.clear()
	_resolution_choices.clear()
	_native_res_is_separate = false
	var resolutions: Array = settings_mgr.RESOLUTIONS if settings_mgr else []
	var native: Vector2i = settings_mgr.get_native_resolution() if settings_mgr else Vector2i.ZERO
	var native_matches_preset := false
	for res in resolutions:
		if res == native:
			native_matches_preset = true
	if native != Vector2i.ZERO and not native_matches_preset:
		_native_res_is_separate = true
		_resolution_choices.append(native)
	for res in resolutions:
		_resolution_choices.append(res)

	for i in range(_resolution_choices.size()):
		var res: Vector2i = _resolution_choices[i]
		if i == 0 and _native_res_is_separate:
			resolution_option.add_item("%s (%dx%d)" % [tr("KEY_RESOLUTION_NATIVE"), res.x, res.y])
		else:
			resolution_option.add_item("%dx%d" % [res.x, res.y])

	fps_limit_option.clear()
	var fps_limits: Array = settings_mgr.FPS_LIMITS if settings_mgr else []
	for fps in fps_limits:
		fps_limit_option.add_item("Sin límite" if fps == 0 else "%d FPS" % fps)

	language_option.clear()
	for label in LANGUAGE_LABELS:
		language_option.add_item(label)


## Maps SettingsManager.resolution_index (-1 == native, else RESOLUTIONS index)
## to the UI item index in resolution_option, accounting for a possible
## prepended "Nativa (WxH)" entry.
func _settings_resolution_index_to_ui_index(settings_index: int) -> int:
	if settings_index == -1:
		if _native_res_is_separate:
			return 0
		# Monitor no longer mismatches a preset — fall back to the matching preset.
		var settings_mgr := _get_settings_manager()
		var native: Vector2i = settings_mgr.get_native_resolution() if settings_mgr else Vector2i.ZERO
		for i in range(_resolution_choices.size()):
			if _resolution_choices[i] == native:
				return i
		return 0
	var offset := 1 if _native_res_is_separate else 0
	return clampi(settings_index + offset, 0, resolution_option.item_count - 1)


## Reverse of the above: UI item index -> value to store in SettingsManager.resolution_index.
func _ui_resolution_index_to_settings_index(ui_index: int) -> int:
	if _native_res_is_separate and ui_index == 0:
		return -1
	var offset := 1 if _native_res_is_separate else 0
	return ui_index - offset


func _sync_from_settings_manager() -> void:
	suppress_change_tracking = true
	var settings_mgr := _get_settings_manager()

	if settings_mgr:
		TranslationServer.set_locale(settings_mgr.locale)
		_update_ui_text_translations()

	var click_vol := 1.0
	var hover_vol := 1.0
	var master_vol := 1.0
	var music_vol := 1.0
	var sfx_vol := 1.0
	var ui_vol := 1.0
	var w_mode := 0
	var res_idx := 2
	var vsync_on := true
	var fps_idx := 1
	var shake := 1.0
	var show_fps := false
	var lang_idx := 0

	if settings_mgr:
		click_vol = settings_mgr.click_volume
		hover_vol = settings_mgr.hover_volume
		master_vol = settings_mgr.master_volume
		music_vol = settings_mgr.music_volume
		sfx_vol = settings_mgr.sfx_volume
		ui_vol = settings_mgr.ui_volume
		w_mode = settings_mgr.window_mode
		res_idx = settings_mgr.resolution_index
		vsync_on = settings_mgr.vsync_enabled
		fps_idx = settings_mgr.fps_limit_index
		shake = settings_mgr.screen_shake_intensity
		show_fps = settings_mgr.show_fps_overlay
		lang_idx = maxi(LANGUAGE_CODES.find(settings_mgr.locale), 0)

	click_volume_slider.value = clampf(click_vol, 0.001, 2.0)
	hover_volume_slider.value = clampf(hover_vol, 0.001, 2.0)
	master_volume_slider.value = clampf(master_vol, 0.001, 2.0)
	music_volume_slider.value = clampf(music_vol, 0.001, 2.0)
	sfx_volume_slider.value = clampf(sfx_vol, 0.001, 2.0)
	ui_volume_slider.value = clampf(ui_vol, 0.001, 2.0)

	_update_click_volume_label(click_volume_slider.value)
	_update_hover_volume_label(hover_volume_slider.value)
	_update_percent_label(master_volume_value_label, master_volume_slider.value)
	_update_percent_label(music_volume_value_label, music_volume_slider.value)
	_update_percent_label(sfx_volume_value_label, sfx_volume_slider.value)
	_update_percent_label(ui_volume_value_label, ui_volume_slider.value)

	_apply_audio_players(click_volume_slider.value, hover_volume_slider.value)
	_apply_bus_volume_preview("Master", master_volume_slider.value)
	_apply_bus_volume_preview("Music", music_volume_slider.value)
	_apply_bus_volume_preview("SFX", sfx_volume_slider.value)
	_apply_bus_volume_preview("UI", ui_volume_slider.value)

	window_mode_option.selected = clampi(w_mode, 0, window_mode_option.item_count - 1)
	resolution_option.selected = _settings_resolution_index_to_ui_index(res_idx)
	vsync_check.button_pressed = vsync_on
	fps_limit_option.selected = clampi(fps_idx, 0, fps_limit_option.item_count - 1)
	show_fps_check.button_pressed = show_fps
	language_option.selected = clampi(lang_idx, 0, language_option.item_count - 1)

	screen_shake_slider.value = clampf(shake, 0.0, 1.0)
	_update_percent_label(screen_shake_value_label, screen_shake_slider.value)

	suppress_change_tracking = false
	has_unsaved_changes = false


func open() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_sync_from_settings_manager()
	visible = true

	if options_card:
		options_card.pivot_offset = options_card.size / 2.0
		options_card.scale = Vector2(0.92, 0.92)
		options_card.modulate.a = 0.0

		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(options_card, "scale", Vector2.ONE, 0.25)
		_active_tween.tween_property(options_card, "modulate:a", 1.0, 0.22)


func close(animate: bool = true) -> void:
	if not visible:
		return

	if not animate:
		visible = false
		return

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	if options_card:
		options_card.pivot_offset = options_card.size / 2.0
		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_active_tween.tween_property(options_card, "scale", Vector2(0.92, 0.92), 0.18)
		_active_tween.tween_property(options_card, "modulate:a", 0.0, 0.18)
		_active_tween.chain().tween_callback(func():
			visible = false
			closed.emit()
		)
	else:
		visible = false
		closed.emit()


# ---------------- CONNECT ----------------

func _connect_menu_signals() -> void:
	var all_buttons: Array[BaseButton] = [
		save_button, back_button,
		window_mode_option, resolution_option, vsync_check, fps_limit_option,
		show_fps_check, language_option,
	]

	for button in all_buttons:
		if button:
			button.pivot_offset = button.size / 2.0
			if not button.pressed.is_connected(_on_any_button_pressed):
				button.pressed.connect(_on_any_button_pressed)
			if not button.mouse_entered.is_connected(_on_button_hover_entered.bind(button)):
				button.mouse_entered.connect(_on_button_hover_entered.bind(button))
			if not button.mouse_exited.is_connected(_on_button_hover_exited.bind(button)):
				button.mouse_exited.connect(_on_button_hover_exited.bind(button))

	if not save_button.pressed.is_connected(_on_save_button_pressed):
		save_button.pressed.connect(_on_save_button_pressed)
	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

	_connect_slider(click_volume_slider, _on_click_volume_slider_value_changed)
	_connect_slider(hover_volume_slider, _on_hover_volume_slider_value_changed)
	_connect_slider(master_volume_slider, _on_master_volume_slider_value_changed)
	_connect_slider(music_volume_slider, _on_music_volume_slider_value_changed)
	_connect_slider(sfx_volume_slider, _on_sfx_volume_slider_value_changed)
	_connect_slider(ui_volume_slider, _on_ui_volume_slider_value_changed)
	_connect_slider(screen_shake_slider, _on_screen_shake_slider_value_changed)

	var window_mode_changed := _on_video_setting_changed.bind("window_mode")
	if not window_mode_option.item_selected.is_connected(window_mode_changed):
		window_mode_option.item_selected.connect(window_mode_changed)
	var resolution_changed := _on_video_setting_changed.bind("resolution")
	if not resolution_option.item_selected.is_connected(resolution_changed):
		resolution_option.item_selected.connect(resolution_changed)
	var fps_limit_changed := _on_video_setting_changed.bind("fps_limit")
	if not fps_limit_option.item_selected.is_connected(fps_limit_changed):
		fps_limit_option.item_selected.connect(fps_limit_changed)
	var vsync_toggled := _on_video_setting_toggled.bind("vsync")
	if not vsync_check.toggled.is_connected(vsync_toggled):
		vsync_check.toggled.connect(vsync_toggled)
	if not language_option.item_selected.is_connected(_on_language_option_item_selected):
		language_option.item_selected.connect(_on_language_option_item_selected)
	var show_fps_toggled := _on_video_setting_toggled.bind("show_fps")
	if not show_fps_check.toggled.is_connected(show_fps_toggled):
		show_fps_check.toggled.connect(show_fps_toggled)


func _connect_slider(slider: HSlider, change_handler: Callable) -> void:
	if not slider.value_changed.is_connected(change_handler):
		slider.value_changed.connect(change_handler)
	if not slider.mouse_entered.is_connected(_on_any_button_mouse_entered):
		slider.mouse_entered.connect(_on_any_button_mouse_entered)
	if not slider.gui_input.is_connected(_on_slider_gui_input):
		slider.gui_input.connect(_on_slider_gui_input)
	if not slider.drag_ended.is_connected(_on_slider_drag_ended):
		slider.drag_ended.connect(_on_slider_drag_ended)


# ---------------- BUTTON HOVER ANIMATION ----------------

func _on_button_hover_entered(btn: Button) -> void:
	_on_any_button_mouse_entered()
	_animate_button_scale(btn, 1.04)


func _on_button_hover_exited(btn: Button) -> void:
	_animate_button_scale(btn, 1.0)


func _animate_button_scale(btn: Button, target_scale: float) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	var current_tween = _button_tweens.get(btn) as Tween
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_button_tweens[btn] = t
	t.tween_property(btn, "scale", Vector2(target_scale, target_scale), 0.18)


# ---------------- AUDIO ----------------

func _on_any_button_pressed() -> void:
	if click_player and click_player.stream:
		click_player.play()


func _on_any_button_mouse_entered() -> void:
	if hover_player and hover_player.stream:
		hover_player.play()


func _on_slider_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		_on_any_button_pressed()


func _on_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		_on_any_button_pressed()


func _on_settings_volume_changed(type: String, linear_val: float, db_val: float) -> void:
	match type:
		"click":
			if click_player:
				click_player.volume_db = db_val
			if not suppress_change_tracking:
				click_volume_slider.value = linear_val
				_update_click_volume_label(linear_val)
		"hover":
			if hover_player:
				hover_player.volume_db = db_val
			if not suppress_change_tracking:
				hover_volume_slider.value = linear_val
				_update_hover_volume_label(linear_val)


func _apply_audio_players(click_val: float, hover_val: float) -> void:
	if click_player:
		click_player.volume_db = linear_to_db(max(click_val, 0.001))
	if hover_player:
		hover_player.volume_db = linear_to_db(max(hover_val, 0.001))


func _apply_bus_volume_preview(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(max(value, 0.001)))


# ---------------- UI EVENTS ----------------

func _on_back_button_pressed() -> void:
	if has_unsaved_changes:
		unsaved_changes_dialog.popup_centered()
	else:
		_request_close()


func _on_unsaved_discard_confirmed() -> void:
	var settings_mgr := _get_settings_manager()
	if settings_mgr:
		settings_mgr.load_settings()
		settings_mgr.apply_video_settings()
	_sync_from_settings_manager()
	_request_close()


func _request_close() -> void:
	close(true)


func _on_save_button_pressed() -> void:
	var settings_mgr := _get_settings_manager()
	if settings_mgr:
		settings_mgr.click_volume = click_volume_slider.value
		settings_mgr.hover_volume = hover_volume_slider.value
		settings_mgr.master_volume = master_volume_slider.value
		settings_mgr.music_volume = music_volume_slider.value
		settings_mgr.sfx_volume = sfx_volume_slider.value
		settings_mgr.ui_volume = ui_volume_slider.value

		settings_mgr.window_mode = window_mode_option.selected
		settings_mgr.resolution_index = _ui_resolution_index_to_settings_index(resolution_option.selected)
		settings_mgr.vsync_enabled = vsync_check.button_pressed
		settings_mgr.fps_limit_index = fps_limit_option.selected

		settings_mgr.screen_shake_intensity = screen_shake_slider.value

		settings_mgr.show_fps_overlay = show_fps_check.button_pressed
		settings_mgr.locale = LANGUAGE_CODES[language_option.selected]

		settings_mgr.save_settings()
		settings_mgr.apply_video_settings()

	has_unsaved_changes = false
	await _flash_save_button()


func _on_click_volume_slider_value_changed(value: float) -> void:
	_update_click_volume_label(value)
	if click_player:
		click_player.volume_db = linear_to_db(max(value, 0.001))
	_mark_unsaved_changes()


func _on_hover_volume_slider_value_changed(value: float) -> void:
	_update_hover_volume_label(value)
	if hover_player:
		hover_player.volume_db = linear_to_db(max(value, 0.001))
	_mark_unsaved_changes()


func _on_master_volume_slider_value_changed(value: float) -> void:
	_update_percent_label(master_volume_value_label, value)
	_apply_bus_volume_preview("Master", value)
	_mark_unsaved_changes()


func _on_music_volume_slider_value_changed(value: float) -> void:
	_update_percent_label(music_volume_value_label, value)
	_apply_bus_volume_preview("Music", value)
	_mark_unsaved_changes()


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	_update_percent_label(sfx_volume_value_label, value)
	_apply_bus_volume_preview("SFX", value)
	_mark_unsaved_changes()


func _on_ui_volume_slider_value_changed(value: float) -> void:
	_update_percent_label(ui_volume_value_label, value)
	_apply_bus_volume_preview("UI", value)
	_mark_unsaved_changes()


func _on_screen_shake_slider_value_changed(value: float) -> void:
	_update_percent_label(screen_shake_value_label, value)
	var settings_mgr := _get_settings_manager()
	if settings_mgr:
		settings_mgr.screen_shake_intensity = value
	_mark_unsaved_changes()


func _on_video_setting_changed(index: int, field: String) -> void:
	if suppress_change_tracking:
		return
	var settings_mgr := _get_settings_manager()
	if settings_mgr:
		match field:
			"window_mode":
				settings_mgr.window_mode = index
				settings_mgr.apply_window_mode()
				settings_mgr.apply_resolution()
			"resolution":
				settings_mgr.resolution_index = _ui_resolution_index_to_settings_index(index)
				settings_mgr.apply_resolution()
			"fps_limit":
				settings_mgr.fps_limit_index = index
				settings_mgr.apply_fps_limit()
	_mark_unsaved_changes()


func _on_video_setting_toggled(pressed: bool, field: String) -> void:
	if suppress_change_tracking:
		return
	var settings_mgr := _get_settings_manager()
	if settings_mgr:
		match field:
			"vsync":
				settings_mgr.vsync_enabled = pressed
				settings_mgr.apply_vsync()
			"show_fps":
				settings_mgr.show_fps_overlay = pressed
	_mark_unsaved_changes()


func _on_language_option_item_selected(index: int) -> void:
	TranslationServer.set_locale(LANGUAGE_CODES[index])
	_update_ui_text_translations()
	_mark_unsaved_changes()


## Reassigns every translated text/title in the menu from the current
## TranslationServer locale, live — no scene reload required.
func _update_ui_text_translations() -> void:
	options_tabs.set_tab_title(0, tr("KEY_TAB_VIDEO"))
	options_tabs.set_tab_title(1, tr("KEY_TAB_AUDIO"))
	options_tabs.set_tab_title(2, tr("KEY_TAB_GAMEPLAY"))

	for i in range(WINDOW_MODE_LABELS.size()):
		if i < window_mode_option.item_count:
			window_mode_option.set_item_text(i, tr(WINDOW_MODE_LABELS[i]))

	if _native_res_is_separate and _resolution_choices.size() > 0 and resolution_option.item_count > 0:
		var native: Vector2i = _resolution_choices[0]
		resolution_option.set_item_text(0, "%s (%dx%d)" % [tr("KEY_RESOLUTION_NATIVE"), native.x, native.y])

	window_mode_label.text = tr("KEY_WINDOW_MODE")
	resolution_label.text = tr("KEY_RESOLUTION")
	vsync_check.text = tr("KEY_VSYNC")
	fps_limit_label.text = tr("KEY_FPS_LIMIT")
	show_fps_check.text = tr("KEY_SHOW_FPS")
	language_label.text = tr("KEY_LANGUAGE")

	master_volume_label.text = tr("KEY_MASTER_VOL")
	music_volume_label.text = tr("KEY_MUSIC_VOL")
	sfx_volume_label.text = tr("KEY_SFX_VOL")
	ui_volume_label.text = tr("KEY_UI_VOL")

	screen_shake_label.text = tr("KEY_SCREEN_SHAKE")

	save_button.text = tr("KEY_SAVE")
	back_button.text = tr("KEY_BACK")

	unsaved_changes_dialog.title = tr("KEY_UNSAVED_TITLE")
	unsaved_changes_dialog.dialog_text = tr("KEY_UNSAVED_MSG")


func _update_click_volume_label(value: float) -> void:
	var percentage := int(round(value * 100.0))
	click_volume_value_label.text = "%d%%" % percentage


func _update_hover_volume_label(value: float) -> void:
	var percentage := int(round(value * 100.0))
	hover_volume_value_label.text = "%d%%" % percentage


func _update_percent_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(round(value * 100.0))


func _mark_unsaved_changes() -> void:
	if suppress_change_tracking:
		return
	has_unsaved_changes = true


func _flash_save_button() -> void:
	var previous_modulate := save_button.modulate
	save_button.modulate = Color(1.3, 1.3, 0.8, 1)
	await get_tree().create_timer(0.3).timeout
	save_button.modulate = previous_modulate

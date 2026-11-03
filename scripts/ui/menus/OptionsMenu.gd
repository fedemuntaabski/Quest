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
@onready var click_volume_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/ClickVolumeLabel
@onready var click_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/ClickVolumeRow/ClickVolumeSlider
@onready var click_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/ClickVolumeRow/ClickVolumeValueLabel
@onready var hover_volume_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/OptionsTabs/Audio/HoverVolumeLabel
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

	_apply_theme()
	_populate_option_buttons()
	_build_accessibility_tab()
	_build_controls_tab()
	_connect_menu_signals()
	_update_ui_text_translations()

	if not unsaved_changes_dialog.confirmed.is_connected(_on_unsaved_discard_confirmed):
		unsaved_changes_dialog.confirmed.connect(_on_unsaved_discard_confirmed)

	if not options_tabs.tab_changed.is_connected(_on_tab_changed):
		options_tabs.tab_changed.connect(_on_tab_changed)

	_sync_from_settings_manager()

	var settings_mgr := _get_settings_manager()
	if settings_mgr and not settings_mgr.volume_changed.is_connected(_on_settings_volume_changed):
		settings_mgr.volume_changed.connect(_on_settings_volume_changed)


func _apply_theme() -> void:
	if options_card:
		options_card.add_theme_stylebox_override("panel", UiStyles.build_panel_style(QuestPalette.DUNGEON_CHARCOAL, QuestPalette.GOLD_DARK, 3, 20))
	_style_button(save_button)
	_style_button(back_button)


func _style_button(button: Button, danger: bool = false) -> void:
	if button == null:
		return

	var border_base: Color = QuestPalette.BLOOD if danger else QuestPalette.GOLD_DARK
	var border_hover: Color = QuestPalette.BLOOD_LIGHT if danger else QuestPalette.GOLD_LIGHT
	var text_base: Color = QuestPalette.PARCHMENT
	var text_hover: Color = QuestPalette.PARCHMENT_LIGHT
	var text_pressed: Color = QuestPalette.BLOOD_LIGHT if danger else QuestPalette.GOLD

	button.add_theme_color_override("font_color", text_base)
	button.add_theme_color_override("font_focus_color", text_hover)
	button.add_theme_color_override("font_hover_color", text_hover)
	button.add_theme_color_override("font_pressed_color", text_pressed)
	button.add_theme_color_override("font_outline_color", QuestPalette.INK)
	button.add_theme_constant_override("outline_size", 3)

	button.add_theme_stylebox_override("normal", UiStyles.build_panel_style(QuestPalette.DUNGEON_MUD, border_base, 3, 16, 16))
	button.add_theme_stylebox_override("pressed", UiStyles.build_panel_style(QuestPalette.DUNGEON_CHARCOAL, border_base, 3, 16, 16))
	button.add_theme_stylebox_override("hover", UiStyles.build_panel_style(QuestPalette.DUNGEON_MUD, border_hover, 3, 16, 16))
	button.add_theme_stylebox_override("focus", UiStyles.build_panel_style(QuestPalette.DUNGEON_MUD, QuestPalette.PARCHMENT_LIGHT, 4, 16, 16))


func _on_tab_changed(tab_idx: int) -> void:
	match tab_idx:
		0: window_mode_option.grab_focus()
		1: master_volume_slider.grab_focus()
		2: screen_shake_slider.grab_focus()
		3: text_scale_slider.grab_focus()
		4:
			if _first_rebind_button:
				_first_rebind_button.grab_focus()


# ---------------- ACCESSIBILITY / CONTROLS (calidad-13, built in code) ----------------

var text_scale_slider: HSlider
var _text_scale_value: Label
var colorblind_check: CheckButton
var reduce_flashes_check: CheckButton
var captions_check: CheckButton
var first_help_check: CheckButton
var _controls_grid: GridContainer
var _controls_status: Label
var _first_rebind_button: Button
## [action, gamepad?] while waiting for the next key/button; empty otherwise.
var _capturing: Array = []
var _help: ControlsHelp


func _build_accessibility_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Accesibilidad"
	tab.add_theme_constant_override("separation", 12)
	options_tabs.add_child(tab)
	var label := Label.new()
	label.text = "Tamaño del texto"
	tab.add_child(label)
	var row := HBoxContainer.new()
	tab.add_child(row)
	text_scale_slider = HSlider.new()
	text_scale_slider.min_value = TEXT_SCALE_MIN
	text_scale_slider.max_value = TEXT_SCALE_MAX
	text_scale_slider.step = 0.1
	text_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_scale_slider)
	_text_scale_value = Label.new()
	_text_scale_value.custom_minimum_size = Vector2(70, 0)
	row.add_child(_text_scale_value)
	text_scale_slider.value_changed.connect(func(v: float) -> void:
		_update_percent_label(_text_scale_value, v)
		var mgr := _get_settings_manager()
		if mgr and not suppress_change_tracking:
			mgr.text_scale = v
		_mark_unsaved_changes())
	colorblind_check = _a11y_check(tab, "Modo daltónico (barras y rarezas con formas)", "colorblind_mode")
	reduce_flashes_check = _a11y_check(tab, "Reducir destellos y parpadeos", "reduce_flashes")
	captions_check = _a11y_check(tab, "Subtítulos para avisos sonoros", "sound_captions")
	first_help_check = _a11y_check(tab, "Mostrar ayudas de primera vez", "first_help_enabled")
	var help_again := Button.new()
	help_again.text = "Volver a ver las ayudas"
	help_again.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	help_again.pressed.connect(func() -> void:
		var mgr := _get_settings_manager()
		if mgr:
			mgr.reset_help())
	tab.add_child(help_again)
	var note := Label.new()
	note.text = "El temblor de cámara se ajusta en Jugabilidad (0 % lo desactiva).\nEl tamaño del texto se aplica por completo a las pantallas que se abran después."
	note.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	tab.add_child(note)
	var logs := Button.new()
	logs.text = "Abrir carpeta de registros"
	logs.tooltip_text = "Para reportar un error: adjunta el archivo quest.log más reciente."
	logs.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path("user://logs")))
	logs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab.add_child(logs)


const TEXT_SCALE_MIN := 0.8  # = SettingsManager.TEXT_SCALE_MIN/MAX
const TEXT_SCALE_MAX := 1.5


func _a11y_check(parent: Control, text: String, setting: String) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	parent.add_child(check)
	check.toggled.connect(func(on: bool) -> void:
		var mgr := _get_settings_manager()
		if mgr and not suppress_change_tracking:
			mgr.set(setting, on)
			if setting == "reduce_flashes" and on:
				screen_shake_slider.value = 0.0  # the camera shake goes with it
		_mark_unsaved_changes())
	return check


func _build_controls_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Controles"
	options_tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)
	_controls_grid = GridContainer.new()
	_controls_grid.columns = 4
	_controls_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_controls_grid)
	_controls_status = Label.new()
	_controls_status.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT)
	_controls_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(_controls_status)
	var buttons := HBoxContainer.new()
	tab.add_child(buttons)
	var reset := Button.new()
	reset.text = "Restablecer todo"
	reset.pressed.connect(func() -> void:
		InputBindings.reset_all()
		_refresh_controls()
		_mark_unsaved_changes())
	buttons.add_child(reset)
	var help := Button.new()
	help.text = "Ver todos los atajos"
	help.pressed.connect(func() -> void:
		if _help == null:
			_help = ControlsHelp.new()
			add_child(_help)
		_help.open())
	buttons.add_child(help)
	_refresh_controls()


func _refresh_controls() -> void:
	for child in _controls_grid.get_children():
		child.queue_free()
	_first_rebind_button = null
	for action in InputBindings.REMAPPABLE:
		var name_label := Label.new()
		name_label.text = InputBindings.REMAPPABLE[action]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_controls_grid.add_child(name_label)
		for gamepad in [false, true]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(150, 0)
			b.text = InputBindings.label(action, gamepad)
			b.tooltip_text = "Cambiar (%s)" % ("mando" if gamepad else "teclado")
			b.pressed.connect(_start_capture.bind(action, gamepad, b))
			_controls_grid.add_child(b)
			if _first_rebind_button == null:
				_first_rebind_button = b
		var r := Button.new()
		r.text = "↺"
		r.tooltip_text = "Restablecer"
		r.pressed.connect(func() -> void:
			InputBindings.reset(action)
			_refresh_controls()
			_mark_unsaved_changes())
		_controls_grid.add_child(r)


func _start_capture(action: String, gamepad: bool, button: Button) -> void:
	_capturing = [action, gamepad]
	button.text = "..."
	_controls_status.text = "Pulsa %s para \"%s\" (Esc cancela)." % ["un botón del mando" if gamepad else "una tecla", InputBindings.REMAPPABLE[action]]


## While capturing, the next key / gamepad button / stick push becomes the binding.
func _input(event: InputEvent) -> void:
	if _capturing.is_empty() or not visible:
		return
	var gamepad: bool = _capturing[1]
	var captured: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_capturing = []
			_controls_status.text = "Cancelado."
			_refresh_controls()
			get_viewport().set_input_as_handled()
			return
		if not gamepad and not event.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
			captured = InputBindings.decode(InputBindings.encode(event))  # clean copy (no echo/pressed state)
	elif gamepad and event is InputEventJoypadButton and event.pressed:
		captured = InputBindings.decode(InputBindings.encode(event))
	elif gamepad and event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
		captured = InputBindings.decode(InputBindings.encode(event))
	if captured == null:
		return
	get_viewport().set_input_as_handled()
	var action: String = _capturing[0]
	_capturing = []
	var clash := InputBindings.conflicts(action, captured)
	InputBindings.rebind(action, captured, gamepad)
	_controls_status.text = "%s → %s" % [InputBindings.REMAPPABLE[action], InputBindings.event_label(captured)]
	if not clash.is_empty():
		var names := clash.map(func(a: String) -> String: return InputBindings.REMAPPABLE[a])
		_controls_status.text += "  (también la usa: %s)" % ", ".join(names)
	_refresh_controls()
	_mark_unsaved_changes()


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

	if settings_mgr:
		text_scale_slider.value = settings_mgr.text_scale
		_update_percent_label(_text_scale_value, text_scale_slider.value)
		colorblind_check.button_pressed = settings_mgr.colorblind_mode
		reduce_flashes_check.button_pressed = settings_mgr.reduce_flashes
		captions_check.button_pressed = settings_mgr.sound_captions
		first_help_check.button_pressed = settings_mgr.first_help_enabled
	_capturing = []
	_refresh_controls()

	suppress_change_tracking = false
	has_unsaved_changes = false


func open() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_sync_from_settings_manager()
	visible = true
	_set_transition_buttons_disabled(true)

	var scale_targets: Array[CanvasItem] = []
	if options_card:
		scale_targets.append(options_card)

	_active_tween = MenuTransitionFX.play_entrance(
		self,
		[{"node": self, "max_alpha": 1.0}],
		scale_targets,
		0.28, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, Vector2(0.92, 0.92)
	)
	if _active_tween != null:
		await _active_tween.finished

	_set_transition_buttons_disabled(false)


func close(animate: bool = true) -> void:
	if not visible:
		return

	if not animate:
		visible = false
		return

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_set_transition_buttons_disabled(true)

	var scale_targets: Array[CanvasItem] = []
	if options_card:
		scale_targets.append(options_card)

	_active_tween = MenuTransitionFX.play_exit(
		self,
		[{"node": self, "max_alpha": 1.0}],
		scale_targets,
		0.28, Vector2(0.92, 0.92),
		Tween.TRANS_CUBIC, Tween.EASE_IN_OUT
	)
	if _active_tween != null:
		await _active_tween.finished

	visible = false
	closed.emit()


func _set_transition_buttons_disabled(is_disabled: bool) -> void:
	if save_button:
		save_button.disabled = is_disabled
	if back_button:
		back_button.disabled = is_disabled


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
	if options_tabs.get_tab_count() > 4:
		options_tabs.set_tab_title(3, "Accesibilidad")
		options_tabs.set_tab_title(4, "Controles")

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
	click_volume_label.text = tr("KEY_CLICK_VOL")
	hover_volume_label.text = tr("KEY_HOVER_VOL")

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

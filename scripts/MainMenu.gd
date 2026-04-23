extends Control

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "options"
const RESOLUTION_PRESETS := [
	{"label": "1920x1080", "size": Vector2i(1920, 1080)},
	{"label": "1600x900", "size": Vector2i(1600, 900)},
	{"label": "1280x720", "size": Vector2i(1280, 720)}
]

@onready var center_container: CenterContainer = $CenterContainer
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitMargin/ExitButton
@onready var options_panel: Panel = $OptionsPanel
@onready var click_volume_slider: HSlider = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/ClickVolumeRow/ClickVolumeSlider
@onready var click_volume_value_label: Label = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/ClickVolumeRow/ClickVolumeValueLabel
@onready var hover_volume_slider: HSlider = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/HoverVolumeRow/HoverVolumeSlider
@onready var hover_volume_value_label: Label = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/HoverVolumeRow/HoverVolumeValueLabel
@onready var res_selector: OptionButton = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/ResSelector
@onready var fullscreen_toggle: CheckButton = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/FullscreenToggle
@onready var save_button: Button = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/SaveButton
@onready var back_button: Button = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/BackButton
@onready var unsaved_changes_dialog: ConfirmationDialog = $UnsavedChangesDialog
@onready var click_sound: AudioStreamPlayer = $click
@onready var hover_sound: AudioStreamPlayer = $hover

var has_unsaved_changes: bool = false
var suppress_change_tracking: bool = false

func _ready() -> void:
	_setup_content_scaling()
	_populate_resolution_selector()
	_connect_menu_signals()
	_set_options_panel_visible(false)
	_sync_selector_with_current_resolution()
	if not unsaved_changes_dialog.confirmed.is_connected(_on_unsaved_discard_confirmed):
		unsaved_changes_dialog.confirmed.connect(_on_unsaved_discard_confirmed)
	suppress_change_tracking = true
	load_settings()
	suppress_change_tracking = false
	_apply_click_volume(click_volume_slider.value)
	_apply_hover_volume(hover_volume_slider.value)
	_update_click_volume_label(click_volume_slider.value)
	_update_hover_volume_label(hover_volume_slider.value)
	has_unsaved_changes = false

func _setup_content_scaling() -> void:
	var root_window: Window = get_tree().root
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

func _populate_resolution_selector() -> void:
	res_selector.clear()
	for preset in RESOLUTION_PRESETS:
		res_selector.add_item(preset["label"])

func _connect_menu_signals() -> void:
	var all_buttons: Array[BaseButton] = [
		start_button,
		options_button,
		exit_button,
		save_button,
		back_button,
		fullscreen_toggle,
		res_selector
	]

	for button in all_buttons:
		if button and not button.pressed.is_connected(_on_any_button_pressed):
			button.pressed.connect(_on_any_button_pressed)
		if button and not button.mouse_entered.is_connected(_on_any_button_mouse_entered):
			button.mouse_entered.connect(_on_any_button_mouse_entered)

	if not options_button.pressed.is_connected(_on_options_button_pressed):
		options_button.pressed.connect(_on_options_button_pressed)
	if not save_button.pressed.is_connected(_on_save_button_pressed):
		save_button.pressed.connect(_on_save_button_pressed)
	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)
	if not click_volume_slider.value_changed.is_connected(_on_click_volume_slider_value_changed):
		click_volume_slider.value_changed.connect(_on_click_volume_slider_value_changed)
	if not click_volume_slider.mouse_entered.is_connected(_on_click_volume_slider_mouse_entered):
		click_volume_slider.mouse_entered.connect(_on_click_volume_slider_mouse_entered)
	if not click_volume_slider.gui_input.is_connected(_on_click_volume_slider_gui_input):
		click_volume_slider.gui_input.connect(_on_click_volume_slider_gui_input)
	if not click_volume_slider.drag_ended.is_connected(_on_click_volume_slider_drag_ended):
		click_volume_slider.drag_ended.connect(_on_click_volume_slider_drag_ended)

	if not hover_volume_slider.value_changed.is_connected(_on_hover_volume_slider_value_changed):
		hover_volume_slider.value_changed.connect(_on_hover_volume_slider_value_changed)
	if not hover_volume_slider.mouse_entered.is_connected(_on_hover_volume_slider_mouse_entered):
		hover_volume_slider.mouse_entered.connect(_on_hover_volume_slider_mouse_entered)
	if not hover_volume_slider.gui_input.is_connected(_on_hover_volume_slider_gui_input):
		hover_volume_slider.gui_input.connect(_on_hover_volume_slider_gui_input)
	if not hover_volume_slider.drag_ended.is_connected(_on_hover_volume_slider_drag_ended):
		hover_volume_slider.drag_ended.connect(_on_hover_volume_slider_drag_ended)

	if not res_selector.item_selected.is_connected(_on_res_selector_item_selected):
		res_selector.item_selected.connect(_on_res_selector_item_selected)
	if not fullscreen_toggle.toggled.is_connected(_on_fullscreen_toggled):
		fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)

func _on_any_button_pressed() -> void:
	if click_sound and click_sound.stream:
		click_sound.play()

func _on_any_button_mouse_entered() -> void:
	if hover_sound and hover_sound.stream:
		hover_sound.play()

func _set_options_panel_visible(visible_value: bool) -> void:
	options_panel.visible = visible_value
	center_container.visible = not visible_value

func _on_options_button_pressed() -> void:
	_set_options_panel_visible(true)

func _on_back_button_pressed() -> void:
	if has_unsaved_changes:
		unsaved_changes_dialog.popup_centered()
	else:
		_set_options_panel_visible(false)

func _on_unsaved_discard_confirmed() -> void:
	has_unsaved_changes = false
	_set_options_panel_visible(false)

func _on_save_button_pressed() -> void:
	save_settings()
	has_unsaved_changes = false
	await _flash_save_button()

func _on_click_volume_slider_value_changed(value: float) -> void:
	_apply_click_volume(value)
	_update_click_volume_label(value)
	_mark_unsaved_changes()

func _on_hover_volume_slider_value_changed(value: float) -> void:
	_apply_hover_volume(value)
	_update_hover_volume_label(value)
	_mark_unsaved_changes()

func _on_click_volume_slider_mouse_entered() -> void:
	_on_any_button_mouse_entered()

func _on_hover_volume_slider_mouse_entered() -> void:
	_on_any_button_mouse_entered()

func _on_click_volume_slider_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		_on_any_button_pressed()

func _on_hover_volume_slider_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		_on_any_button_pressed()

func _on_click_volume_slider_drag_ended(value_changed: bool) -> void:
	if value_changed and click_sound and click_sound.stream:
		click_sound.play()

func _on_hover_volume_slider_drag_ended(value_changed: bool) -> void:
	if value_changed and hover_sound and hover_sound.stream:
		hover_sound.play()

func _update_click_volume_label(value: float) -> void:
	var percentage := int(round(value * 100.0))
	click_volume_value_label.text = "%d%%" % percentage

func _update_hover_volume_label(value: float) -> void:
	var percentage := int(round(value * 100.0))
	hover_volume_value_label.text = "%d%%" % percentage

func _mark_unsaved_changes() -> void:
	if suppress_change_tracking:
		return
	has_unsaved_changes = true

func _apply_click_volume(value: float) -> void:
	click_sound.volume_db = linear_to_db(max(value, 0.001))

func _apply_hover_volume(value: float) -> void:
	hover_sound.volume_db = linear_to_db(max(value, 0.001))

func _flash_save_button() -> void:
	var previous_modulate := save_button.modulate
	save_button.modulate = Color(1.2, 1.2, 0.85, 1)
	await get_tree().create_timer(0.5).timeout
	save_button.modulate = previous_modulate

func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_on_res_selector_item_selected(res_selector.selected)
	_mark_unsaved_changes()

func _on_res_selector_item_selected(index: int) -> void:
	var safe_index := clampi(index, 0, RESOLUTION_PRESETS.size() - 1)
	var target_size: Vector2i = RESOLUTION_PRESETS[safe_index]["size"]
	DisplayServer.window_set_size(target_size)
	get_tree().root.content_scale_size = target_size
	if res_selector.selected != safe_index:
		res_selector.select(safe_index)
	_mark_unsaved_changes()

func _sync_selector_with_current_resolution() -> void:
	var current_size := DisplayServer.window_get_size()
	var found_index := -1

	for i in RESOLUTION_PRESETS.size():
		var candidate: Vector2i = RESOLUTION_PRESETS[i]["size"]
		if candidate == current_size:
			found_index = i
			break

	if found_index == -1:
		found_index = 0

	res_selector.select(found_index)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SETTINGS_SECTION, "resolution_index", res_selector.selected)
	cfg.set_value(SETTINGS_SECTION, "fullscreen", fullscreen_toggle.button_pressed)
	cfg.set_value(SETTINGS_SECTION, "click_volume", click_volume_slider.value)
	cfg.set_value(SETTINGS_SECTION, "hover_volume", hover_volume_slider.value)
	var save_error := cfg.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("MainMenu: Failed to save settings (%s)" % save_error)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var load_error := cfg.load(SETTINGS_PATH)
	if load_error != OK:
		return

	var saved_index := int(cfg.get_value(SETTINGS_SECTION, "resolution_index", res_selector.selected))
	_on_res_selector_item_selected(saved_index)

	var fullscreen_enabled := bool(cfg.get_value(SETTINGS_SECTION, "fullscreen", false))
	fullscreen_toggle.button_pressed = fullscreen_enabled
	_on_fullscreen_toggled(fullscreen_enabled)

	var saved_click_volume := float(cfg.get_value(SETTINGS_SECTION, "click_volume", click_volume_slider.value))
	click_volume_slider.value = clampf(saved_click_volume, 0.001, 2.0)
	_apply_click_volume(click_volume_slider.value)
	_update_click_volume_label(click_volume_slider.value)

	var saved_hover_volume := float(cfg.get_value(SETTINGS_SECTION, "hover_volume", hover_volume_slider.value))
	hover_volume_slider.value = clampf(saved_hover_volume, 0.001, 2.0)
	_apply_hover_volume(hover_volume_slider.value)
	_update_hover_volume_label(hover_volume_slider.value)

func on_start_button_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scenes/Main2d.tscn")

func on_exit_button_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

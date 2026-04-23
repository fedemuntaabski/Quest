extends CanvasLayer

class_name PauseMenu

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "options"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const RESOLUTION_PRESETS := [
	{"label": "1920x1080", "size": Vector2i(1920, 1080)},
	{"label": "1600x900", "size": Vector2i(1600, 900)},
	{"label": "1280x720", "size": Vector2i(1280, 720)}
]

@onready var pause_panel: Panel = $CenterContainer/PausePanel
@onready var continue_button: Button = $CenterContainer/PausePanel/PauseVBox/ContinueButton
@onready var options_button: Button = $CenterContainer/PausePanel/PauseVBox/OptionsButton
@onready var exit_button: Button = $CenterContainer/PausePanel/PauseVBox/ExitButton

@onready var options_panel: Panel = $OptionsPanel
@onready var click_volume_slider: HSlider = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/ClickVolumeRow/ClickVolumeSlider
@onready var click_volume_value_label: Label = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/ClickVolumeRow/ClickVolumeValueLabel
@onready var hover_volume_slider: HSlider = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/HoverVolumeRow/HoverVolumeSlider
@onready var hover_volume_value_label: Label = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/HoverVolumeRow/HoverVolumeValueLabel
@onready var res_selector: OptionButton = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/ResSelector
@onready var save_button: Button = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/SaveButton
@onready var back_button: Button = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/BackButton

var suppress_change_tracking: bool = false
var has_unsaved_changes: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	_populate_resolution_selector()
	_connect_signals()

	suppress_change_tracking = true
	load_settings()
	suppress_change_tracking = false

	_update_click_volume_label(click_volume_slider.value)
	_update_hover_volume_label(hover_volume_slider.value)
	_set_options_panel_visible(false)
	_set_pause_panel_visible(true)

func open_menu() -> void:
	visible = true
	_set_options_panel_visible(false)
	_set_pause_panel_visible(true)

func close_menu() -> void:
	visible = false
	has_unsaved_changes = false
	_set_options_panel_visible(false)
	_set_pause_panel_visible(true)

func _set_pause_panel_visible(visible_value: bool) -> void:
	pause_panel.visible = visible_value

func _set_options_panel_visible(visible_value: bool) -> void:
	options_panel.visible = visible_value

func _populate_resolution_selector() -> void:
	res_selector.clear()
	for preset in RESOLUTION_PRESETS:
		res_selector.add_item(preset["label"])

func _connect_signals() -> void:
	if not continue_button.pressed.is_connected(_on_continue_button_pressed):
		continue_button.pressed.connect(_on_continue_button_pressed)
	if not options_button.pressed.is_connected(_on_options_button_pressed):
		options_button.pressed.connect(_on_options_button_pressed)
	if not exit_button.pressed.is_connected(_on_exit_button_pressed):
		exit_button.pressed.connect(_on_exit_button_pressed)
	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)
	if not save_button.pressed.is_connected(_on_save_button_pressed):
		save_button.pressed.connect(_on_save_button_pressed)

	if not click_volume_slider.value_changed.is_connected(_on_click_volume_slider_value_changed):
		click_volume_slider.value_changed.connect(_on_click_volume_slider_value_changed)
	if not hover_volume_slider.value_changed.is_connected(_on_hover_volume_slider_value_changed):
		hover_volume_slider.value_changed.connect(_on_hover_volume_slider_value_changed)
	if not res_selector.item_selected.is_connected(_on_res_selector_item_selected):
		res_selector.item_selected.connect(_on_res_selector_item_selected)

func _on_continue_button_pressed() -> void:
	get_tree().paused = false
	close_menu()

func _on_options_button_pressed() -> void:
	_set_pause_panel_visible(false)
	_set_options_panel_visible(true)

func _on_exit_button_pressed() -> void:
	get_tree().paused = false
	close_menu()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_back_button_pressed() -> void:
	has_unsaved_changes = false
	_set_options_panel_visible(false)
	_set_pause_panel_visible(true)

func _on_save_button_pressed() -> void:
	save_settings()
	has_unsaved_changes = false

func _on_click_volume_slider_value_changed(value: float) -> void:
	_update_click_volume_label(value)
	_mark_unsaved_changes()

func _on_hover_volume_slider_value_changed(value: float) -> void:
	_update_hover_volume_label(value)
	_mark_unsaved_changes()

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

func _on_res_selector_item_selected(index: int) -> void:
	var safe_index := clampi(index, 0, RESOLUTION_PRESETS.size() - 1)
	var target_size: Vector2i = RESOLUTION_PRESETS[safe_index]["size"]
	DisplayServer.window_set_size(target_size)
	get_tree().root.content_scale_size = target_size
	if res_selector.selected != safe_index:
		res_selector.select(safe_index)
	_mark_unsaved_changes()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SETTINGS_SECTION, "resolution_index", res_selector.selected)
	cfg.set_value(SETTINGS_SECTION, "click_volume", click_volume_slider.value)
	cfg.set_value(SETTINGS_SECTION, "hover_volume", hover_volume_slider.value)
	var save_error := cfg.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("PauseMenu: Failed to save settings (%s)" % save_error)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var load_error := cfg.load(SETTINGS_PATH)
	if load_error != OK:
		return

	var saved_index := int(cfg.get_value(SETTINGS_SECTION, "resolution_index", res_selector.selected))
	_on_res_selector_item_selected(saved_index)

	var saved_click_volume := float(cfg.get_value(SETTINGS_SECTION, "click_volume", click_volume_slider.value))
	click_volume_slider.value = clampf(saved_click_volume, 0.001, 2.0)
	_update_click_volume_label(click_volume_slider.value)

	var saved_hover_volume := float(cfg.get_value(SETTINGS_SECTION, "hover_volume", hover_volume_slider.value))
	hover_volume_slider.value = clampf(saved_hover_volume, 0.001, 2.0)
	_update_hover_volume_label(hover_volume_slider.value)

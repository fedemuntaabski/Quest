extends Control
class_name OptionsMenu

signal closed

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "options"

@export var click_player_path: NodePath
@export var hover_player_path: NodePath

@onready var click_player: AudioStreamPlayer = get_node_or_null(click_player_path)
@onready var hover_player: AudioStreamPlayer = get_node_or_null(hover_player_path)

@onready var click_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/ClickVolumeRow/ClickVolumeSlider
@onready var click_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/ClickVolumeRow/ClickVolumeValueLabel
@onready var hover_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/HoverVolumeRow/HoverVolumeSlider
@onready var hover_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/HoverVolumeRow/HoverVolumeValueLabel
@onready var save_button: Button = $OptionsCenterContainer/OptionsCard/OptionsVBox/SaveButton
@onready var back_button: Button = $OptionsCenterContainer/OptionsCard/OptionsVBox/BackButton
@onready var unsaved_changes_dialog: ConfirmationDialog = $UnsavedChangesDialog

var has_unsaved_changes: bool = false
var suppress_change_tracking: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_connect_menu_signals()

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

func open() -> void:
	visible = true

func close() -> void:
	visible = false

# ---------------- CONNECT ----------------

func _connect_menu_signals() -> void:
	var all_buttons: Array[BaseButton] = [save_button, back_button]

	for button in all_buttons:
		if button and not button.pressed.is_connected(_on_any_button_pressed):
			button.pressed.connect(_on_any_button_pressed)
		if button and not button.mouse_entered.is_connected(_on_any_button_mouse_entered):
			button.mouse_entered.connect(_on_any_button_mouse_entered)

	if not save_button.pressed.is_connected(_on_save_button_pressed):
		save_button.pressed.connect(_on_save_button_pressed)
	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

	_connect_slider(click_volume_slider, _on_click_volume_slider_value_changed)
	_connect_slider(hover_volume_slider, _on_hover_volume_slider_value_changed)

func _connect_slider(slider: HSlider, change_handler: Callable) -> void:
	if not slider.value_changed.is_connected(change_handler):
		slider.value_changed.connect(change_handler)
	if not slider.mouse_entered.is_connected(_on_any_button_mouse_entered):
		slider.mouse_entered.connect(_on_any_button_mouse_entered)
	if not slider.gui_input.is_connected(_on_slider_gui_input):
		slider.gui_input.connect(_on_slider_gui_input)
	if not slider.drag_ended.is_connected(_on_slider_drag_ended):
		slider.drag_ended.connect(_on_slider_drag_ended)

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

# ---------------- UI ----------------

func _on_back_button_pressed() -> void:
	if has_unsaved_changes:
		unsaved_changes_dialog.popup_centered()
	else:
		_request_close()

func _on_unsaved_discard_confirmed() -> void:
	has_unsaved_changes = false
	_request_close()

func _request_close() -> void:
	close()
	closed.emit()

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
	if click_player:
		click_player.volume_db = linear_to_db(max(value, 0.001))

func _apply_hover_volume(value: float) -> void:
	if hover_player:
		hover_player.volume_db = linear_to_db(max(value, 0.001))

func _flash_save_button() -> void:
	var previous_modulate := save_button.modulate
	save_button.modulate = Color(1.2, 1.2, 0.85, 1)
	await get_tree().create_timer(0.5).timeout
	save_button.modulate = previous_modulate

# ---------------- SETTINGS ----------------

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SETTINGS_SECTION, "click_volume", click_volume_slider.value)
	cfg.set_value(SETTINGS_SECTION, "hover_volume", hover_volume_slider.value)
	var save_error := cfg.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("OptionsMenu: Failed to save settings (%s)" % save_error)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var load_error := cfg.load(SETTINGS_PATH)
	if load_error != OK:
		return

	var saved_click_volume := float(cfg.get_value(SETTINGS_SECTION, "click_volume", click_volume_slider.value))
	click_volume_slider.value = clampf(saved_click_volume, 0.001, 2.0)
	_apply_click_volume(click_volume_slider.value)
	_update_click_volume_label(click_volume_slider.value)

	var saved_hover_volume := float(cfg.get_value(SETTINGS_SECTION, "hover_volume", hover_volume_slider.value))
	hover_volume_slider.value = clampf(saved_hover_volume, 0.001, 2.0)
	_apply_hover_volume(hover_volume_slider.value)
	_update_hover_volume_label(hover_volume_slider.value)

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
@onready var click_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/ClickVolumeRow/ClickVolumeSlider
@onready var click_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/ClickVolumeRow/ClickVolumeValueLabel
@onready var hover_volume_slider: HSlider = $OptionsCenterContainer/OptionsCard/OptionsVBox/HoverVolumeRow/HoverVolumeSlider
@onready var hover_volume_value_label: Label = $OptionsCenterContainer/OptionsCard/OptionsVBox/HoverVolumeRow/HoverVolumeValueLabel
@onready var save_button: Button = $OptionsCenterContainer/OptionsCard/OptionsVBox/SaveButton
@onready var back_button: Button = $OptionsCenterContainer/OptionsCard/OptionsVBox/BackButton
@onready var unsaved_changes_dialog: ConfirmationDialog = $UnsavedChangesDialog

var has_unsaved_changes: bool = false
var suppress_change_tracking: bool = false
var _active_tween: Tween = null
var _button_tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_connect_menu_signals()

	if not unsaved_changes_dialog.confirmed.is_connected(_on_unsaved_discard_confirmed):
		unsaved_changes_dialog.confirmed.connect(_on_unsaved_discard_confirmed)

	_sync_from_settings_manager()

	var settings_mgr := _get_settings_manager()
	if settings_mgr and not settings_mgr.volume_changed.is_connected(_on_settings_volume_changed):
		settings_mgr.volume_changed.connect(_on_settings_volume_changed)


func _get_settings_manager() -> Node:
	if Engine.has_singleton("SettingsManager"):
		return Engine.get_singleton("SettingsManager")
	var root := get_tree().root if get_tree() else null
	if root and root.has_node("SettingsManager"):
		return root.get_node("SettingsManager")
	return null


func _sync_from_settings_manager() -> void:
	suppress_change_tracking = true
	var settings_mgr := _get_settings_manager()

	var click_vol := 1.0
	var hover_vol := 1.0

	if settings_mgr:
		click_vol = settings_mgr.click_volume
		hover_vol = settings_mgr.hover_volume

	click_volume_slider.value = clampf(click_vol, 0.001, 2.0)
	hover_volume_slider.value = clampf(hover_vol, 0.001, 2.0)

	_update_click_volume_label(click_volume_slider.value)
	_update_hover_volume_label(hover_volume_slider.value)
	_apply_audio_players(click_volume_slider.value, hover_volume_slider.value)

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
	var all_buttons: Array[BaseButton] = [save_button, back_button]

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


# ---------------- UI EVENTS ----------------

func _on_back_button_pressed() -> void:
	if has_unsaved_changes:
		unsaved_changes_dialog.popup_centered()
	else:
		_request_close()


func _on_unsaved_discard_confirmed() -> void:
	_sync_from_settings_manager()
	_request_close()


func _request_close() -> void:
	close(true)


func _on_save_button_pressed() -> void:
	var settings_mgr := _get_settings_manager()
	if settings_mgr:
		settings_mgr.click_volume = click_volume_slider.value
		settings_mgr.hover_volume = hover_volume_slider.value
		settings_mgr.save_settings()

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


func _flash_save_button() -> void:
	var previous_modulate := save_button.modulate
	save_button.modulate = Color(1.3, 1.3, 0.8, 1)
	await get_tree().create_timer(0.3).timeout
	save_button.modulate = previous_modulate

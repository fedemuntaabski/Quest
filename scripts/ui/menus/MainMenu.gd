extends Control

@onready var center_container: CenterContainer = $CenterContainer
@onready var main_vbox: VBoxContainer = $CenterContainer/VBoxContainer

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton
@onready var credit_button: Button = $CenterContainer/VBoxContainer/CreditsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitMargin/ExitButton

@onready var options_menu: OptionsMenu = $OptionsMenu

@onready var click_sound: AudioStreamPlayer = $click
@onready var hover_sound: AudioStreamPlayer = $hover

var flow: MainMenuFlow
var _button_tweens: Dictionary = {}


func _ready() -> void:
	$AnimationPlayer.play("menu_intro")
	_setup_content_scaling()
	_apply_audio_settings()
	_connect_signals()

	start_button.grab_focus()

	flow = MainMenuFlow.new()
	flow.setup(
		self,
		center_container,
		main_vbox,
		options_menu,
		click_sound,
		hover_sound
	)

	flow.build_slot_selector(start_button)

	if options_menu:
		options_menu.close(false)


func _setup_content_scaling() -> void:
	var root_window: Window = get_tree().root
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


func _apply_audio_settings() -> void:
	var settings_mgr = _get_settings_manager()
	if settings_mgr:
		settings_mgr.apply_volume_to_player(click_sound, "click")
		settings_mgr.apply_volume_to_player(hover_sound, "hover")
		if not settings_mgr.volume_changed.is_connected(_on_volume_changed):
			settings_mgr.volume_changed.connect(_on_volume_changed)


func _get_settings_manager() -> Node:
	if Engine.has_singleton("SettingsManager"):
		return Engine.get_singleton("SettingsManager")
	var root := get_tree().root if get_tree() else null
	if root and root.has_node("SettingsManager"):
		return root.get_node("SettingsManager")
	return null


func _on_volume_changed(type: String, _linear_val: float, db_val: float) -> void:
	match type:
		"click":
			if click_sound:
				click_sound.volume_db = db_val
		"hover":
			if hover_sound:
				hover_sound.volume_db = db_val


func _connect_signals() -> void:
	var buttons: Array[Button] = [
		start_button,
		options_button,
		credit_button,
		exit_button
	]

	for btn in buttons:
		if btn:
			btn.pivot_offset = btn.size / 2.0
			if not btn.mouse_entered.is_connected(_on_button_hover_entered.bind(btn)):
				btn.mouse_entered.connect(_on_button_hover_entered.bind(btn))
			if not btn.mouse_exited.is_connected(_on_button_hover_exited.bind(btn)):
				btn.mouse_exited.connect(_on_button_hover_exited.bind(btn))
			if not btn.focus_entered.is_connected(_on_button_hover_entered.bind(btn)):
				btn.focus_entered.connect(_on_button_hover_entered.bind(btn))
			if not btn.focus_exited.is_connected(_on_button_hover_exited.bind(btn)):
				btn.focus_exited.connect(_on_button_hover_exited.bind(btn))

	if options_menu and not options_menu.closed.is_connected(_on_options_menu_closed):
		options_menu.closed.connect(_on_options_menu_closed)


func _on_button_hover_entered(btn: Button) -> void:
	_play_hover()
	_animate_button_scale(btn, 1.05)


func _on_button_hover_exited(btn: Button) -> void:
	_animate_button_scale(btn, 1.0)


func _animate_button_scale(btn: Button, target_scale: float) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	var cur_tween = _button_tweens.get(btn) as Tween
	if cur_tween and cur_tween.is_valid():
		cur_tween.kill()

	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_button_tweens[btn] = t
	t.tween_property(btn, "scale", Vector2(target_scale, target_scale), 0.16)


func _play_hover() -> void:
	if hover_sound and hover_sound.stream and not hover_sound.playing:
		hover_sound.play()


func _play_click() -> void:
	if click_sound and click_sound.stream:
		click_sound.play()


func _on_options_menu_closed() -> void:
	if flow:
		flow.show_main_menu()


func on_start_button_pressed() -> void:
	_play_click()
	if flow:
		flow.start_pressed()


func _on_options_button_pressed() -> void:
	_play_click()
	if flow:
		flow.show_options_menu()


func _on_credits_button_pressed() -> void:
	_play_click()
	QuestLogger.info(QuestLogger.Category.UI, "Credits button pressed")
	if flow:
		flow.credits_pressed()


func on_exit_button_pressed() -> void:
	_play_click()
	if flow:
		flow.exit_pressed()

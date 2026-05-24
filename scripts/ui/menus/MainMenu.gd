extends Control

@onready var center_container: CenterContainer = $CenterContainer
@onready var main_vbox: VBoxContainer = $CenterContainer/VBoxContainer
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitMargin/ExitButton
@onready var options_menu: OptionsMenu = $OptionsMenu
@onready var click_sound: AudioStreamPlayer = $click
@onready var hover_sound: AudioStreamPlayer = $hover

var flow: MainMenuFlow = null

func _ready() -> void:
	_setup_content_scaling()
	_connect_menu_signals()

	flow = MainMenuFlow.new()
	flow.setup(self, center_container, main_vbox, options_menu, click_sound, hover_sound)
	flow.build_slot_selector(start_button)

	if options_menu and not options_menu.closed.is_connected(_on_options_menu_closed):
		options_menu.closed.connect(_on_options_menu_closed)
	if options_menu:
		options_menu.close()

func _setup_content_scaling() -> void:
	var root_window: Window = get_tree().root
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func _connect_menu_signals() -> void:
	var hover_targets: Array[BaseButton] = [
		start_button,
		options_button,
		exit_button
	]

	for button in hover_targets:
		if button and not button.mouse_entered.is_connected(_on_any_button_mouse_entered):
			button.mouse_entered.connect(_on_any_button_mouse_entered)

	if not options_button.pressed.is_connected(_on_options_button_pressed):
		options_button.pressed.connect(_on_options_button_pressed)

func _on_any_button_mouse_entered() -> void:
	if hover_sound and hover_sound.stream:
		hover_sound.play()

func _play_click() -> void:
	if click_sound and click_sound.stream:
		click_sound.play()

func _on_options_button_pressed() -> void:
	_play_click()
	_show_options_menu()

func _on_options_menu_closed() -> void:
	if flow:
		flow.show_main_menu()

func _show_options_menu() -> void:
	if flow:
		flow.show_options_menu()

func on_start_button_pressed() -> void:
	if flow:
		flow.start_pressed()

func on_exit_button_pressed() -> void:
	if flow:
		flow.exit_pressed()

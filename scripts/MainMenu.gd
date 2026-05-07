extends Control

@onready var center_container: CenterContainer = $CenterContainer
@onready var main_vbox: VBoxContainer = $CenterContainer/VBoxContainer
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitMargin/ExitButton
@onready var options_menu: OptionsMenu = $OptionsMenu
@onready var click_sound: AudioStreamPlayer = $click
@onready var hover_sound: AudioStreamPlayer = $hover

var slot_selector: SaveSlotSelector = null

func _ready() -> void:
	_setup_content_scaling()
	_connect_menu_signals()
	_build_slot_selector()

	if options_menu and not options_menu.closed.is_connected(_on_options_menu_closed):
		options_menu.closed.connect(_on_options_menu_closed)
	if options_menu:
		options_menu.close()

func _build_slot_selector() -> void:
	slot_selector = SaveSlotSelector.new()
	slot_selector.setup(start_button, click_sound, hover_sound)
	slot_selector.visible = false
	add_child(slot_selector)

	if not slot_selector.slot_selected.is_connected(_on_slot_selected):
		slot_selector.slot_selected.connect(_on_slot_selected)
	if not slot_selector.back_pressed.is_connected(_on_slot_back_pressed):
		slot_selector.back_pressed.connect(_on_slot_back_pressed)

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
	_show_main_menu()

func _show_main_menu() -> void:
	center_container.visible = true
	main_vbox.visible = true
	if slot_selector:
		slot_selector.visible = false

func _show_options_menu() -> void:
	center_container.visible = false
	if slot_selector:
		slot_selector.visible = false
	if options_menu:
		options_menu.open()

func on_start_button_pressed() -> void:
	_play_click()
	center_container.visible = false
	main_vbox.visible = false
	if slot_selector:
		slot_selector.refresh()
		slot_selector.visible = true

func _on_slot_back_pressed() -> void:
	_show_main_menu()

func _on_slot_selected(slot_id: int) -> void:
	SaveManager.load_game(slot_id)
	
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scenes/Main2d.tscn")

func on_exit_button_pressed() -> void:
	_play_click()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

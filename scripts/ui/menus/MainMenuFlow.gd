extends RefCounted
class_name MainMenuFlow

var _SaveSlotSelector = preload("res://scripts/ui/menus/SaveSlotSelector.gd")

var owner: Node = null
var center_container: CenterContainer = null
var main_vbox: VBoxContainer = null
var options_menu: OptionsMenu = null
var click_sound: AudioStreamPlayer = null
var hover_sound: AudioStreamPlayer = null

var slot_selector: SaveSlotSelector = null

func setup(
	p_owner: Node,
	p_center_container: CenterContainer,
	p_main_vbox: VBoxContainer,
	p_options_menu: OptionsMenu,
	p_click_sound: AudioStreamPlayer,
	p_hover_sound: AudioStreamPlayer
) -> void:
	owner = p_owner
	center_container = p_center_container
	main_vbox = p_main_vbox
	options_menu = p_options_menu
	click_sound = p_click_sound
	hover_sound = p_hover_sound

func build_slot_selector(start_button: Button) -> void:
	if owner == null:
		return

	slot_selector = _SaveSlotSelector.new()
	slot_selector.setup(start_button, click_sound, hover_sound)
	slot_selector.visible = false
	owner.add_child(slot_selector)

	if not slot_selector.slot_selected.is_connected(_on_slot_selected):
		slot_selector.slot_selected.connect(_on_slot_selected)
	if not slot_selector.back_pressed.is_connected(_on_slot_back_pressed):
		slot_selector.back_pressed.connect(_on_slot_back_pressed)

func show_main_menu() -> void:
	if center_container:
		center_container.visible = true
	if main_vbox:
		main_vbox.visible = true
	if slot_selector:
		slot_selector.visible = false

func show_options_menu() -> void:
	if center_container:
		center_container.visible = false
	if slot_selector:
		slot_selector.visible = false
	if options_menu:
		options_menu.open()

func start_pressed() -> void:
	_play_click()
	if center_container:
		center_container.visible = false
	if main_vbox:
		main_vbox.visible = false
	if slot_selector:
		slot_selector.refresh()
		slot_selector.visible = true

func exit_pressed() -> void:
	_play_click()
	if owner == null:
		return
	await owner.get_tree().create_timer(0.15).timeout
	# Flush pending saves before quitting the application.
	ManagerLocator.flush_saves()
	owner.get_tree().quit()

func _on_slot_back_pressed() -> void:
	show_main_menu()

func _on_slot_selected(slot_id: int) -> void:
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.load_game(slot_id)

	if owner == null:
		return

	await owner.get_tree().create_timer(0.15).timeout
	# Ensure pending saves are flushed before scene change.
	ManagerLocator.flush_saves()
	owner.get_tree().change_scene_to_file("res://scenes/Main2d.tscn")

func _play_click() -> void:
	if click_sound and click_sound.stream:
		click_sound.play()

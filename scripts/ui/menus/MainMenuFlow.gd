extends RefCounted
class_name MainMenuFlow

## MainMenuFlow — Navigation coordinator for MainMenu.
## Coordinates transitions between Main buttons, OptionsMenu and SlotSelection.

const GAME_SCENE := "res://scenes/Main2d.tscn"
const CREDITS_SCENE := "res://scenes/CreditMenu.tscn"
const SLOT_SELECTION_SCENE := preload("res://scenes/SlotSelection.tscn")

enum MenuState {
	MAIN,
	SLOT_SELECT,
	OPTIONS
}

var owner: Node = null
var center_container: CenterContainer = null
var main_vbox: VBoxContainer = null
var options_menu: OptionsMenu = null

var click_sound: AudioStreamPlayer = null
var hover_sound: AudioStreamPlayer = null

var slot_selector: SaveSlotSelector = null

var current_state: MenuState = MenuState.MAIN
var is_transitioning: bool = false
var _menu_tween: Tween = null


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


func build_slot_selector(_start_button: Button = null) -> void:
	if owner == null:
		return

	slot_selector = SLOT_SELECTION_SCENE.instantiate() as SaveSlotSelector
	slot_selector.setup(click_sound, hover_sound)
	slot_selector.visible = false

	owner.add_child(slot_selector)

	if not slot_selector.slot_selected.is_connected(_on_slot_selected):
		slot_selector.slot_selected.connect(_on_slot_selected)

	if not slot_selector.back_pressed.is_connected(_on_slot_back_pressed):
		slot_selector.back_pressed.connect(_on_slot_back_pressed)


func show_main_menu() -> void:
	current_state = MenuState.MAIN

	if slot_selector:
		slot_selector.close(true)
	if options_menu:
		options_menu.close(false)

	_animate_main_menu(true)


func show_options_menu() -> void:
	if is_transitioning:
		return
	current_state = MenuState.OPTIONS

	if slot_selector:
		slot_selector.close(false)

	_animate_main_menu(false, func():
		if options_menu:
			options_menu.open()
	)


func start_pressed() -> void:
	if is_transitioning:
		return

	current_state = MenuState.SLOT_SELECT
	_play_click()

	if options_menu:
		options_menu.close(false)

	_animate_main_menu(false, func():
		if slot_selector:
			slot_selector.open()
	)


func exit_pressed() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	_play_click()

	if owner == null:
		return

	_animate_main_menu(false)

	await owner.get_tree().create_timer(0.2).timeout
	ManagerLocator.flush_saves()
	owner.get_tree().quit()


func credits_pressed() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	_play_click()

	if owner == null:
		return

	_animate_main_menu(false)

	await owner.get_tree().create_timer(0.2).timeout
	var err := owner.get_tree().change_scene_to_file(CREDITS_SCENE)
	if err != OK:
		push_error("MainMenuFlow: Failed to load CreditsScene: %d" % err)
		is_transitioning = false
		_animate_main_menu(true)


func _on_slot_back_pressed() -> void:
	show_main_menu()


func _on_slot_selected(slot_id: int) -> void:
	if is_transitioning:
		return

	is_transitioning = true

	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr == null:
		push_error("MainMenuFlow: SaveManager not found.")
		is_transitioning = false
		return

	save_mgr.load_game(slot_id)
	await _change_to_game_scene()


func _change_to_game_scene() -> void:
	if owner == null:
		return

	if slot_selector:
		slot_selector.close(true)

	await owner.get_tree().create_timer(0.2).timeout
	ManagerLocator.flush_saves()
	owner.get_tree().change_scene_to_file(GAME_SCENE)


func _animate_main_menu(show: bool, on_finish: Callable = Callable()) -> void:
	if center_container == null:
		return

	if _menu_tween and _menu_tween.is_valid():
		_menu_tween.kill()

	center_container.pivot_offset = center_container.size / 2.0

	_menu_tween = center_container.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)

	if show:
		center_container.visible = true
		if main_vbox:
			main_vbox.visible = true
		_menu_tween.set_ease(Tween.EASE_OUT)
		_menu_tween.tween_property(center_container, "modulate:a", 1.0, 0.22)
		_menu_tween.tween_property(center_container, "scale", Vector2.ONE, 0.22)
		_menu_tween.chain().tween_callback(func():
			is_transitioning = false
			if on_finish.is_valid():
				on_finish.call()
		)
	else:
		is_transitioning = true
		_menu_tween.set_ease(Tween.EASE_IN)
		_menu_tween.tween_property(center_container, "modulate:a", 0.0, 0.18)
		_menu_tween.tween_property(center_container, "scale", Vector2(0.95, 0.95), 0.18)
		_menu_tween.chain().tween_callback(func():
			center_container.visible = false
			if main_vbox:
				main_vbox.visible = false
			is_transitioning = false
			if on_finish.is_valid():
				on_finish.call()
		)


func _play_click() -> void:
	if click_sound and click_sound.stream:
		click_sound.play()
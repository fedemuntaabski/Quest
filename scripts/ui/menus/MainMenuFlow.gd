extends RefCounted
class_name MainMenuFlow

const GAME_SCENE := "res://scenes/Main2d.tscn"
const CREDITS_SCENE := "res://scenes/CreditsScene.tscn"


var _SaveSlotSelector := preload(
	"res://scripts/ui/menus/SaveSlotSelector.gd"
)

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

	slot_selector.setup(
		start_button,
		click_sound,
		hover_sound
	)

	slot_selector.visible = false

	owner.add_child(slot_selector)

	if not slot_selector.slot_selected.is_connected(_on_slot_selected):
		slot_selector.slot_selected.connect(_on_slot_selected)

	if not slot_selector.back_pressed.is_connected(_on_slot_back_pressed):
		slot_selector.back_pressed.connect(_on_slot_back_pressed)


func show_main_menu() -> void:

	current_state = MenuState.MAIN

	_set_main_menu_visible(true)

	if slot_selector:
		slot_selector.visible = false


func show_options_menu() -> void:

	current_state = MenuState.OPTIONS

	_set_main_menu_visible(false)

	if slot_selector:
		slot_selector.visible = false

	if options_menu:
		options_menu.open()


func start_pressed() -> void:

	if is_transitioning:
		return

	current_state = MenuState.SLOT_SELECT

	_play_click()

	_set_main_menu_visible(false)

	if slot_selector:
		slot_selector.refresh()
		slot_selector.visible = true


func exit_pressed() -> void:

	if is_transitioning:
		return

	is_transitioning = true

	_play_click()

	if owner == null:
		return

	await owner.get_tree().create_timer(0.15).timeout

	ManagerLocator.flush_saves()

	owner.get_tree().quit()


func _on_slot_back_pressed() -> void:

	show_main_menu()


func _on_slot_selected(slot_id: int) -> void:

	if is_transitioning:
		return

	is_transitioning = true

	var save_mgr := ManagerLocator.get_save_manager()

	if save_mgr == null:

		push_error(
			"MainMenuFlow: SaveManager not found."
		)

		is_transitioning = false
		return

	save_mgr.load_game(slot_id)

	await _change_to_game_scene()


func _change_to_game_scene() -> void:

	if owner == null:
		return

	await owner.get_tree().create_timer(0.15).timeout

	ManagerLocator.flush_saves()

	owner.get_tree().change_scene_to_file(
		GAME_SCENE
	)


func _set_main_menu_visible(value: bool) -> void:

	if center_container:
		center_container.visible = value

	if main_vbox:
		main_vbox.visible = value


func _play_click() -> void:

	if click_sound and click_sound.stream:
		click_sound.play()

func credits_pressed() -> void:

	print("1")

	if is_transitioning:
		print("2")
		return

	is_transitioning = true

	print("3")

	_play_click()

	await owner.get_tree().create_timer(0.15).timeout

	print("4")

	var err := owner.get_tree().change_scene_to_file(
		CREDITS_SCENE
	)

	print("5", err)
	print(FileAccess.file_exists(CREDITS_SCENE))

	if err != OK:
		push_error("No se pudo abrir CreditsScene.")
		is_transitioning = false
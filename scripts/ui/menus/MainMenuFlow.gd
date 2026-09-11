extends RefCounted
class_name MainMenuFlow

## MainMenuFlow — Navigation coordinator for MainMenu.
## Coordinates transitions between Main buttons, OptionsMenu and SlotSelection.

const GAME_SCENE := "res://scenes/Main2d.tscn"
const CREDITS_SCENE := "res://scenes/CreditMenu.tscn"
const WAITING_ROOM_SCENE := "res://scenes/WaitingRoom.tscn"
const SLOT_SELECTION_SCENE := preload("res://scenes/SlotSelection.tscn")
const NETWORK_MODE_SELECT_SCENE := preload("res://scenes/NetworkModeSelect.tscn")

enum MenuState {
	MAIN,
	NETWORK_MODE_SELECT,
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
var network_mode_select: NetworkModeSelect = null

var _is_hosting: bool = false

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


func build_network_mode_select() -> void:
	if owner == null:
		return

	network_mode_select = NETWORK_MODE_SELECT_SCENE.instantiate() as NetworkModeSelect
	network_mode_select.setup(click_sound, hover_sound)
	network_mode_select.visible = false

	owner.add_child(network_mode_select)

	if not network_mode_select.host_selected.is_connected(_on_host_selected):
		network_mode_select.host_selected.connect(_on_host_selected)
	if not network_mode_select.join_selected.is_connected(_on_join_selected):
		network_mode_select.join_selected.connect(_on_join_selected)
	if not network_mode_select.offline_selected.is_connected(_on_offline_selected):
		network_mode_select.offline_selected.connect(_on_offline_selected)
	if not network_mode_select.back_pressed.is_connected(_on_network_mode_back_pressed):
		network_mode_select.back_pressed.connect(_on_network_mode_back_pressed)

	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr and steam_mgr.lobby_manager:
		if not steam_mgr.lobby_manager.lobby_ready.is_connected(_on_lobby_ready):
			steam_mgr.lobby_manager.lobby_ready.connect(_on_lobby_ready)
		if not steam_mgr.lobby_manager.lobby_failed.is_connected(_on_lobby_failed):
			steam_mgr.lobby_manager.lobby_failed.connect(_on_lobby_failed)


func show_main_menu() -> void:
	current_state = MenuState.MAIN
	_leave_network_session()

	if slot_selector:
		slot_selector.close(true)
	if network_mode_select:
		network_mode_select.close(false)
	if options_menu:
		options_menu.close(false)

	_animate_main_menu(true)


func _leave_network_session() -> void:
	if _is_hosting:
		var steam_mgr := ManagerLocator.get_steam_manager()
		if steam_mgr and steam_mgr.lobby_manager:
			steam_mgr.lobby_manager.leave_lobby()
	_is_hosting = false


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

	current_state = MenuState.NETWORK_MODE_SELECT
	_play_click()

	if options_menu:
		options_menu.close(false)

	_animate_main_menu(false, func():
		if network_mode_select:
			network_mode_select.open()
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
	if _is_hosting:
		_leave_network_session()
		if slot_selector:
			slot_selector.close(true)
		current_state = MenuState.NETWORK_MODE_SELECT
		if network_mode_select:
			network_mode_select.open()
		return

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

	if _is_hosting:
		await _change_to_waiting_room()
	else:
		await _change_to_game_scene()


func _on_host_selected() -> void:
	if network_mode_select:
		network_mode_select.close(false)

	_is_hosting = true

	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr == null or steam_mgr.lobby_manager == null:
		QuestLogger.error(QuestLogger.Category.NETWORK, "SteamManager/lobby_manager not available for host flow.")
		_is_hosting = false
		if network_mode_select:
			network_mode_select.open()
		return

	steam_mgr.lobby_manager.create_lobby(Steam.LOBBY_TYPE_FRIENDS_ONLY)


func _on_join_selected() -> void:
	if network_mode_select:
		network_mode_select.close(false)

	_is_hosting = false
	Steam.activateGameOverlay("Friends")


func _on_offline_selected() -> void:
	current_state = MenuState.SLOT_SELECT
	_is_hosting = false

	if network_mode_select:
		network_mode_select.close(false)
	if slot_selector:
		slot_selector.open()


func _on_network_mode_back_pressed() -> void:
	if network_mode_select:
		network_mode_select.close(true)
	show_main_menu()


func _on_lobby_ready(_lobby_id: int, is_host: bool) -> void:
	if is_host:
		current_state = MenuState.SLOT_SELECT
		if slot_selector:
			slot_selector.open()
	else:
		await _change_to_waiting_room()


func _on_lobby_failed(reason: String) -> void:
	QuestLogger.error(QuestLogger.Category.NETWORK, "Lobby flow failed: %s" % reason)
	_is_hosting = false
	current_state = MenuState.NETWORK_MODE_SELECT
	if network_mode_select:
		network_mode_select.open()


func _change_to_game_scene() -> void:
	if owner == null:
		return

	if slot_selector:
		slot_selector.close(true)

	await owner.get_tree().create_timer(0.2).timeout
	ManagerLocator.flush_saves()
	owner.get_tree().change_scene_to_file(GAME_SCENE)


func _change_to_waiting_room() -> void:
	if owner == null:
		return

	if slot_selector:
		slot_selector.close(true)

	await owner.get_tree().create_timer(0.2).timeout
	ManagerLocator.flush_saves()
	owner.get_tree().change_scene_to_file(WAITING_ROOM_SCENE)


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

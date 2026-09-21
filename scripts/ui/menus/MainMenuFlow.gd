extends RefCounted
class_name MainMenuFlow

## MainMenuFlow — Navigation coordinator for MainMenu.
## Coordinates transitions between Main buttons, OptionsMenu and SlotSelection.

const SLOT_SELECTION_SCENE := preload("res://scenes/SlotSelection.tscn")
const NETWORK_MODE_SELECT_SCENE := preload("res://scenes/NetworkModeSelect.tscn")
const CHARACTER_SELECTION_SCENE := preload("res://scenes/CharacterSelection.tscn")

enum MenuState {
	MAIN,
	NETWORK_MODE_SELECT,
	SLOT_SELECT,
	CHARACTER_SELECT,
	OPTIONS
}

var owner: Node = null
var center_container: CenterContainer = null
var main_vbox: VBoxContainer = null
var options_menu: OptionsMenu = null
var start_button: Button = null

var click_sound: AudioStreamPlayer = null
var hover_sound: AudioStreamPlayer = null

var slot_selector: SaveSlotSelector = null
var network_mode_select: NetworkModeSelect = null
var character_selection: CharacterSelection = null

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
	p_hover_sound: AudioStreamPlayer,
	p_start_button: Button = null
) -> void:
	owner = p_owner
	center_container = p_center_container
	main_vbox = p_main_vbox
	options_menu = p_options_menu
	click_sound = p_click_sound
	hover_sound = p_hover_sound
	start_button = p_start_button

	if options_menu and not options_menu.closed.is_connected(_on_options_back_pressed):
		options_menu.closed.connect(_on_options_back_pressed)


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


func build_character_selection() -> void:
	if owner == null:
		return

	character_selection = CHARACTER_SELECTION_SCENE.instantiate() as CharacterSelection
	character_selection.setup(click_sound, hover_sound)
	character_selection.visible = false

	owner.add_child(character_selection)

	if not character_selection.character_confirmed.is_connected(_on_character_confirmed):
		character_selection.character_confirmed.connect(_on_character_confirmed)

	if not character_selection.back_pressed.is_connected(_on_character_back_pressed):
		character_selection.back_pressed.connect(_on_character_back_pressed)


func show_main_menu() -> void:
	current_state = MenuState.MAIN
	_leave_network_session()

	if slot_selector:
		slot_selector.close(true)
	if network_mode_select:
		network_mode_select.close(false)
	if character_selection:
		character_selection.close(false)
	if options_menu:
		options_menu.close(false)

	_animate_main_menu(true)


func _leave_network_session() -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	if is_instance_valid(steam_mgr) and is_instance_valid(steam_mgr.lobby_manager) \
			and steam_mgr.lobby_manager.current_lobby_id != 0:
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


func _on_options_back_pressed() -> void:
	show_main_menu()
	if start_button:
		start_button.grab_focus()


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

	var is_fresh_slot := not save_mgr.has_save(slot_id)
	save_mgr.load_game(slot_id)

	if is_fresh_slot:
		current_state = MenuState.CHARACTER_SELECT
		if slot_selector:
			slot_selector.close(true)
		if character_selection:
			character_selection.open()
	else:
		await _proceed_after_character_ready()


func _proceed_after_character_ready() -> void:
	if _is_hosting:
		await _change_to_waiting_room()
	else:
		await _change_to_game_scene()


func _on_character_confirmed(character_id: String) -> void:
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.apply_character_selection(character_id)

	if character_selection:
		character_selection.close(true)

	await _proceed_after_character_ready()


func _on_character_back_pressed() -> void:
	is_transitioning = false

	if character_selection:
		character_selection.close(true)

	current_state = MenuState.SLOT_SELECT
	if slot_selector:
		slot_selector.open()


func _on_host_selected() -> void:
	QuestLogger.info(QuestLogger.Category.NETWORK, "_on_host_selected: entered")

	if network_mode_select:
		network_mode_select.close(false)
		QuestLogger.info(QuestLogger.Category.NETWORK, "_on_host_selected: network_mode_select.close(false) called, visible=%s" % network_mode_select.visible)

	_is_hosting = true

	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr == null or steam_mgr.lobby_manager == null:
		QuestLogger.error(QuestLogger.Category.NETWORK, "SteamManager/lobby_manager not available for host flow.")
		_is_hosting = false
		if network_mode_select:
			network_mode_select.open()
		return

	QuestLogger.info(QuestLogger.Category.NETWORK, "_on_host_selected: is_steam_available=%s, calling create_lobby" % steam_mgr.is_steam_available())
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
	QuestLogger.info(QuestLogger.Category.NETWORK, "_on_lobby_ready: lobby_id=%d is_host=%s" % [_lobby_id, is_host])
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
		network_mode_select.call_deferred("open")


func _change_to_game_scene() -> void:
	if owner == null:
		return

	if slot_selector:
		slot_selector.close(true)

	await owner.get_tree().create_timer(0.2).timeout
	ManagerLocator.flush_saves()
	var orchestrator := _get_orchestrator()
	if orchestrator:
		await orchestrator.start_gameplay()


func _change_to_waiting_room() -> void:
	if owner == null:
		return

	if slot_selector:
		slot_selector.close(true)

	await owner.get_tree().create_timer(0.2).timeout
	ManagerLocator.flush_saves()
	var orchestrator := _get_orchestrator()
	if orchestrator:
		await orchestrator.go_to_waiting_room()


func _get_orchestrator() -> Main:
	var orchestrator := ManagerLocator.get_main_orchestrator()
	if orchestrator == null:
		QuestLogger.error(QuestLogger.Category.UI, "MainMenuFlow: no Main orchestrator in group 'main_orchestrator' — run the project via scenes/Main.tscn (F5), not this scene standalone (F6).")
	return orchestrator


func _animate_main_menu(show: bool, on_finish: Callable = Callable()) -> void:
	if center_container == null:
		return

	if _menu_tween and _menu_tween.is_valid():
		_menu_tween.kill()

	center_container.pivot_offset = center_container.size / 2.0

	if show:
		center_container.visible = true
		if main_vbox:
			main_vbox.visible = true
		_set_main_buttons_disabled(true)
		_menu_tween = MenuTransitionFX.play_entrance(
			center_container,
			[{"node": center_container, "max_alpha": 1.0}],
			[center_container],
			0.28, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, Vector2(0.95, 0.95)
		)
		if _menu_tween != null:
			await _menu_tween.finished
		_set_main_buttons_disabled(false)
		is_transitioning = false
		if on_finish.is_valid():
			on_finish.call()
	else:
		is_transitioning = true
		_set_main_buttons_disabled(true)
		_menu_tween = MenuTransitionFX.play_exit(
			center_container,
			[{"node": center_container, "max_alpha": 1.0}],
			[center_container],
			0.28, Vector2(0.95, 0.95),
			Tween.TRANS_CUBIC, Tween.EASE_IN_OUT
		)
		if _menu_tween != null:
			await _menu_tween.finished
		center_container.visible = false
		if main_vbox:
			main_vbox.visible = false
		is_transitioning = false
		if on_finish.is_valid():
			on_finish.call()


func _set_main_buttons_disabled(is_disabled: bool) -> void:
	if main_vbox == null:
		return
	for child in main_vbox.get_children():
		if child is Button:
			(child as Button).disabled = is_disabled


func _play_click() -> void:
	if click_sound and click_sound.stream:
		click_sound.play()

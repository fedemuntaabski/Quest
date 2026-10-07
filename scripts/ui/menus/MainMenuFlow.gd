extends RefCounted
class_name MainMenuFlow

## MainMenuFlow — Navigation coordinator for MainMenu.
## Coordinates transitions between Main buttons, OptionsMenu and SlotSelection.

const SLOT_SELECTION_SCENE := preload("res://scenes/menus/SlotSelection.tscn")
const NETWORK_MODE_SELECT_SCENE := preload("res://scenes/menus/NetworkModeSelect.tscn")
const HERO_SELECT_SCENE := preload("res://scenes/menus/HeroSelectMenu.tscn")

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
var hero_select: HeroSelectMenu = null

const MAX_PLAYERS := 4

var _is_hosting: bool = false
## coop-12: Join was picked (the slot is loaded first, then NetSession joins).
var _is_joining: bool = false
var _join_code: String = ""

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

	var net := Net.session()
	if net:
		if not net.session_started.is_connected(_on_session_started):
			net.session_started.connect(_on_session_started)
		if not net.session_failed.is_connected(_on_lobby_failed):
			net.session_failed.connect(_on_lobby_failed)


func build_hero_select() -> void:
	if owner == null:
		return

	hero_select = HERO_SELECT_SCENE.instantiate() as HeroSelectMenu
	hero_select.setup(click_sound, hover_sound)
	hero_select.visible = false

	owner.add_child(hero_select)

	if not hero_select.heroes_confirmed.is_connected(_on_heroes_confirmed):
		hero_select.heroes_confirmed.connect(_on_heroes_confirmed)

	if not hero_select.back_pressed.is_connected(_on_hero_select_back_pressed):
		hero_select.back_pressed.connect(_on_hero_select_back_pressed)


func show_main_menu() -> void:
	current_state = MenuState.MAIN
	_leave_network_session()

	if slot_selector:
		slot_selector.close(true)
	if network_mode_select:
		network_mode_select.close(false)
	if hero_select:
		hero_select.close(false)
	if options_menu:
		options_menu.close(false)

	_animate_main_menu(true)


func _leave_network_session() -> void:
	var net := Net.session()
	if net:
		net.leave("menu")
	_is_hosting = false
	_is_joining = false


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
	if _is_hosting or _is_joining:
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

	# Offline picks its 2 heroes every run; co-op picks in the WaitingRoom.
	var net := Net.session()
	if net and net.is_online() and not net.is_host():
		await _change_to_waiting_room()  # joined from an invite before picking a slot
	elif _is_hosting:
		is_transitioning = false
		if net == null or net.host(MAX_PLAYERS) != OK:
			_on_lobby_failed("host_failed")
	elif _is_joining:
		is_transitioning = false
		if net == null or net.join(_join_code) != OK:
			_on_lobby_failed("join_failed")
	else:
		current_state = MenuState.CHARACTER_SELECT
		if slot_selector:
			slot_selector.close(true)
		if hero_select:
			hero_select.open()


func _proceed_after_character_ready() -> void:
	if _is_hosting:
		await _change_to_waiting_room()
	else:
		await _change_to_game_scene()


func _on_heroes_confirmed(hero_ids: Array[String]) -> void:
	var session := ManagerLocator.get_game_session()
	if session == null or not session.set_selection(hero_ids):
		QuestLogger.error(QuestLogger.Category.UI, "MainMenuFlow: invalid hero pick %s" % [hero_ids])
		return

	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.apply_character_selection(hero_ids[0])

	if hero_select:
		hero_select.close(true)

	await _proceed_after_character_ready()


func _on_hero_select_back_pressed() -> void:
	if hero_select:
		hero_select.close(false)
	show_main_menu()


func _on_host_selected() -> void:
	_open_slots_for_network(true)


func _on_join_selected() -> void:
	_join_code = network_mode_select.get_join_code() if network_mode_select else ""
	var net := Net.session()
	if _join_code.is_empty() and net and net.make_transport() is SteamTransport:
		# Steam without a code: wait for an overlay invite (NetSession joins it).
		SteamApi.steam().activateGameOverlay("Friends")
		return
	_open_slots_for_network(false)


func _open_slots_for_network(hosting: bool) -> void:
	_is_hosting = hosting
	_is_joining = not hosting
	current_state = MenuState.SLOT_SELECT
	if network_mode_select:
		network_mode_select.close(false)
	if slot_selector:
		slot_selector.open()


func _on_offline_selected() -> void:
	current_state = MenuState.SLOT_SELECT
	_is_hosting = false
	_is_joining = false

	if network_mode_select:
		network_mode_select.close(false)
	if slot_selector:
		slot_selector.open()


func _on_network_mode_back_pressed() -> void:
	if network_mode_select:
		network_mode_select.close(true)
	show_main_menu()


func _on_session_started(_mode: int) -> void:
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr and not save_mgr.slot_loaded:
		# Joined from an overlay invite: pick a slot (local bestiary/records) first.
		current_state = MenuState.SLOT_SELECT
		if network_mode_select:
			network_mode_select.close(false)
		if slot_selector:
			slot_selector.open()
		return
	await _change_to_waiting_room()


func _on_lobby_failed(reason: String) -> void:
	QuestLogger.error(QuestLogger.Category.NETWORK, "Lobby flow failed: %s" % reason)
	_is_hosting = false
	_is_joining = false
	is_transitioning = false
	current_state = MenuState.NETWORK_MODE_SELECT
	if slot_selector:
		slot_selector.close(false)
	if network_mode_select:
		network_mode_select.open()
		network_mode_select.show_status("No se pudo conectar (%s)." % reason)


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

	# The WaitingRoom hero pick rules multiplayer: drop any earlier offline pick.
	var session := ManagerLocator.get_game_session()
	if session:
		session.clear()

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

extends Control
class_name WaitingRoom

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const GAME_SCENE := "res://scenes/Main2d.tscn"
const CharacterDatabase = preload("res://scripts/core/stats/CharacterDatabase.gd")
const CharacterCardOptionScene := preload("res://scenes/CharacterCardOption.tscn")

@onready var lobby_id_label: Label = $CenterContainer/RoomCard/VBoxContainer/LobbyIdLabel
@onready var players_list: VBoxContainer = $CenterContainer/RoomCard/VBoxContainer/PlayersPanel/PlayersList
@onready var character_cards_container: HBoxContainer = $CenterContainer/RoomCard/VBoxContainer/CharacterPanel/CharacterVBox/CharacterCardsContainer
@onready var invite_button: Button = $CenterContainer/RoomCard/VBoxContainer/InviteButton
@onready var start_button: Button = $CenterContainer/RoomCard/VBoxContainer/StartButton
@onready var leave_button: Button = $CenterContainer/RoomCard/VBoxContainer/LeaveButton

var _refresh_timer: Timer = null
var _character_cards: Dictionary = {}
var _local_character_id: String = ""


func _ready() -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	var is_host: bool = multiplayer.multiplayer_peer != null and multiplayer.is_server()

	start_button.visible = is_host
	invite_button.disabled = steam_mgr == null or not steam_mgr.is_steam_available()

	invite_button.pressed.connect(_on_invite_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	if steam_mgr:
		steam_mgr.client_authenticated.connect(_on_roster_changed)
		steam_mgr.avatar_loaded_ready.connect(_on_avatar_loaded)
	multiplayer.peer_disconnected.connect(_on_roster_changed)
	if multiplayer.multiplayer_peer != null:
		multiplayer.server_disconnected.connect(_on_host_lost)

	_local_character_id = ManagerLocator.get_save_manager().get_selected_character_id()
	_build_character_cards()
	_publish_local_character_selection()

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 1.0
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_refresh)
	add_child(_refresh_timer)

	_refresh()


func _refresh(_arg = null) -> void:
	var lobby_mgr: SteamLobbyManager = null
	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr:
		lobby_mgr = steam_mgr.lobby_manager

	lobby_id_label.text = "Lobby: %d" % (lobby_mgr.current_lobby_id if lobby_mgr else 0)
	
	for child: Node in players_list.get_children():
		child.queue_free()

	_make_player_row(Steam.getSteamID(), "%s (vos)" % Steam.getPersonaName(), steam_mgr)

	if steam_mgr:
		for peer_id: int in steam_mgr.connected_clients.keys():
			var steam_id: int = steam_mgr.connected_clients[peer_id].get("steam_id", 0)
			_make_player_row(steam_id, Steam.getFriendPersonaName(steam_id), steam_mgr)

	_refresh_character_roster()


func _build_character_cards() -> void:
	for data in CharacterDatabase.get_all():
		var card := CharacterCardOptionScene.instantiate()
		character_cards_container.add_child(card)
		card.setup(data)
		card.selected.connect(_on_character_card_selected)
		_character_cards[data.character_id] = card
		if data.character_id == _local_character_id:
			card.set_selected(true)


func _on_character_card_selected(character_id: String) -> void:
	_local_character_id = character_id
	ManagerLocator.get_save_manager().apply_character_selection(character_id)
	for id in _character_cards.keys():
		_character_cards[id].set_selected(id == character_id)
	_publish_local_character_selection()


func _publish_local_character_selection() -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	var lobby_mgr: SteamLobbyManager = steam_mgr.lobby_manager if steam_mgr else null
	if lobby_mgr and lobby_mgr.current_lobby_id != 0:
		Steam.setLobbyMemberData(lobby_mgr.current_lobby_id, "character_id", _local_character_id)


func _refresh_character_roster() -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	var lobby_mgr: SteamLobbyManager = steam_mgr.lobby_manager if steam_mgr else null
	if lobby_mgr == null or lobby_mgr.current_lobby_id == 0:
		return

	var local_steam_id := Steam.getSteamID()
	var taken: Dictionary = {_local_character_id: local_steam_id}

	if steam_mgr:
		for peer_id: int in steam_mgr.connected_clients.keys():
			var steam_id: int = steam_mgr.connected_clients[peer_id].get("steam_id", 0)
			var picked: String = Steam.getLobbyMemberData(lobby_mgr.current_lobby_id, steam_id, "character_id")
			if picked != "":
				taken[picked] = steam_id

	for character_id in _character_cards.keys():
		var owner_steam_id: int = taken.get(character_id, 0)
		var is_taken_by_other := owner_steam_id != 0 and owner_steam_id != local_steam_id
		var owner_name := Steam.getFriendPersonaName(owner_steam_id) if is_taken_by_other else ""
		_character_cards[character_id].set_taken(is_taken_by_other, owner_name)


func _make_player_row(steam_id: int, display_name: String, steam_mgr) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_meta("steam_id", steam_id)

	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = Vector2(32, 32)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_SCALE
	row.add_child(avatar)

	var label := Label.new()
	label.text = "• %s" % display_name
	row.add_child(label)

	players_list.add_child(row)

	if steam_mgr:
		if steam_mgr.avatar_cache.has(steam_id):
			avatar.texture = steam_mgr.avatar_cache[steam_id]
		else:
			steam_mgr.get_user_avatar(steam_id)

	return row


func _on_avatar_loaded(steam_id: int, texture: ImageTexture) -> void:
	for row: Node in players_list.get_children():
		if row.get_meta("steam_id", 0) == steam_id:
			var avatar := row.get_node_or_null("Avatar") as TextureRect
			if avatar:
				avatar.texture = texture


func _on_roster_changed(_a = null, _b = null) -> void:
	_refresh()


func _on_invite_pressed() -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr == null or steam_mgr.lobby_manager == null:
		return
	var lobby_id: int = steam_mgr.lobby_manager.current_lobby_id
	Steam.activateGameOverlayInviteDialog(lobby_id)


func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	ManagerLocator.flush_saves()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_leave_pressed() -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr and steam_mgr.lobby_manager:
		steam_mgr.lobby_manager.leave_lobby()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_host_lost() -> void:
	QuestLogger.warn(QuestLogger.Category.NETWORK, "Host disconnected, returning to main menu")
	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr and steam_mgr.lobby_manager:
		steam_mgr.lobby_manager.leave_lobby()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

extends Control
class_name WaitingRoom

## WaitingRoom (coop-12): the co-op lobby. Everything shown comes from the
## NetSession roster (host-authoritative, same on every peer): players with their
## color, picks and ready flag; hero cards (taken by others = locked); Ready;
## Start (host, once everyone is ready); join code + Steam invite; Leave.

const CharacterCardOptionScene := preload("res://scenes/menus/CharacterCardOption.tscn")

@onready var lobby_id_label: Label = $CenterContainer/RoomCard/VBoxContainer/LobbyIdLabel
@onready var players_list: VBoxContainer = $CenterContainer/RoomCard/VBoxContainer/PlayersPanel/PlayersList
@onready var hint_label: Label = $CenterContainer/RoomCard/VBoxContainer/CharacterPanel/CharacterVBox/CharacterHintLabel
@onready var character_cards_container: HBoxContainer = $CenterContainer/RoomCard/VBoxContainer/CharacterPanel/CharacterVBox/CharacterCardsContainer
@onready var invite_button: Button = $CenterContainer/RoomCard/VBoxContainer/InviteButton
@onready var start_button: Button = $CenterContainer/RoomCard/VBoxContainer/StartButton
@onready var leave_button: Button = $CenterContainer/RoomCard/VBoxContainer/LeaveButton

var ready_button: Button
var _character_cards: Dictionary = {}
var _net: CoopSession
var _leaving := false


func _ready() -> void:
	_net = Net.session()
	ready_button = Button.new()
	ready_button.name = "ReadyButton"
	ready_button.toggle_mode = true
	ready_button.text = "Listo"
	start_button.get_parent().add_child(ready_button)
	start_button.get_parent().move_child(ready_button, start_button.get_index())

	invite_button.pressed.connect(_on_invite_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	ready_button.toggled.connect(func(on: bool) -> void: _net.request_set_ready(on))
	_net.lobby_changed.connect(_refresh)
	_net.session_ended.connect(_on_session_ended)
	_build_character_cards()
	_refresh()

	var tween := MenuTransitionFX.play_entrance(self, [{"node": self, "max_alpha": 1.0}], [],
		0.28, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, Vector2.ONE)
	if tween != null:
		await tween.finished


func _build_character_cards() -> void:
	for data in CharacterDatabase.get_all():
		var card := CharacterCardOptionScene.instantiate()
		character_cards_container.add_child(card)
		card.setup(data)
		card.selected.connect(func(id: String) -> void: _net.request_pick(id))
		_character_cards[data.character_id] = card


func _refresh() -> void:
	if not is_instance_valid(_net) or not _net.is_online():
		return
	var me := _net.local_peer()
	lobby_id_label.text = "Código: %s  (%s)" % [_net.get_join_code(), "Steam" if _net.get_kind() == "steam" else "red local"]
	for child in players_list.get_children():
		child.queue_free()
	for peer in _net.players:
		players_list.add_child(_player_row(peer, me))

	var mine: Array = _net.players.get(me, {}).get("heroes", [])
	for id in _character_cards:
		var card: CharacterCardOption = _character_cards[id]
		var owner_peer := _net.hero_taken_by(id)
		card.set_taken(owner_peer != 0 and owner_peer != me, _net.player_name(owner_peer))
		card.set_selected(mine.has(id))

	var quota := _net.heroes_per_player()
	hint_label.text = "Elegí %d héroe(s) (%d/%d)" % [quota, mine.size(), quota]
	ready_button.set_pressed_no_signal(_net.players.get(me, {}).get("ready", false))
	ready_button.disabled = mine.size() != quota
	start_button.visible = _net.is_host()
	var reason := _net.start_block_reason()
	start_button.disabled = reason != ""
	start_button.tooltip_text = reason
	invite_button.disabled = _net.transport == null or not _net.transport.can_invite()


func _player_row(peer: int, me: int) -> HBoxContainer:
	var p: Dictionary = _net.players[peer]
	var row := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(16, 16)
	swatch.color = _net.player_color(peer)
	row.add_child(swatch)
	var heroes := []
	for id in p.heroes:
		var data := CharacterDatabase.get_by_id(id)
		heroes.append(data.display_name if data else id)
	var label := Label.new()
	label.text = "%s%s%s — %s %s" % [p.name, " (vos)" if peer == me else "", " [anfitrión]" if peer == 1 else "",
		", ".join(heroes) if not heroes.is_empty() else "sin héroe", "✓ listo" if p.ready else "…"]
	row.add_child(label)
	return row


func _on_invite_pressed() -> void:
	if _net.transport:
		_net.transport.invite()


func _on_start_pressed() -> void:
	start_button.disabled = true
	ManagerLocator.flush_saves()
	if not _net.start_run():
		_refresh()


func _on_leave_pressed() -> void:
	_go_to_menu()


func _on_session_ended(reason: String) -> void:
	QuestLogger.warn(QuestLogger.Category.NETWORK, "Lobby closed (%s), back to the main menu" % reason)
	_go_to_menu()


func _go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	leave_button.disabled = true
	var orchestrator := ManagerLocator.get_main_orchestrator()
	if orchestrator:
		await orchestrator.return_to_main_menu()  # also closes the session
	elif _net:
		_net.leave("menu")

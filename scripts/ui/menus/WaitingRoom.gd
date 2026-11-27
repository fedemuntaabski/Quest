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
@onready var character_cards_container: GridContainer = $CenterContainer/RoomCard/VBoxContainer/CharacterPanel/CharacterVBox/CharacterCardsContainer
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
	ready_button.text = "LISTO"
	_button_rows()

	invite_button.pressed.connect(_on_invite_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	ready_button.toggled.connect(func(on: bool) -> void: _net.request_set_ready(on))
	_net.lobby_changed.connect(_refresh)
	_net.session_ended.connect(_on_session_ended)
	_build_character_cards()
	_apply_style()
	_refresh()
	_scroll_when_tall()

	var tween := MenuTransitionFX.play_entrance(self, [{"node": self, "max_alpha": 1.0}], [],
		0.28, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, Vector2.ONE)
	if tween != null:
		await tween.finished


## juego-36: the four plaques in two rows (Invitar + Listo, Iniciar + Abandonar) instead of
## four stacked: at text x1.5 the card fits a 1080p screen without scrolling.
func _button_rows() -> void:
	var box := start_button.get_parent()
	var at := invite_button.get_index()
	for pair: Array in [[invite_button, ready_button], [start_button, leave_button]]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		box.add_child(row)
		box.move_child(row, at)
		at += 1
		for button: Button in pair:
			if button.get_parent():
				button.get_parent().remove_child(button)
			row.add_child(button)


## visual-24: with large text the card is taller than the screen (Abandonar fell off
## the bottom); a ScrollContainer around the centered card lets it scroll instead.
## At text x1.0 it fits and nothing moves. The @onready paths are already resolved.
func _scroll_when_tall() -> void:
	var center := $CenterContainer as CenterContainer
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	move_child(scroll, center.get_index())
	remove_child(center)
	scroll.add_child(center)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL


## menu-33: framed card, title + ornament, inset panels, plaques (Abandonar = red).
func _apply_style() -> void:
	theme = UiStyles.menu_font_theme()
	var card := $CenterContainer/RoomCard as PanelContainer
	UiStyles.style_menu_frame(card, 30)
	var title := $CenterContainer/RoomCard/VBoxContainer/Title as Label
	UiStyles.style_menu_title(title, 36)
	UiStyles.add_ornament_after(title)
	UiStyles.style_menu_text(lobby_id_label, 18, Color(QuestPalette.PARCHMENT, 0.85))
	UiStyles.style_menu_text(hint_label, 18, QuestPalette.RELIC_GOLD)
	for panel: PanelContainer in [$CenterContainer/RoomCard/VBoxContainer/PlayersPanel, $CenterContainer/RoomCard/VBoxContainer/CharacterPanel]:
		panel.add_theme_stylebox_override("panel", UiStyles.build_inset_style(14))
	UiStyles.style_plaque_button(invite_button, false, 22)
	UiStyles.style_plaque_button(ready_button, false, 24)
	ready_button.custom_minimum_size = Vector2(520, 62)
	ready_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyles.style_plaque_button(start_button, false, 26)
	UiStyles.style_plaque_button(leave_button, true, 22)


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
	UiStyles.style_menu_text(label, 18)
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
	if reason == CoopSession.VERSION_MISMATCH:
		await _show_version_refused()
	_go_to_menu()


func _show_version_refused() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Versión distinta"
	dialog.dialog_text = "No podés entrar: el anfitrión tiene la versión %s y vos la %s.\nTienen que jugar la misma versión." % [_net.host_version_refused, _net.game_version]
	UiStyles.style_menu_dialog(dialog)
	add_child(dialog)
	dialog.popup_centered()
	await dialog.visibility_changed
	dialog.queue_free()


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

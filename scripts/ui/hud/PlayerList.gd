class_name PlayerList
extends VBoxContainer

## coop-12 phase 7: the session's players (color, name, host/you tags, ping), in
## the HUD's top-left column. Built by HUDController only for a co-op session;
## hidden while offline. Refreshes on NetSession.lobby_changed / pings_changed.

const ROW_FONT := 15
const SWATCH := Vector2(12, 12)

var _session: CoopSession


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	_session = Net.session()
	if _session:
		_session.lobby_changed.connect(refresh)
		_session.pings_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	visible = _session != null and _session.is_online()
	if not visible:
		return
	var peers: Array = _session.players.keys()
	peers.sort()
	for peer: int in peers:
		add_child(_row(peer))


## One row per player; `row_text()` is the label part (tests read it).
func _row(peer: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = SWATCH
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = _session.player_color(peer)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	var label := Label.new()
	label.text = row_text(peer)
	label.add_theme_font_size_override("font_size", Accessibility.font(ROW_FONT))
	label.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row


func row_text(peer: int) -> String:
	var text := _session.player_name(peer)
	if peer == 1:
		text += " (anfitrión)"
	if peer == _session.local_peer():
		text += " (vos)"
	if peer != 1 and _session.pings.has(peer):
		text += "  %d ms" % int(_session.pings[peer])
	return text

class_name ChatPanel
extends VBoxContainer

## coop-12 phase 7: short co-op chat with predefined messages
## (NetConfig.chat_messages). T opens/closes the message list; a click sends it
## through NetCommands "chat" (the host relays it to everyone). Received lines
## stay LINE_SEC seconds (real time) and at most MAX_LINES are kept.
## Bottom-left of the HUD; built by HUDController for a co-op session.

const MAX_LINES := 5
const LINE_SEC := 10.0
const FONT := 15

var _log: VBoxContainer
var _menu: VBoxContainer
## Label -> expiry (Time.get_ticks_msec()).
var _expiry: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	_log = VBoxContainer.new()
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log)
	_menu = VBoxContainer.new()
	_menu.visible = false
	add_child(_menu)
	var session := Net.session()
	var messages: Array[String] = session.config.chat_messages if session else []
	for i in messages.size():
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, messages[i]]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(send.bind(i))
		_menu.add_child(button)
	set_process(false)


func is_menu_open() -> bool:
	return _menu.visible


func toggle_menu() -> void:
	_menu.visible = not _menu.visible


func send(index: int) -> void:
	_menu.visible = false
	ManagerLocator.get_net_commands().request("chat", {"i": index})


## A message arrived (host relay or local): "Name: text" in the player's color.
func add_message(player_name: String, color: Color, text: String) -> void:
	var line := Label.new()
	line.text = "%s: %s" % [player_name, text]
	line.add_theme_font_size_override("font_size", FONT)
	line.add_theme_color_override("font_color", color)
	line.add_theme_color_override("font_outline_color", QuestPalette.INK)
	line.add_theme_constant_override("outline_size", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_child(line)
	_expiry[line] = Time.get_ticks_msec() + int(LINE_SEC * 1000.0)
	while _log.get_child_count() > MAX_LINES:
		var old := _log.get_child(0)
		_expiry.erase(old)
		_log.remove_child(old)
		old.queue_free()
	set_process(true)


func get_lines() -> Array[String]:
	var out: Array[String] = []
	for line: Label in _log.get_children():
		out.append(line.text)
	return out


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for line: Label in _expiry.keys():
		if _expiry[line] <= now:
			_expiry.erase(line)
			line.queue_free()
	set_process(not _expiry.is_empty())

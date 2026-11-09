extends SceneTree

## visual-24: layout regressions found by tests/tools/shot_barrido.gd. Every check
## runs at text scale 1.0 and at SettingsManager.TEXT_SCALE_MAX, with the menus under
## a CanvasLayer as in the game (Main's UIContainer).
##   godot --headless --path . --script res://tests/test_barrido_ui.gd

const SCALES := [1.0, 1.5]

var failures: Array[String] = []
var settings: Node


func _initialize() -> void:
	await process_frame
	settings = root.get_node("SettingsManager")
	for text_scale: float in SCALES:
		settings.text_scale = text_scale
		_check_canvas_layer_font(text_scale)
		await _check_options(text_scale)
		await _check_waiting_room(text_scale)
	settings.text_scale = 1.0
	await _check_texts()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_barrido_ui: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _screen() -> Rect2:
	return root.get_visible_rect()


func _inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.grow(1.0).encloses(inner)


## Text scale reaches a Control with no font override under a CanvasLayer (the HUD and
## every menu): it used to stay at 16 because only the root window's theme had the size.
func _check_canvas_layer_font(text_scale: float) -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var label := Label.new()
	layer.add_child(label)
	_expect(label.get_theme_font_size("font_size") == Accessibility.font(16),
		"x%.1f: a Label under a CanvasLayer has font size %d, want %d" % [text_scale, label.get_theme_font_size("font_size"), Accessibility.font(16)])
	layer.free()


func _under_layer(scene_path: String) -> Control:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var node := (load(scene_path) as PackedScene).instantiate() as Control
	layer.add_child(node)
	return node


## Every Opciones tab keeps its content, Guardar and Volver inside the card, and the
## card on screen.
func _check_options(text_scale: float) -> void:
	var options := _under_layer("res://scenes/menus/OptionsMenu.tscn") as OptionsMenu
	options.visible = true
	var vbox := options.get_node("OptionsCenterContainer/OptionsCard/OptionsVBox") as Control
	for tab in options.options_tabs.get_tab_count():
		options.options_tabs.current_tab = tab
		for i in 3:
			await process_frame
		var title := options.options_tabs.get_tab_title(tab)
		var card := options.options_card.get_global_rect()
		var shown := options.options_tabs.get_current_tab_control().find_children("*", "Label", true, false).filter(
			func(l: Label) -> bool: return l.is_visible_in_tree() and l.text != "")
		_expect(not shown.is_empty(), "x%.1f Opciones/%s: the tab shows no text" % [text_scale, title])
		_expect(_inside(card, _screen()), "x%.1f Opciones/%s: card %s off screen %s" % [text_scale, title, card, _screen()])
		_expect(_inside(vbox.get_global_rect(), card), "x%.1f Opciones/%s: content %s spills out of the card %s" % [text_scale, title, vbox.get_global_rect(), card])
		_expect(_inside(options.back_button.get_global_rect(), card), "x%.1f Opciones/%s: Volver %s outside the card %s" % [text_scale, title, options.back_button.get_global_rect(), card])
	options.get_parent().free()


## Texts the sweep caught: network buttons naming Steam while ENet is used, the FPS
## counter over the first hero portrait, "1 partidas", the hover-volume label.
func _check_texts() -> void:
	var mode := _under_layer("res://scenes/menus/NetworkModeSelect.tscn") as NetworkModeSelect
	await process_frame
	var steam: Node = root.get_node("SteamManager")
	if not steam.is_steam_available():  # headless: no Steam client
		for button: Button in [mode.host_button, mode.join_button]:
			_expect(not button.text.contains("STEAM") and button.text.contains("RED LOCAL"), "network button says '%s' without Steam" % button.text)
	_expect(not mode.host_button.text.contains("HOST"), "network button still says HOST")
	mode.get_parent().free()

	var fps := (root.get_node("FPSOverlay") as CanvasLayer).get("label") as Label
	var r := fps.get_global_rect()
	_expect(r.end.x < _screen().size.x * 0.5 and r.position.y > _screen().size.y * 0.5, "FPS counter %s sits over the top-right portraits" % r)

	_expect(Accessibility.font(11) == Accessibility.MIN_TEXT_PX and Accessibility.glyph(11) == 11, "minimum text size: font(11) = %d" % Accessibility.font(11))

	var lines := RunSummary.lines({}, [], {"victories": 1, "runs": 1, "best_floor": 2})
	_expect(lines.any(func(l: String) -> bool: return l.contains("1 victoria en 1 partida,")), "run summary plural: %s" % lines[-1])
	_expect(not tr("KEY_HOVER_VOL").contains("Pasado"), "hover volume label reads '%s'" % tr("KEY_HOVER_VOL"))


## The lobby fits the screen (Abandonar reachable) and no hero card cuts its text.
func _check_waiting_room(text_scale: float) -> void:
	var room := _under_layer("res://scenes/menus/WaitingRoom.tscn") as WaitingRoom
	for i in 3:
		await process_frame
	var scroll := room.get_node("Scroll") as ScrollContainer
	var card := (scroll.get_node("CenterContainer/RoomCard") as Control).get_global_rect()
	_expect(_inside(scroll.get_global_rect(), _screen()), "x%.1f Sala de espera: scroll %s off screen" % [text_scale, scroll.get_global_rect()])
	if text_scale == 1.0:
		_expect(_inside(card, _screen()), "x1.0 Sala de espera: card %s off screen %s" % [card, _screen()])
	scroll.scroll_vertical = 100000  # Abandonar, at the bottom, can be scrolled into view
	for i in 2:
		await process_frame
	_expect(_inside(room.leave_button.get_global_rect(), _screen()), "x%.1f Sala de espera: Abandonar %s can't be scrolled on screen" % [text_scale, room.leave_button.get_global_rect()])
	for label: Label in room.character_cards_container.find_children("*", "Label", true, false):
		if label.text != "" and label.is_visible_in_tree():
			_expect(label.get_visible_line_count() >= label.get_line_count(),
				"x%.1f Sala de espera: '%s' shows %d of %d lines" % [text_scale, label.text.left(30), label.get_visible_line_count(), label.get_line_count()])
	room.get_parent().free()

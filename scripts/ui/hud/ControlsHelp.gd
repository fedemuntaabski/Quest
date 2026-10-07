extends PanelContainer
class_name ControlsHelp

## ControlsHelp (calidad-13): every shortcut with its CURRENT binding (read from
## InputMap, so remaps show up) + the fixed mouse and gamepad-cursor controls.
## Opened by show_help (H) in game, and from the pause menu / Opciones.
## Esc, the close button or show_help again closes it.

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS  # usable from the (tree-pausing) pause menu
	add_theme_stylebox_override("panel", UiStyles.build_panel_style(Color(0.06, 0.05, 0.05, 0.96), QuestPalette.GOLD, 2, 10, 18))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func toggle() -> void:
	if visible:
		hide()
	else:
		open()


func open() -> void:
	_rebuild()
	show()
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	var close := find_child("CloseButton", true, false) as Button
	if close and close.is_inside_tree():
		close.grab_focus.call_deferred()  # gamepad: B/Back or A on "Cerrar"


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Controles"
	title.add_theme_font_size_override("font_size", Accessibility.font(26))
	title.add_theme_color_override("font_color", QuestPalette.GOLD)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	scroll.add_child(grid)
	_header(grid, ["Acción", "Teclado", "Mando"])
	for action in InputBindings.REMAPPABLE:
		_row(grid, [InputBindings.REMAPPABLE[action], InputBindings.label(action), InputBindings.label(action, true)])
	_header(grid, ["Ratón", "", ""])
	for pair in InputBindings.MOUSE_HELP:
		_row(grid, [pair[1], pair[0], ""])
	_header(grid, ["Mando (cursor)", "", ""])
	for pair in InputBindings.GAMEPAD_HELP:
		_row(grid, [pair[1], "", pair[0]])
	var hint := Label.new()
	hint.text = "Las teclas se cambian en Opciones > Controles."
	hint.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	box.add_child(hint)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "Cerrar"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(hide)
	box.add_child(close)


func _header(grid: GridContainer, cells: Array) -> void:
	for text in cells:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", Accessibility.font(18))
		label.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT)
		grid.add_child(label)


func _row(grid: GridContainer, cells: Array) -> void:
	for text in cells:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", Accessibility.font(16))
		grid.add_child(label)

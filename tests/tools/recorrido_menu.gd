extends SceneTree

## menu-33: walks the whole menu in a real window with real input events (mouse moves +
## clicks at each button's centre, keyboard ui_down/ui_accept), not by calling the flow:
## menu -> Inicio -> sin conexión -> ranura 3 -> two heroes -> Comenzar -> floor; back to
## the menu; Opciones (each tab) -> Volver; Créditos -> Esc; Tutorial; keyboard focus walk;
## Salir quits. Backs up and restores user://slot_*.cfg. Prints PASS/FAIL lines, exit = fails.
##   godot --path . --script res://tests/tools/recorrido_menu.gd -- <out_dir>

const SLOT := 3

var _main: Main
var _dir: String
var _fails := 0
var _backup: Dictionary = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "user://"
	DirAccess.make_dir_recursive_absolute(_dir)
	_backup_slots()
	await process_frame
	root.mode = Window.MODE_WINDOWED
	for i in 15:
		await process_frame
	root.size = Vector2i(1920, 1080)
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _wait(3.0)
	await _walk()
	print("recorrido_menu: %s (%d fails)" % ["OK" if _fails == 0 else "FAILED", _fails])


func _walk() -> void:
	var menu: Node = _main.ui_container.get_child(0)
	var flow: MainMenuFlow = menu.flow
	await _shot("01_menu")

	# keyboard: focus walk down the column lights each marker
	menu.start_button.grab_focus()
	for i in 4:
		_key(&"ui_down")
		await _wait(0.35)
	var focused := root.gui_get_focus_owner()
	_check(focused == menu.exit_button, "ui_down x4 from INICIO reaches SALIR (focus on %s)" % (focused.name if focused else "nothing"))
	var decor := MenuButtonDecor.of(menu.exit_button)
	_check(decor != null and decor.heat > 0.8, "keyboard focus lights the SALIR marker")
	await _shot("02_menu_teclado_salir")
	for i in 4:
		_key(&"ui_up")
		await _wait(0.2)

	# hover with the mouse
	await _hover(menu.options_button)
	await _wait(0.4)
	_check(MenuButtonDecor.of(menu.options_button).heat > 0.8, "mouse hover lights the OPCIONES marker")
	await _shot("03_menu_hover_opciones")

	# Inicio -> network mode
	await _click(menu.start_button)
	await _wait(1.2)
	_check(flow.network_mode_select.visible and flow.network_mode_select.mode_card.modulate.a > 0.95, "INICIO opens Modo de juego")
	await _shot("04_modo")
	await _click(flow.network_mode_select.offline_button)
	await _wait(1.0)
	_check(flow.slot_selector.visible, "Sin conexión opens the slots")
	await _shot("05_ranuras")
	await _click(flow.slot_selector.slot_buttons[SLOT - 1])
	await _wait(1.2)
	if flow.continue_dialog and is_instance_valid(flow.continue_dialog) and flow.continue_dialog.visible:
		flow.continue_dialog.custom_action.emit(&"new")
		await _wait(1.0)
	_check(flow.hero_select.visible, "a slot opens the hero pick")
	var hs := flow.hero_select
	await _click(hs._cards["warrior"])
	await _wait(0.3)
	await _click(hs._cards["mage"])
	await _wait(0.4)
	_check(hs.can_start() and not hs.start_button.disabled, "two clicked heroes enable COMENZAR")
	await _shot("06_heroes")
	await _click(hs.start_button)
	await _wait(3.0)
	_check(_main.world_container.get_child_count() > 0, "COMENZAR starts the floor")
	await _shot("07_partida")
	await _main.return_to_main_menu()
	await _wait(2.0)

	menu = _main.ui_container.get_child(0)
	flow = menu.flow
	await _click(menu.options_button)
	await _wait(1.2)
	_check(flow.options_menu.visible, "OPCIONES opens")
	var tabs := flow.options_menu.options_tabs
	for i in tabs.get_tab_count():
		await _click_tab(tabs, i)
		await _wait(0.3)
		_check(tabs.current_tab == i, "clicking tab %d selects it" % i)
	await _shot("08_opciones")
	await _click(flow.options_menu.back_button)
	await _wait(1.2)
	_check(not flow.options_menu.visible and menu.center_container.visible, "Volver closes Opciones")

	await _click(menu.credits_button)
	await _wait(1.0)
	var credits := menu.get_node_or_null("CreditsPanel")
	_check(credits != null, "CRÉDITOS opens the credits")
	await _shot("09_creditos")
	_key(&"ui_cancel")
	await _wait(0.6)
	_check(menu.get_node_or_null("CreditsPanel") == null, "Esc closes the credits")

	await _click(menu.tutorial_button)
	await _wait(4.0)
	if _main.intro_screen:
		_main.intro_screen.skip()
		await _wait(2.0)
	_check(_main.world_container.get_child_count() > 0, "TUTORIAL starts the tutorial floor")
	await _shot("10_tutorial")
	await _main.return_to_main_menu()
	await _wait(2.0)

	menu = _main.ui_container.get_child(0)
	await _shot("11_menu_vuelta")
	print("clicking SALIR: the process should end right after this line")
	await _click(menu.exit_button)
	await _wait(3.0)
	_check(false, "SALIR did not quit")


## Salir quits through get_tree().quit() (flushing saves first): restore here too.
func _finalize() -> void:
	_restore_slots()
	print("slots restored at exit")


func _center(c: Control) -> Vector2:
	# canvas_items stretch: control coords -> window pixels
	var xf := c.get_viewport().get_screen_transform() * c.get_global_transform_with_canvas()
	return xf * (c.size * 0.5)


func _hover(c: Control) -> void:
	var m := InputEventMouseMotion.new()
	m.position = _center(c)
	m.global_position = m.position
	root.push_input(m)
	await process_frame


func _click(c: Control) -> void:
	await _hover(c)
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.position = _center(c)
		b.global_position = b.position
		root.push_input(b)
		await process_frame


func _click_tab(tabs: TabContainer, i: int) -> void:
	var bar := tabs.get_tab_bar()
	var r := bar.get_tab_rect(i)
	var xf := bar.get_viewport().get_screen_transform() * bar.get_global_transform_with_canvas()
	var p: Vector2 = xf * (r.position + r.size * 0.5)
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.position = p
		b.global_position = p
		root.push_input(b)
		await process_frame


func _key(action: StringName) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		root.push_input(e)


func _check(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func _backup_slots() -> void:
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("slot_"):  # .cfg and its .bak / .corrupt
			_backup[f] = FileAccess.get_file_as_bytes("user://" + f)
	print("backed up %s" % [_backup.keys()])


func _restore_slots() -> void:
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("slot_") and not _backup.has(f):
			DirAccess.remove_absolute("user://" + f)
	for f: String in _backup:
		var fa := FileAccess.open("user://" + f, FileAccess.WRITE)
		fa.store_buffer(_backup[f])
		fa.close()


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	var frames := 0
	while Time.get_ticks_msec() < end or frames < 3:
		await process_frame
		frames += 1


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, n])

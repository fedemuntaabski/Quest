extends SceneTree

## menu-33: the menu look. Plaques + markers on the main menu and its sub-screens, framed
## panels, the backdrop's cover-fit mapping, fonts through Accessibility, markers kept
## out of get_children(), and the invariant that a hidden menu backdrop (Opciones inside
## the pause menu) never draws from the global RNG (floors are generated from it).
##   godot --headless --path . --script res://tests/test_menu_estetica.gd

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	await process_frame
	_check_rng_untouched()
	await _check_main_menu()
	await _check_sub_screens()
	_check_backdrop_mapping()
	await _check_marker_heat()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_menu_estetica: %s (%d checks, %d failures)" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func _under_layer(scene_path: String) -> Control:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var node := (load(scene_path) as PackedScene).instantiate() as Control
	layer.add_child(node)
	return node


func _check_rng_untouched() -> void:
	for path: String in ["res://scenes/menus/OptionsMenu.tscn", "res://scenes/menus/PauseMenu.tscn"]:
		seed(1234)
		var expected := randi()
		seed(1234)
		var scene := (load(path) as PackedScene).instantiate()
		root.add_child(scene)
		_expect(randi() == expected, "%s consumed the global RNG while hidden" % path.get_file())
		scene.free()


func _check_main_menu() -> void:
	var menu := _under_layer("res://scenes/menus/MainMenu.tscn")
	for i in 3:
		await process_frame
	var buttons: Array = [menu.start_button, menu.tutorial_button, menu.options_button, menu.credits_button, menu.exit_button]
	for btn: Button in buttons:
		_expect(btn != null, "main menu button missing")
		if btn == null:
			continue
		_expect(MenuButtonDecor.of(btn) != null, "%s has no marker" % btn.name)
		_expect(not btn.get_children().any(func(c: Node) -> bool: return c is MenuButtonDecor), "%s: the marker shows in get_children()" % btn.name)
		_expect(btn.get_theme_font_size("font_size") == Accessibility.font(menu.BUTTON_FONT_PX), "%s font size %d" % [btn.name, btn.get_theme_font_size("font_size")])
		var normal := btn.get_theme_stylebox("normal") as StyleBoxFlat
		_expect(normal != null and normal.border_width_left == 3, "%s: not a plaque" % btn.name)
	var exit_rim := (menu.exit_button.get_theme_stylebox("normal") as StyleBoxFlat).border_color
	_expect(exit_rim == QuestPalette.BANNER_RED, "Salir is not the red plaque (%s)" % exit_rim)
	_expect(menu.background is MenuBackdrop and menu.background.texture != null, "main menu backdrop has no picture")
	_expect(menu.version_label.text.begins_with("v"), "version label '%s'" % menu.version_label.text)
	var col: Rect2 = menu.center_container.get_global_rect()
	_expect(col.position.x < root.get_visible_rect().size.x * 0.25, "the button column is not on the left (%s)" % col)
	menu.get_parent().free()


func _check_sub_screens() -> void:
	var slots := _under_layer("res://scenes/menus/SlotSelection.tscn") as SaveSlotSelector
	await process_frame
	_expect(MenuFrameDecor.of(slots.slot_card) != null, "slot card has no frame")
	_expect(MenuButtonDecor.of(slots.slot_buttons[0]) != null, "slot button has no marker")
	_expect(MenuButtonDecor.of(slots.delete_buttons[0]) == null, "delete button should have no marker")
	slots.get_parent().free()

	var mode := _under_layer("res://scenes/menus/NetworkModeSelect.tscn") as NetworkModeSelect
	await process_frame
	_expect(MenuFrameDecor.of(mode.mode_card) != null, "mode card has no frame")
	mode.get_parent().free()

	var options := _under_layer("res://scenes/menus/OptionsMenu.tscn") as OptionsMenu
	await process_frame
	_expect(MenuFrameDecor.of(options.options_card) != null, "options card has no frame")
	_expect(options.get_node("OptionsBackground") is MenuBackdrop, "options backdrop is not a MenuBackdrop")
	options.get_parent().free()

	var hero := _under_layer("res://scenes/menus/HeroSelectMenu.tscn") as HeroSelectMenu
	await process_frame
	_expect(hero.get_node_or_null("Backdrop") is MenuBackdrop, "hero select has no backdrop")
	_expect(MenuButtonDecor.of(hero.start_button) != null, "COMENZAR has no marker")
	hero.get_parent().free()


func _check_backdrop_mapping() -> void:
	var bd := MenuBackdrop.new()
	bd.parallax_px = 0.0
	bd.embers = false
	var img := Image.create(160, 90, false, Image.FORMAT_RGB8)
	bd.texture = ImageTexture.create_from_image(img)
	bd.size = Vector2(1600, 900)
	root.add_child(bd)
	_expect(bd.image_to_local(Vector2(0.5, 0.5)).is_equal_approx(Vector2(800, 450)), "16:9 on 16:9: centre maps to %s" % bd.image_to_local(Vector2(0.5, 0.5)))
	bd.size = Vector2(900, 900)  # square: covered, cropped left/right
	var p := bd.image_to_local(Vector2(0.0, 0.0))
	_expect(is_equal_approx(p.y, 0.0) and p.x < 0.0, "square cover-fit: top-left maps to %s" % p)
	bd.free()


func _check_marker_heat() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var btn := Button.new()
	btn.text = "PRUEBA"
	btn.size = Vector2(300, 60)
	layer.add_child(btn)
	UiStyles.style_plaque_button(btn)
	await process_frame
	var decor := MenuButtonDecor.of(btn)
	btn.grab_focus()
	for i in 30:
		await process_frame
	_expect(decor != null and decor.heat > 0.9, "focus did not light the marker (heat %.2f)" % (decor.heat if decor else -1.0))
	btn.release_focus()
	for i in 40:
		await process_frame
	_expect(decor != null and decor.heat < 0.1, "losing focus did not put the marker out (heat %.2f)" % (decor.heat if decor else -1.0))
	layer.free()

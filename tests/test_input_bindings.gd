extends SceneTree

## Session calidad-13: controls.
##   - code defaults: new actions exist (build_*, chat, show_help, hero_cycle_prev),
##     gamepad events added, move_* deadzone raised
##   - encode/decode round trip (key + mods, joy button, joy axis, mouse)
##   - rebind keeps the other device, conflicts, overrides() only lists changes,
##     apply_overrides() restores them, reset() goes back to the defaults
##   - Shift+Tab cycles back (prev checked before hero_cycle)
##   - VirtualCursor turns A/B/X into left/right/middle mouse buttons
##   - ControlsHelp lists every remappable action with its current binding
##   godot --headless --path . --script res://tests/test_input_bindings.gd

var failures: Array[String] = []


func _initialize() -> void:
	InputBindings.ensure_defaults()  # SettingsManager already did; idempotent
	_test_defaults()
	_test_codec()
	_test_rebind()
	_test_cursor()
	_test_help()
	InputBindings.reset_all()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_input_bindings: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _key(keycode: Key, shift: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.shift_pressed = shift
	ev.pressed = true
	return ev


func _test_defaults() -> void:
	for action in InputBindings.REMAPPABLE:
		_expect(InputMap.has_action(action), "action %s exists" % action)
	_expect(_key(KEY_B).is_action("build_major"), "B -> build_major")
	_expect(_key(KEY_H).is_action("show_help"), "H -> show_help")
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	_expect(start.is_action("tactical_pause"), "Start -> tactical_pause")
	_expect(InputMap.action_get_deadzone("move_up") >= 0.2, "move_up deadzone raised")
	_expect(_key(KEY_TAB, true).is_action("hero_cycle_prev") and not _key(KEY_TAB).is_action("hero_cycle_prev"), "Shift+Tab is prev, Tab is not")
	var before := InputBindings.encode_all(InputMap.action_get_events("build_major"))
	InputBindings.ensure_defaults()
	_expect(InputBindings.encode_all(InputMap.action_get_events("build_major")) == before, "ensure_defaults idempotent")


func _test_codec() -> void:
	var key := _key(KEY_1)
	key.ctrl_pressed = true
	for ev: InputEvent in [key, InputBindings.decode("jb:3"), InputBindings.decode("ja:4:1"), InputBindings.decode("mb:2")]:
		var code := InputBindings.encode(ev)
		var back := InputBindings.decode(code)
		_expect(back != null and InputBindings.encode(back) == code, "round trip %s" % code)
	_expect(InputBindings.decode("k:49:0c").ctrl_pressed, "ctrl modifier decoded")
	_expect(InputBindings.decode("garbage") == null and InputBindings.decode("k:1") == null, "bad codes ignored")


func _test_rebind() -> void:
	InputBindings.reset_all()
	_expect(InputBindings.overrides().is_empty(), "no overrides at defaults")
	InputBindings.rebind("hero_ability", _key(KEY_E), false)
	_expect(_key(KEY_E).is_action("hero_ability") and not _key(KEY_Q).is_action("hero_ability"), "Q -> E")
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	_expect(y.is_action("hero_ability"), "gamepad binding kept on a keyboard rebind")
	_expect(InputBindings.conflicts("hero_ability", _key(KEY_X)) == ["game_speed"], "X conflicts with game_speed: %s" % [InputBindings.conflicts("hero_ability", _key(KEY_X))])
	var saved := InputBindings.overrides()
	_expect(saved.keys() == ["hero_ability"], "only the changed action is saved: %s" % [saved.keys()])
	InputBindings.reset("hero_ability")
	_expect(_key(KEY_Q).is_action("hero_ability"), "reset -> Q")
	InputBindings.apply_overrides(saved)
	_expect(_key(KEY_E).is_action("hero_ability"), "apply_overrides restores E")
	InputBindings.apply_overrides({"not_an_action": ["k:1:0"], "hero_cycle": "bad"})
	_expect(not InputMap.has_action("not_an_action"), "unknown actions ignored")
	InputBindings.reset_all()


func _test_cursor() -> void:
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	var mb := VirtualCursor.to_mouse(a, root)
	_expect(mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed, "A -> left press")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	_expect(VirtualCursor.to_mouse(b, root).button_index == MOUSE_BUTTON_RIGHT, "B -> right")
	var x := InputEventJoypadButton.new()
	x.button_index = JOY_BUTTON_X
	_expect(VirtualCursor.to_mouse(x, root).button_index == MOUSE_BUTTON_MIDDLE, "X -> middle")


func _test_help() -> void:
	var help := ControlsHelp.new()
	root.add_child(help)
	InputBindings.rebind("hero_ability", _key(KEY_E), false)
	help.open()
	var texts: Array[String] = []
	for label in help.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	for action in InputBindings.REMAPPABLE:
		_expect(InputBindings.REMAPPABLE[action] in texts, "help lists %s" % action)
	_expect("E" in texts, "help shows the remapped key")
	help.free()

extends SceneTree

## heroes-9: the active ability's cooldown on game time (frozen in the tactical
## pause, with the "No se puede en pausa táctica" refusal), the portrait's
## AbilityButton (radial fraction, ready pulse, click = Q) and describe() with
## the real numbers.
##   godot --headless --path . --script res://tests/test_ability_cooldown.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	var session := root.get_node("GameSession")
	session.clear()
	session.set_selection(["warrior", "tank"] as Array[String])
	root.get_node("PlayerStats").reset_run_upgrades()

	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame

	var warrior: Player = main2d.heroes[0]
	var abilities := warrior.abilities
	var button: AbilityButton = (hud._portraits[warrior.stats.hero_id] as HeroPortrait).ability_button
	_expect(button.visible and button.icon != null, "portrait shows the ability button with its icon")
	_expect(button.is_ready() and button.cooldown_fraction == 0.0, "ready at the start")
	_expect(button._pulse != null and button._pulse.is_valid(), "ready = pulsing border")

	# describe(): template filled with the hero's numbers.
	var text := abilities.describe(abilities.active)
	_expect(text.contains("50") and text.contains("8") and text.contains("25") and not text.contains("{"), "describe() fills the numbers: '%s'" % text)
	_expect(button.tooltip_text.contains(abilities.display_name()), "tooltip names the ability")
	hud.open_hero_sheet(hud._portraits[warrior.stats.hero_id])
	var sheet := hud.character_popup.get_abilities_text()
	_expect(sheet.contains("Piel de Hierro") and sheet.contains("20 %") and sheet.contains("Grito de Guerra"), "sheet shows passive + active with real text: '%s'" % sheet)
	_expect(hud.character_popup._stat_table.get_child_count() == 6 * 5, "stat table: header + 4 rows x 6 columns (%d cells)" % hud.character_popup._stat_table.get_child_count())
	hud.character_popup.close()

	# Tactical pause: refused with a reason, cooldown frozen.
	Engine.time_scale = 0.0
	_expect(abilities.get_block_reason() == HeroAbilities.PAUSE_REASON, "pause reason: '%s'" % abilities.get_block_reason())
	button.pressed.emit()
	_expect(abilities.cooldown_left == 0.0, "button click in pause doesn't fire")
	_expect(abilities._input_allowed(), "Q still reaches the selected hero in pause (to explain the refusal)")
	Engine.time_scale = 1.0

	# Fire through the button.
	button.pressed.emit()
	var total := abilities.active_cooldown()
	_expect(is_equal_approx(abilities.cooldown_left, total), "cooldown starts at %f (%f)" % [total, abilities.cooldown_left])
	_expect(not button.is_ready() and button.cooldown_fraction > 0.99, "button shows the full pie (%f)" % button.cooldown_fraction)
	_expect(button._pulse == null and not button._hint.visible, "no pulse / Q hint while cooling down")
	_expect(not abilities.try_activate(), "can't fire again during the cooldown")
	_expect(abilities.get_block_reason().contains("s)"), "cooldown reason shows the seconds: '%s'" % abilities.get_block_reason())

	# Game time: frozen at time_scale 0, runs at 1.
	Engine.time_scale = 0.0
	await process_frame
	var frozen := abilities.cooldown_left
	for i in 10:
		await process_frame
	_expect(abilities.cooldown_left == frozen, "cooldown frozen in the tactical pause")
	Engine.time_scale = 1.0
	await process_frame
	var before := abilities.cooldown_left
	for i in 10:
		await process_frame
	_expect(abilities.cooldown_left < before, "cooldown runs on game time")
	_expect(button.cooldown_fraction < 1.0 and button.cooldown_fraction > 0.0, "radial shrinks (%f)" % button.cooldown_fraction)

	# Finish: ready again.
	abilities.cooldown_left = 0.01
	for i in 5:
		await process_frame
	_expect(abilities.cooldown_left == 0.0 and button.is_ready() and button.cooldown_fraction == 0.0, "ready again after the cooldown")
	_expect(button._pulse != null and button._hint.visible, "ready pulse + Q back")

	main2d.queue_free()
	hud.queue_free()
	await process_frame
	session.clear()
	Engine.time_scale = 1.0
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_ability_cooldown: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

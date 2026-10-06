extends SceneTree

## Run curve + difficulty (progresion-10):
##   - run_curve.tres: 5 themed floors (name, tint, music path, pool); multipliers,
##     cap, raider ratio and trap never decrease; boss only on floors 3 (minijefe)
##     and 5 (jefe, 2 phases: charge + summon)
##   - FloorConfig delegates to the curve; without one the linear fallback still works
##   - difficulty_config.tres: Normal = 1.0, Difícil harder on every axis
##   - FloorManager applies curve x difficulty (GameSession.difficulty)
##   godot --headless --path . --script res://tests/test_difficulty_curve.gd

var failures: Array[String] = []


func _initialize() -> void:
	_test_curve()
	_test_difficulty_config()
	await _test_floor_manager()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_difficulty_curve: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _test_curve() -> void:
	var config: FloorConfig = load("res://resources/floors/default_floor_config.tres")
	var curve := config.run_curve
	_expect(curve != null and curve.floors.size() == config.max_floors, "run curve has %d floors" % (curve.floors.size() if curve else 0))
	var names := {}
	var tints := {}
	var prev: FloorTheme = null
	for f in range(1, config.max_floors + 1):
		var t := config.theme(f)
		_expect(t.display_name != "" and not names.has(t.display_name), "floor %d: name '%s' empty or repeated" % [f, t.display_name])
		_expect(not tints.has(t.tint), "floor %d: tint repeated" % f)
		names[t.display_name] = true
		tints[t.tint] = true
		_expect(t.music_path.ends_with("floor_%d.ogg" % f), "floor %d: music path %s" % [f, t.music_path])
		_expect(t.enemy_pool != null and config.enemy_pool(f) == t.enemy_pool, "floor %d: pool not from the theme" % f)
		_expect(is_equal_approx(config.enemy_hp_multiplier(f), t.hp_mult) and is_equal_approx(config.enemy_damage_multiplier(f), t.damage_mult), "floor %d: FloorConfig doesn't delegate multipliers" % f)
		_expect(config.max_enemies(f) == t.max_enemies and is_equal_approx(config.raider_ratio(f), t.raider_ratio), "floor %d: cap/ratio not from the theme" % f)
		if prev:
			_expect(t.hp_mult >= prev.hp_mult and t.damage_mult >= prev.damage_mult and t.threat_mult >= prev.threat_mult, "floor %d: multipliers drop" % f)
			_expect(t.max_enemies >= prev.max_enemies and t.raider_ratio >= prev.raider_ratio, "floor %d: cap/raiders drop" % f)
			_expect(t.trap_damage >= prev.trap_damage, "floor %d: trap weaker than the floor above" % f)
		var wants_boss := f == 3 or f == 5
		_expect((t.boss != null) == wants_boss, "floor %d: boss %s" % [f, t.boss])
		if t.boss:
			_expect(t.boss.is_boss and t.boss.boss_tier == (1 if f == 5 else 0), "floor %d: boss flags" % f)
		prev = t
	var final_boss := config.theme(5).boss
	_expect(final_boss.boss_phases == 2 and final_boss.summon_type != null and final_boss.summon_count > 0 and final_boss.charge_damage > 0, "final boss: 2 phases with charge + summon")
	_expect(config.theme(3).boss.boss_phases == 1 and config.theme(3).boss.charge_damage > 0, "minijefe: 1 phase, charge")
	_expect(config.theme(1).trap_chance == 0.0 and config.theme(2).trap_chance > 0.0, "floor 1 has no trap, floor 2 has one")
	var plain := config.duplicate() as FloorConfig
	plain.run_curve = null
	_expect(is_equal_approx(plain.enemy_hp_multiplier(3), 1.0 + plain.enemy_hp_growth * 2), "no curve: linear HP growth")


func _test_difficulty_config() -> void:
	var cfg := DifficultyConfig.get_default()
	_expect(cfg.levels.size() == 2, "2 difficulties")
	var normal := cfg.get_level("normal")
	var hard := cfg.get_level("hard")
	_expect(normal.hp_mult == 1.0 and normal.damage_mult == 1.0 and normal.threat_mult == 1.0 and normal.extra_max_enemies == 0 and normal.nexo_hp_mult == 1.0 and normal.start_resource_mult == 1.0, "Normal is the identity")
	_expect(hard.hp_mult > 1.0 and hard.damage_mult > 1.0 and hard.threat_mult > 1.0 and hard.extra_max_enemies > 0 and hard.nexo_hp_mult < 1.0 and hard.start_resource_mult < 1.0, "Difícil is harder on every axis")
	_expect(cfg.get_level("nope") == normal, "unknown id falls back to Normal")


func _test_floor_manager() -> void:
	var session := root.get_node("GameSession")
	var config: FloorConfig = load("res://resources/floors/default_floor_config.tres")
	for f in range(1, 6):
		var values := {}
		for id in ["normal", "hard"]:
			session.difficulty = id
			var fm := FloorManager.new()
			root.add_child(fm)
			fm.setup(f, 7)
			values[id] = [fm.enemy_hp_multiplier(), fm.enemy_damage_multiplier(), fm.threat_chance(4), fm.max_enemies(), fm.nexo_max_hp()]
			if id == "normal":
				_expect(is_equal_approx(fm.enemy_hp_multiplier(), config.theme(f).hp_mult), "floor %d normal: HP mult is the curve's" % f)
				_expect(fm.theme() == config.theme(f), "floor %d: FloorManager.theme()" % f)
			fm.free()
		var n: Array = values["normal"]
		var h: Array = values["hard"]
		_expect(h[0] > n[0] and h[1] > n[1] and h[3] > n[3] and h[4] < n[4], "floor %d: hard %s vs normal %s" % [f, h, n])
		_expect(h[2] >= n[2] and h[2] <= config.door_roll.max_chance, "floor %d: hard threat %.2f vs %.2f" % [f, h[2], n[2]])
	session.difficulty = "normal"
	await process_frame

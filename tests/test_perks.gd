extends SceneTree

## Session impl-6, fase 1: class perks (HeroPerk, 1-of-2 at hero level 3 and 5).
##   - 16 perks in data (4 per hero, two exclusive pairs, mods use known keys)
##   - what is on offer per level; invalid / second pick of a group refused
##   - a perk changes exactly the stat / ability number it says, and survives
##     buying levels, a new floor (clear_party + register) and is reset per run
##   - HP never above the global cap, never kills when it shrinks
##   - CharacterPopup cards + HeroPortrait dot
##   godot --headless --path . --script res://tests/test_perks.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HEROES := ["warrior", "mage", "rogue", "tank"]

var failures: Array[String] = []
var ps: Node
var resources: Node


func _initialize() -> void:
	ps = root.get_node("PlayerStats")
	resources = root.get_node("ResourceManager")
	_test_data()
	await _test_warrior_tank()
	await _test_mage_rogue()
	_test_persistence_and_reset()
	await _test_ui()
	root.get_node("GameSession").clear()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_perks: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _boot(ids: Array[String]) -> Node:
	resources.reset_resources(15, 999, 10, 20)
	resources.reset_research()
	ps.reset_run_upgrades()
	root.get_node("GameSession").set_selection(ids)
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	return main2d


func _free(main2d: Node) -> void:
	main2d.queue_free()
	await process_frame
	await process_frame


func _hero(main2d: Node, id: String) -> Player:
	for hero: Player in main2d.heroes:
		if hero.stats.hero_id == id:
			return hero
	failures.append("hero %s not spawned" % id)
	return null


func _level_to(id: String, level: int) -> void:
	resources.add_resource("food", 999)
	while ps.get_hero_level(id) < level:
		_expect(ps.level_up_hero(id), "%s could not reach level %d" % [id, level])
		resources.add_resource("food", 999)


func _test_data() -> void:
	var seen := {}
	for id: String in HEROES:
		var data := CharacterDatabase.get_by_id(id)
		_expect(data.perks.size() == 4, "%s: %d perks, expected 4" % [id, data.perks.size()])
		var groups := {}
		for perk in data.perks:
			_expect(not seen.has(perk.id) and perk.id != &"", "perk id duplicated/empty: %s" % perk.id)
			seen[perk.id] = true
			_expect(perk.display_name != "" and perk.description != "" and perk.describe_mods() != "", "%s: missing text" % perk.id)
			_expect(perk.unlock_level in [3, 5], "%s: unlock level %d" % [perk.id, perk.unlock_level])
			_expect(not perk.mods.is_empty(), "%s: no mods" % perk.id)
			for key: String in perk.mods:
				_expect(key in HeroPerk.MOD_KEYS, "%s: unknown mod '%s'" % [perk.id, key])
			groups[perk.exclusive_group] = int(groups.get(perk.exclusive_group, 0)) + 1
		_expect(groups.size() == 2 and groups.values().all(func(n: int) -> bool: return n == 2), "%s: expected two exclusive pairs: %s" % [id, groups])
	_expect(seen.size() == 16, "16 perks in total, got %d" % seen.size())


func _test_warrior_tank() -> void:
	var main2d := await _boot(["warrior", "tank"] as Array[String])
	var warrior := _hero(main2d, "warrior")
	var tank := _hero(main2d, "tank")
	var base_range := warrior.stats.base_attack_range

	# Offer by level.
	_expect(ps.get_pending_perk_choices("warrior").is_empty() and not ps.has_pending_perk("warrior"), "level 1: nothing on offer")
	_level_to("warrior", 2)
	_expect(ps.get_pending_perk_choices("warrior").is_empty(), "level 2: nothing on offer")
	_level_to("warrior", 3)
	var offer: Array[HeroPerk] = ps.get_pending_perk_choices("warrior")
	_expect(offer.size() == 2 and offer.all(func(p: HeroPerk) -> bool: return p.unlock_level == 3), "level 3: the two level-3 perks")
	_expect(not ps.choose_perk("warrior", &"brazo_largo"), "a level-5 perk must not be pickable at level 3")
	_expect(not ps.choose_perk("warrior", &"nope"), "unknown perk refused")
	var reduction_before: float = warrior.abilities.passive_reduction()
	var duration_before: float = warrior.abilities.active_duration()
	_expect(ps.choose_perk("warrior", &"piel_curtida"), "could not pick piel_curtida")
	_expect(ps.get_pending_perk_choices("warrior").is_empty() and not ps.choose_perk("warrior", &"voz_de_mando"), "the other perk of the group is refused")
	_expect(_near(warrior.abilities.passive_reduction(), reduction_before + 0.05), "piel_curtida: reduction %f -> %f" % [reduction_before, warrior.abilities.passive_reduction()])
	_expect(_near(warrior.abilities.active_duration(), duration_before), "piel_curtida must not touch the active")

	# Level 5: attack range, applied to the hitbox shape too; levels bought afterwards keep it.
	_level_to("warrior", 5)
	_expect(ps.get_pending_perk_choices("warrior").size() == 2, "level 5: the two level-5 perks")
	var cooldown_before: float = warrior.abilities.active_cooldown()
	_expect(ps.choose_perk("warrior", &"brazo_largo"), "could not pick brazo_largo")
	_expect(_near(warrior.stats.attack_range, base_range + 20.0), "brazo_largo: range %f" % warrior.stats.attack_range)
	var circle := (warrior.hitbox.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	_expect(_near(circle.radius, base_range + 20.0), "brazo_largo: hitbox radius %f" % circle.radius)
	_expect(_near(warrior.abilities.active_cooldown(), cooldown_before), "brazo_largo must not touch the cooldown")
	_level_to("warrior", 6)
	_expect(_near(warrior.stats.attack_range, base_range + 20.0), "buying a level kept the range perk")
	_expect(not ps.has_pending_perk("warrior"), "nothing pending after both picks")

	# Tank: Coraza +6 max HP and the same current HP; capped by the global limit.
	_level_to("tank", 3)
	var max_before: int = tank.stats.max_hp
	var hp_before: int = tank.stats.current_hp
	_expect(ps.choose_perk("tank", &"coraza"), "could not pick coraza")
	_expect(tank.stats.max_hp == mini(max_before + 6, StatBalance.PLAYER_MAX_HP) and tank.stats.current_hp == mini(hp_before + 6, StatBalance.PLAYER_MAX_HP), "coraza: %d/%d" % [tank.stats.current_hp, tank.stats.max_hp])
	_level_to("tank", 6)
	_expect(tank.stats.max_hp <= StatBalance.PLAYER_MAX_HP, "max HP %d above the cap" % tank.stats.max_hp)
	_expect(ps.choose_perk("tank", &"interposicion_larga"), "could not pick interposicion_larga")
	_expect(_near(tank.abilities.active_duration(), tank.abilities.active.duration + 2.0), "interposicion_larga: duration")

	await _free(main2d)


func _test_mage_rogue() -> void:
	var main2d := await _boot(["mage", "rogue"] as Array[String])
	var mage := _hero(main2d, "mage")
	var rogue := _hero(main2d, "rogue")
	_level_to("mage", 3)
	_level_to("rogue", 3)
	_expect(ps.choose_perk("mage", &"estudio_profundo"), "mage: estudio_profundo")
	_expect(mage.abilities.passive_discovery_bonus() == {"science": 3}, "estudio_profundo: %s" % [mage.abilities.passive_discovery_bonus()])
	_expect(ps.choose_perk("rogue", &"filo_envenenado"), "rogue: filo_envenenado")
	_expect(_near(rogue.abilities.active_value(), rogue.abilities.active.value + 0.5), "filo_envenenado: x%f" % rogue.abilities.active_value())
	_level_to("mage", 5)
	_level_to("rogue", 5)
	var interval_before: float = rogue.stats.attack_interval
	var damage_before: int = rogue.stats.attack_damage
	_expect(ps.choose_perk("rogue", &"manos_rapidas"), "rogue: manos_rapidas")
	var cfg: UpgradeConfig = ps.run_upgrade_config
	_expect(_near(rogue.stats.attack_interval, maxf(cfg.min_attack_interval, interval_before - 0.05)) and rogue.stats.attack_damage == damage_before, "manos_rapidas: %f" % rogue.stats.attack_interval)
	_level_to("rogue", 6)
	var expected := maxf(cfg.min_attack_interval, cfg.interval_at(rogue.stats.base_attack_interval, 5) - 0.05)
	_expect(_near(rogue.stats.attack_interval, expected), "level after the perk: interval %f, expected %f" % [rogue.stats.attack_interval, expected])
	var cooldown_before: float = mage.abilities.active_cooldown()
	_expect(ps.choose_perk("mage", &"alcance_arcano"), "mage: alcance_arcano")
	_expect(_near(mage.stats.attack_range, mage.stats.base_attack_range + 30.0), "alcance_arcano")
	_expect(_near(mage.abilities.active_cooldown(), cooldown_before), "alcance_arcano must not touch the cooldown")

	# Cooldown perk: the running cooldown is capped to the shorter total.
	mage.abilities.cooldown_left = 29.0
	var data := CharacterDatabase.get_by_id("mage")
	var focus: HeroPerk = data.perks.filter(func(p: HeroPerk) -> bool: return p.id == &"foco_arcano")[0]
	_expect(_near(float(focus.mods["active_cooldown"]), -6.0), "foco_arcano data")
	await _free(main2d)


func _test_persistence_and_reset() -> void:
	ps.reset_run_upgrades()
	resources.reset_resources(15, 999, 10, 20)
	var s := _bare("tank")
	_level_to("tank", 3)
	_expect(ps.choose_perk("tank", &"coraza"), "bare tank: coraza")
	var max_hp := s.max_hp
	# New floor: the party is rebuilt and registers again; levels and perks come back.
	ps.clear_party()
	var fresh := _bare("tank")
	_expect(fresh.max_hp == max_hp and fresh.max_hp == mini(fresh.base_hp + 2 * ps.run_upgrade_config.hp_per_level + 6, StatBalance.PLAYER_MAX_HP), "perk lost on a new floor: %d vs %d" % [fresh.max_hp, max_hp])
	_expect(ps.get_perks_of("tank").size() == 1, "run_perks survive clear_party")
	# New run.
	ps.reset_run_upgrades()
	ps.refresh_stats()
	_expect(ps.run_perks.is_empty() and ps.get_perks_of("tank").is_empty() and fresh.max_hp == fresh.base_hp, "reset: perks and bonus must be gone (%d)" % fresh.max_hp)
	ps.clear_party()
	s.queue_free()
	fresh.queue_free()


## CharacterStats set up like Player._ready does it (no scene), registered in PlayerStats.
func _bare(id: String) -> CharacterStats:
	var data := CharacterDatabase.get_by_id(id)
	var s := CharacterStats.new()
	root.add_child(s)
	s.hero_id = id
	s.base_hp = data.base_hp
	s.set_base_attack(data.attack_damage, data.attack_interval)
	s.set_base_attack_range(data.attack_range)
	ps.register(s)
	return s


func _test_ui() -> void:
	ps.reset_run_upgrades()
	resources.reset_resources(15, 999, 10, 20)
	var data := CharacterDatabase.get_by_id("rogue")
	var s := _bare("rogue")
	var popup := CharacterPopup.new()
	root.add_child(popup)
	await process_frame
	popup.open_for(s, data)
	_expect(popup._perk_title.text.begins_with("Mejoras de clase"), "popup: title '%s'" % popup._perk_title.text)
	_expect(popup._perk_rows.get_child_count() == 1, "level 1: only the hint")
	var portrait := HeroPortrait.new()
	portrait.setup(s, data)
	root.add_child(portrait)
	await process_frame
	_expect(not portrait.has_pending_perk(), "no dot before level 3")
	_level_to("rogue", 3)
	_expect(portrait.has_pending_perk(), "dot after reaching level 3")
	var buttons := popup.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Elegir")
	_expect(buttons.size() == 2, "popup: two 'Elegir' cards, got %d" % buttons.size())
	if buttons.size() == 2:
		buttons[1].pressed.emit()
	_expect(ps.get_perks_of("rogue").size() == 1 and not portrait.has_pending_perk(), "pressing a card picks the perk and clears the dot")
	_expect(popup.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Elegir").is_empty(), "cards gone after picking")
	portrait.queue_free()
	popup.queue_free()
	ps.reset_run_upgrades()
	ps.clear_party()
	s.queue_free()

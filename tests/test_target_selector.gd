extends SceneTree

## Session impl-6, fase 3B: TargetProfile / TargetSelector over a live Main2d.
##   - the 20 enemies have a profile; raider role <=> profile whose first rule is the Nexo
##   - rule priority (turret > trap > hero, generator before any module, carrier > weakest)
##   - hysteresis, retaliate, powered-off modules still targeted, HOLD fallback
##   - target dies -> re-selected in the same frame; module built -> re-evaluated
##   - Module damage feedback (signals + mini bar)
##   godot --headless --path . --script res://tests/test_target_selector.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const FAR := Vector2(9000, 9000)
const EXPECTED := {
	"goblin": "siege", "masked_orc": "siege", "orc_warrior": "siege",
	"skelet": "hunter", "orc_shaman": "hunter", "wogol": "hunter", "necromancer": "hunter", "tc_eyeball": "hunter", "tc_dragon": "hunter",
	"tiny_zombie": "saboteur", "big_zombie": "saboteur", "ogre": "saboteur", "tc_ogre": "saboteur",
	"tc_fire_skull": "tower_breaker", "big_demon": "tower_breaker",
	"imp": "assassin", "tc_red_imp": "assassin", "tc_wolf": "assassin", "chort": "assassin", "tc_demon": "assassin",
}

var failures: Array[String] = []


func _initialize() -> void:
	_test_data()
	await _test_rules()
	await _test_events()
	await _test_module_feedback()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_target_selector: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _type(id: String) -> EnemyType:
	return load("res://resources/enemies/%s.tres" % id) as EnemyType


func _test_data() -> void:
	for id: String in EXPECTED:
		var type := _type(id)
		var profile := type.get_target_profile()
		_expect(profile != null and not profile.rules.is_empty(), "%s: profile without rules" % id)
		if profile == null:
			continue
		_expect(String(profile.id) == EXPECTED[id], "%s: profile '%s', expected '%s'" % [id, profile.id, EXPECTED[id]])
		_expect((type.role == EnemyType.Role.RAIDER) == profile.targets_nexo_first(), "%s: role and profile disagree about raiding" % id)
		_expect(profile.display_name != "" and profile.description != "", "%s: profile needs name/description" % id)
	_expect(EXPECTED.size() == 20, "table should list the 20 enemies")
	# No profile -> derived from role/behavior.
	var plain := EnemyType.new()
	_expect(plain.get_target_profile().id == &"hunter", "derived profile of a plain type should be hunter")
	plain.behavior = 1
	_expect(plain.get_target_profile().id == &"saboteur", "derived profile of a Sapper should be saboteur")
	plain.role = EnemyType.Role.RAIDER
	_expect(plain.get_target_profile().id == &"siege", "derived profile of a raider should be siege")


func _boot() -> Node:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.standalone_floor = 1
	root.add_child(main2d)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false
	for group_id in main2d.door_turn_system.rooms.keys():
		main2d.door_turn_system.rooms[group_id]["visited"] = true
	main2d.room_manager.refresh_visibility()
	main2d.nexo.max_hp = 100000
	main2d.nexo.current_hp = 100000
	for hero in main2d.heroes:
		_place(hero, main2d.room_manager.get_start_zone_id(), FAR)
	return main2d


func _free(main2d: Node) -> void:
	main2d.queue_free()
	await process_frame
	await process_frame


func _place(hero: Player, zone_id: String, pos: Vector2) -> void:
	hero.current_zone_id = zone_id
	hero.global_position = pos


func _rooms(rm: RoomManager) -> Array[String]:
	var rooms: Array[String] = []
	for zone_id in rm.get_zone_ids():
		if rm.get_zone_kind(zone_id) == "room" and rm.find_zone_path(rm.get_start_zone_id(), zone_id).size() > 0 and zone_id != rm.get_start_zone_id():
			rooms.append(zone_id)
	return rooms


func _enemy(main2d: Node, id: String, zone_id: String) -> Enemy:
	var enemies: EnemyManager = main2d.enemy_manager
	var enemy := EnemyManager.ENEMY_SCENE.instantiate() as Enemy
	enemies._enemies_root.add_child(enemy)
	enemy.setup(main2d.room_manager.get_center(zone_id))
	enemy.configure(Enemy.Variant.SWARM, zone_id, 1.0, 1.0, _type(id))
	enemy.ai_timer.stop()
	return enemy


func _build(rm: RoomManager, zone_id: String, module_type: Module.ModuleType) -> Module:
	var room := rm.get_zone_node(zone_id) as RoomZone
	room.set_powered(true)
	var want: int = Module.CATALOG[module_type]["slot"]
	for slot: BuildingSlot in room.find_children("*", "BuildingSlot", true, false):
		if slot.is_empty() and int(slot.slot_type) == want:
			return slot.build(module_type)
	return null


func _test_rules() -> void:
	var main2d := await _boot()
	var rm: RoomManager = main2d.room_manager
	var rooms := _rooms(rm)
	_expect(rooms.size() >= 4, "need 4 rooms, got %d" % rooms.size())
	var home: String = rooms[0]
	var turret_room: String = rooms[1]
	var gen_room: String = rooms[2]
	var hero: Player = main2d.heroes[0]
	var other: Player = main2d.heroes[1]
	var turret := _build(rm, turret_room, Module.ModuleType.BALLESTA)
	var generator := _build(rm, gen_room, Module.ModuleType.FORJA)
	var trap := _build(rm, gen_room, Module.ModuleType.BRASERO)
	_expect(turret != null and generator != null and trap != null, "could not build the test modules")
	_place(hero, home, rm.get_center(home) + Vector2(60, 0))

	# Tower breaker: turret before trap before hero.
	var breaker := _enemy(main2d, "big_demon", home)
	var target := breaker.selector.select(rm)
	_expect(target != null and target.type == TargetRule.Type.MODULE_TURRET and target.node == turret, "breaker: should go for the turret (got %s)" % [target.type if target else "null"])
	_expect(breaker.selector.goal_zone(rm) == turret_room, "breaker: goal zone should be the turret's room")
	turret.powered = false  # switched off: still a target
	_expect(breaker.selector.select(rm).node == turret, "breaker: a switched-off turret is still a target")
	turret.die()
	target = breaker.selector.select(rm)
	_expect(target.type == TargetRule.Type.MODULE_TRAP and target.node == trap, "breaker: turret gone -> trap")
	trap.die()
	target = breaker.selector.select(rm)
	_expect(target.type == TargetRule.Type.HERO_NEAREST and target.node == hero, "breaker: no defenses -> nearest hero")

	# Saboteur: generator even though the trap (any module) is in the same room as it.
	var turret2 := _build(rm, turret_room, Module.ModuleType.BALLESTA)
	var saboteur := _enemy(main2d, "tiny_zombie", home)
	target = saboteur.selector.select(rm)
	_expect(target.type == TargetRule.Type.MODULE_GENERATOR and target.node == generator, "saboteur: generators before any module")
	generator.die()
	target = saboteur.selector.select(rm)
	_expect(target.type == TargetRule.Type.MODULE_ANY and target.node == turret2, "saboteur: then any module")
	turret2.die()
	_expect(saboteur.selector.select(rm).type == TargetRule.Type.HERO_NEAREST, "saboteur: then heroes")

	# Assassin: carrier anywhere > weakest in sight > nearest.
	var assassin := _enemy(main2d, "imp", home)
	_place(hero, home, rm.get_center(home) + Vector2(60, 0))
	_place(other, home, rm.get_center(home) + Vector2(20, 0))
	hero.stats.current_hp = hero.stats.max_hp
	other.stats.current_hp = other.stats.max_hp
	hero.stats.current_hp = maxi(1, hero.stats.max_hp / 2)
	target = assassin.selector.select(rm)
	_expect(target.type == TargetRule.Type.HERO_WEAKEST and target.node == hero, "assassin: should pick the weakest hero in sight")
	_place(hero, rm.get_start_zone_id(), FAR)
	hero.is_carrying_nexo = true
	target = assassin.selector.select(rm)
	_expect(target.type == TargetRule.Type.HERO_CARRIER and target.node == hero, "assassin: the Nexo carrier first, even far away")
	hero.is_carrying_nexo = false
	_expect(assassin.selector.profile.hits_modules_en_route == false, "assassin: ignores modules en route")

	# Retaliate: a raider ignores heroes until hit.
	var raider := _enemy(main2d, "goblin", home)
	_place(hero, home, rm.get_center(home) + Vector2(300, 0))
	_expect(raider.selector.select(rm).type == TargetRule.Type.NEXO, "raider: Nexo first")
	raider.selector.note_hit_by_hero()
	_expect(raider.selector.select(rm).node == hero or raider.selector.select(rm).node == other, "raider: provoked -> goes for a hero")

	# Hysteresis: the chased hero is kept until it leaves reach * drop_range_mult.
	var hunter := _enemy(main2d, "skelet", home)
	var center := rm.get_center(home)
	_place(hero, home, center + Vector2(100, 0))
	_place(other, home, center + Vector2(200, 0))
	hunter.selector.reevaluate()
	_expect(hunter.selector.current.node == hero, "hunter: should chase the nearest hero")
	_place(other, home, center + Vector2(50, 0))
	hunter.selector.reevaluate()
	_expect(hunter.selector.current.node == hero, "hunter: should keep the chased hero while it is valid")
	_place(hero, home, center + Vector2(hunter.aggro_range * 1.3, 0))
	hunter.selector.reevaluate()
	_expect(hunter.selector.current.node == other, "hunter: should drop a hero beyond reach * drop_range_mult")

	# HOLD fallback.
	var holder := _enemy(main2d, "skelet", home)
	var hold_profile := TargetProfile.new()
	hold_profile.fallback = TargetProfile.Fallback.HOLD
	holder.selector.profile = hold_profile
	var held := holder.selector.select(rm)
	_expect(held != null and held.is_hold and holder.selector.goal_zone(rm) == home, "HOLD: should stay in its zone")
	await _free(main2d)


func _test_events() -> void:
	var main2d := await _boot()
	var rm: RoomManager = main2d.room_manager
	var rooms := _rooms(rm)
	var home: String = rooms[0]
	var trap_room: String = rooms[1]
	var hero: Player = main2d.heroes[0]
	_place(hero, home, rm.get_center(home) + Vector2(60, 0))
	var breaker := _enemy(main2d, "big_demon", home)
	breaker.selector.reevaluate()
	_expect(breaker.selector.current != null and breaker.selector.current.type == TargetRule.Type.HERO_NEAREST, "events: starts on the hero")

	# Module built -> re-evaluated immediately.
	var turret := _build(rm, trap_room, Module.ModuleType.BALLESTA)
	_expect(breaker.selector.current.node == turret, "events: building a turret should redirect the breaker at once")

	# Target destroyed -> re-selected in the same frame, target_lost emitted.
	var lost: Array = []
	breaker.selector.target_lost.connect(func(old: Target) -> void: lost.append(old))
	turret.die()
	_expect(lost.size() == 1 and lost[0].node == turret, "events: target_lost should fire once with the old target")
	_expect(breaker.selector.current != null and breaker.selector.current.node != turret, "events: should have re-selected in the same frame")

	# Nexo picked up -> carriers get chased.
	var assassin := _enemy(main2d, "tc_wolf", home)
	_place(hero, rm.get_start_zone_id(), FAR)
	assassin.selector.reevaluate()
	var before := assassin.selector.current
	hero.is_carrying_nexo = true
	main2d.extraction_manager.start_extraction()
	_expect(assassin.selector.current != null and assassin.selector.current.type == TargetRule.Type.HERO_CARRIER, "events: phase change should switch the assassin to the carrier (was %s)" % [before.type if before else "none"])
	hero.is_carrying_nexo = false
	await _free(main2d)


func _test_module_feedback() -> void:
	var main2d := await _boot()
	var rm: RoomManager = main2d.room_manager
	var turret := _build(rm, _rooms(rm)[0], Module.ModuleType.BALLESTA) as TurretModule
	var seen: Array[int] = []
	turret.damaged.connect(func(amount: int) -> void: seen.append(amount))
	var hp_signals: Array[int] = []
	turret.hp_changed.connect(func(current: int, _max: int) -> void: hp_signals.append(current))
	_expect(not turret._bar_back.visible, "module bar hidden at full HP")
	turret.take_damage(4)
	_expect(seen == [4] and hp_signals == [turret.max_hp - 4], "module: damaged/hp_changed should fire")
	_expect(turret._bar_back.visible and turret.is_targetable(), "module bar visible once damaged")
	_expect(turret.get_target_position() == turret.global_position, "module target position")
	turret.powered = false
	_expect(turret.is_targetable(), "switched-off module is still targetable")
	turret.die()
	_expect(not turret.is_targetable(), "destroyed module is not targetable")
	await _free(main2d)

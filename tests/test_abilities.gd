extends SceneTree

## Hero abilities (session balance-4) over a live Main2d: every hero has a passive
## and an active; the passives (damage reduction, Nexo proximity, discovery
## bonuses), the actives (buff, shield, overcharge, burst), cooldowns and the
## hero_ability input gating.
##   godot --headless --path . --script res://tests/test_abilities.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"

var failures: Array[String] = []
var checks := 0
var resources: ResourceManager


func _initialize() -> void:
	resources = root.get_node("ResourceManager") as ResourceManager
	_check_data()
	await _check_warrior_tank()
	await _check_mage_rogue()
	root.get_node("GameSession").clear()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_abilities: %s (%d checks, %d failures)" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func _boot(ids: Array[String]) -> Node:
	resources.reset_resources(15, 15, 10, 20)
	resources.reset_research()
	root.get_node("PlayerStats").reset_run_upgrades()
	_expect(root.get_node("GameSession").set_selection(ids), "party %s rejected" % [ids])
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


func _check_data() -> void:
	for id in BalanceSim.HERO_IDS:
		var data := BalanceSim.hero_data(id)
		_expect(data.passive != null and not data.passive.is_active(), "%s: missing/mis-typed passive" % id)
		_expect(data.active != null and data.active.is_active() and data.active.cooldown > 0.0, "%s: missing/mis-typed active" % id)
		_expect(data.vfx_color != Color.WHITE, "%s: no VFX palette color" % id)


func _check_warrior_tank() -> void:
	var main2d := await _boot(["warrior", "tank"] as Array[String])
	var warrior := _hero(main2d, "warrior")
	var tank := _hero(main2d, "tank")
	if warrior == null or tank == null:
		await _free(main2d)
		return
	# Passives.
	_expect(warrior.abilities.incoming_damage(10) == 8, "Piel de Hierro: 10 -> %d (want 8)" % warrior.abilities.incoming_damage(10))
	_expect(warrior.abilities.incoming_damage(1) == 1, "damage never drops below 1")
	var nexo := ManagerLocator.get_nexo()
	tank.global_position = nexo.get_target_position()
	_expect(tank.abilities.incoming_damage(10) == 5, "Muro Viviente at the Nexo: 10 -> %d (want 5)" % tank.abilities.incoming_damage(10))
	tank.global_position = nexo.get_target_position() + Vector2(5000.0, 0.0)
	_expect(tank.abilities.incoming_damage(10) == 10, "Muro Viviente far from the Nexo should do nothing")

	# Input gating: only a selected hero, never at time_scale 0.
	var selection := ManagerLocator.get_selection_manager()
	selection.select_only("tank")
	_expect(not warrior.abilities._input_allowed() and tank.abilities._input_allowed(), "hero_ability must act only on selected heroes")
	Engine.time_scale = 0.0
	_expect(not tank.abilities._input_allowed(), "hero_ability must not fire during the tactical pause")
	Engine.time_scale = 1.0

	# Active: Grito de Guerra buffs allies in the room, then wears off; cooldown holds.
	var base_damage := warrior.hitbox.damage
	warrior.abilities.active = warrior.abilities.active.duplicate()
	warrior.abilities.active.duration = 0.2
	_expect(warrior.abilities.try_activate(), "Grito de Guerra did not fire")
	_expect(warrior.hitbox.damage > base_damage and warrior.stats.attack_mult == 1.5, "buff not applied to the hitbox (%d vs %d)" % [warrior.hitbox.damage, base_damage])
	_expect(not warrior.abilities.try_activate() and warrior.abilities.cooldown_left > 0.0, "active must be on cooldown after use")
	warrior.abilities._process(5.0)
	_expect(is_equal_approx(warrior.abilities.cooldown_left, warrior.abilities.active.cooldown - 5.0), "cooldown does not tick with game time")
	await create_timer(0.5).timeout
	_expect(warrior.stats.attack_mult == 1.0 and warrior.hitbox.damage == base_damage, "buff did not wear off")

	# Active: Interposición shields the whole party.
	_expect(tank.abilities.try_activate(), "Interposición did not fire")
	_expect(warrior.stats.damage_taken_mult == 0.5 and tank.stats.damage_taken_mult == 0.5, "shield missing on the party")
	_expect(warrior.abilities.incoming_damage(10) == 4, "shield + Piel de Hierro: 10 -> %d (want 4)" % warrior.abilities.incoming_damage(10))

	# A dead hero cannot cast.
	var hp := warrior.stats.current_hp
	warrior.stats.current_hp = 0
	warrior.abilities.cooldown_left = 0.0
	_expect(not warrior.abilities.is_ready() and not warrior.abilities.try_activate(), "a dead hero cast an ability")
	warrior.stats.current_hp = hp
	await _free(main2d)


func _check_mage_rogue() -> void:
	var main2d := await _boot(["mage", "rogue"] as Array[String])
	var mage := _hero(main2d, "mage")
	var rogue := _hero(main2d, "rogue")
	if mage == null or rogue == null:
		await _free(main2d)
		return
	var room_manager: RoomManager = main2d.room_manager
	var start_id := room_manager.get_start_zone_id()

	# Discovery passives: Ciencia (mage) and Polvo (rogue) on top of the floor's dust.
	var science := resources.get_resource("science")
	var dust := resources.get_resource("dust")
	main2d.floor_manager.on_room_discovered(start_id, [] as Array[Vector2i])
	var door_bonus: Dictionary = main2d.floor_manager.door_bonus(start_id)  # every door also pays one random resource
	var bonus_science: int = door_bonus["amount"] if door_bonus["key"] == "science" else 0
	_expect(resources.get_resource("science") - science - bonus_science == roundi(mage.abilities.passive.value), "Mente Analítica: Ciencia %+d" % (resources.get_resource("science") - science))
	var expected_dust: int = main2d.floor_manager.config.discovery_dust(1) + roundi(rogue.abilities.passive.value)
	_expect(resources.get_resource("dust") - dust == expected_dust, "Paso Ligero: Polvo %+d (want %+d)" % [resources.get_resource("dust") - dust, expected_dust])

	# Sobrecarga de Módulo: turret x2 and one extra generator tick.
	var start := room_manager.get_zone_node(start_id)
	var major: BuildingSlot = null
	var minor: BuildingSlot = null
	for slot in start.find_children("*", "BuildingSlot", true, false):
		if slot.slot_type == BuildingSlot.SlotType.MAJOR:
			major = slot
		elif minor == null:
			minor = slot
	if major != null and minor != null:
		major.build(Module.ModuleType.GENERATOR_INDUSTRY)
		var turret := minor.build(Module.ModuleType.TURRET) as TurretModule
		var industry := resources.get_resource("industry")
		var base_damage := turret.get_damage()
		_expect(mage.abilities.try_activate(), "Sobrecarga de Módulo did not fire")
		_expect(turret.get_damage() == base_damage * 2, "turret damage %d (want %d)" % [turret.get_damage(), base_damage * 2])
		_expect(resources.get_resource("industry") - industry == 3, "generator extra tick: industry %+d (want +3)" % (resources.get_resource("industry") - industry))
	else:
		failures.append("start room has no MAJOR/MINOR slot")

	# Golpe Furtivo: burst x3 on every enemy inside the hero's range.
	var enemy := main2d.enemy_manager._spawn_enemy(start_id, rogue.global_position) as Enemy
	await physics_frame
	await physics_frame
	var before := enemy.current_hp
	var strike := roundi(rogue.stats.effective_attack_damage() * rogue.abilities.active.value)
	_expect(rogue.abilities.try_activate(), "Golpe Furtivo did not fire")
	_expect(not is_instance_valid(enemy) or enemy.current_hp == before - strike or not enemy.is_alive(), "burst missed the enemy (%d -> %d, strike %d)" % [before, enemy.current_hp if is_instance_valid(enemy) else 0, strike])
	await _free(main2d)

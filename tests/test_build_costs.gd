extends SceneTree

## Module costs (session economia-8): price grows with the built count,
## demolishing refunds 50 % of what was paid, repairs cost Industria by missing
## HP, Comida heals a hero.
##   godot --headless --path . --script res://tests/test_build_costs.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	_check_curve()
	await _check_live()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_build_costs: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _check_curve() -> void:
	var curve := ModuleCostCurve.get_default()
	_expect(curve.cost(4, 0) == 4, "first module costs its base")
	_expect(curve.cost(4, 1) > curve.cost(4, 0) and curve.cost(4, 2) > curve.cost(4, 1), "cost must rise with the built count")
	_expect(curve.cost(4, 2) == 4 + roundi(4 * curve.step * 2), "cost formula")
	_expect(curve.refund(7) == roundi(7 * 0.5) and is_equal_approx(curve.refund_pct, 0.5), "refund is 50%")
	_expect(curve.repair_cost(6, 0, 15) == 0 and curve.repair_cost(6, 1, 15) >= 1, "repair: free when intact, at least 1 when hurt")
	_expect(curve.repair_cost(6, 15, 15) >= curve.repair_cost(6, 5, 15), "repair scales with missing HP")
	var cfg := load("res://resources/upgrades/run_upgrade_config.tres") as UpgradeConfig
	_expect(cfg.heal_cost(0) == 0 and cfg.heal_cost(1) == 1 and cfg.heal_cost(40) > cfg.heal_cost(10), "heal cost per missing HP")


func _check_live() -> void:
	var rm := root.get_node("ResourceManager") as ResourceManager
	var ps := root.get_node("PlayerStats")
	rm.reset_resources(500, 15, 10, 20)
	rm.reset_research()
	ps.reset_run_upgrades()
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.party_config = main2d.party_config.duplicate()
	main2d.party_config.party_size = 1
	root.add_child(main2d)
	await process_frame
	var room_manager: RoomManager = main2d.room_manager
	var room := room_manager.get_zone_node(room_manager.get_start_zone_id())
	room.set_powered(true)
	var major: BuildingSlot = null
	var minors: Array[BuildingSlot] = []
	for slot in room.find_children("*", "BuildingSlot", true, false):
		if slot.slot_type == BuildingSlot.SlotType.MAJOR:
			major = slot
		else:
			minors.append(slot)
	_expect(major != null and minors.size() == 2, "start room slots")
	if major == null or minors.size() != 2:
		return
	var curve := ModuleCostCurve.get_default()
	var T := Module.ModuleType

	# Rising cost: each Pinchos built makes the next one dearer.
	var base := int(Module.CATALOG[T.PINCHOS]["cost"])
	_expect(Module.get_cost(T.PINCHOS) == base and room_manager.count_modules(T.PINCHOS) == 0, "first spikes trap costs base")
	var first := minors[0].build(T.PINCHOS)
	_expect(room_manager.count_modules(T.PINCHOS) == 1 and Module.get_cost(T.PINCHOS) == curve.cost(base, 1), "second costs %d" % curve.cost(base, 1))
	_expect(first.paid_cost == base, "paid_cost remembers the price")
	var second := minors[1].build(T.PINCHOS)
	_expect(second.paid_cost == curve.cost(base, 1) and Module.get_cost(T.PINCHOS) == curve.cost(base, 2), "third costs %d" % curve.cost(base, 2))
	_expect(Module.get_cost(T.FORJA) == int(Module.CATALOG[T.FORJA]["cost"]), "other types keep their own count")

	# Demolish: 50 % of what was paid, slot freed, count drops.
	var industry := rm.get_resource("industry")
	var refund := second.refund_value()
	_expect(refund == curve.refund(second.paid_cost), "refund_value")
	second.demolish()
	_expect(rm.get_resource("industry") == industry + refund, "demolish refund %d" % refund)
	_expect(minors[1].is_empty() and room_manager.count_modules(T.PINCHOS) == 1, "slot freed and count updated")

	# Repair: costs Industria by missing HP, restores full HP; refuses when intact or short.
	var forja := major.build(T.FORJA)
	_expect(forja.repair_cost() == 0 and not forja.repair(), "intact module needs no repair")
	forja.take_damage(9)
	var cost := forja.repair_cost()
	_expect(cost == curve.repair_cost(int(Module.CATALOG[T.FORJA]["cost"]), 9, forja.max_hp) and cost >= 1, "repair cost %d" % cost)
	rm.spend_resource("industry", rm.get_resource("industry"))
	_expect(not forja.repair() and forja.current_hp < forja.max_hp, "repair without Industria must fail")
	rm.add_resource("industry", 50)
	_expect(forja.repair() and forja.current_hp == forja.max_hp and rm.get_resource("industry") == 50 - cost, "repair spends %d and heals" % cost)

	# Comida heals a hero.
	var stats: CharacterStats = ps.stats
	_expect(ps.get_heal_cost() == 0 and not ps.heal_hero(), "full HP: nothing to heal")
	stats.take_damage(10)
	var heal_cost: int = ps.get_heal_cost()
	var food := rm.get_resource("food")
	_expect(heal_cost == ps.run_upgrade_config.heal_cost(10), "heal cost %d" % heal_cost)
	_expect(ps.heal_hero() and stats.current_hp == stats.max_hp and rm.get_resource("food") == food - heal_cost, "heal_hero spends Comida and restores HP")

	# Catapulta: one shot hits everything near the target; the Ballesta only the target.
	var catapult := minors[1].build(T.CATAPULTA) as TurretModule
	var near := Dummy.new()
	var also_near := Dummy.new()
	var far := Dummy.new()
	for d in [near, also_near, far]:
		d.add_to_group("enemies")
		main2d.add_child(d)
	also_near.global_position = near.global_position + Vector2(catapult.splash_radius * 0.5, 0.0)
	far.global_position = near.global_position + Vector2(catapult.splash_radius * 3.0, 0.0)
	catapult.current_targets = [near]
	catapult._on_fire_timer_timeout()
	_expect(near.taken > 0 and also_near.taken == near.taken and far.taken == 0, "catapult splash: %d/%d/%d" % [near.taken, also_near.taken, far.taken])
	main2d.queue_free()
	await process_frame


class Dummy extends Node2D:
	var taken := 0

	func take_damage(amount: int) -> void:
		taken += amount

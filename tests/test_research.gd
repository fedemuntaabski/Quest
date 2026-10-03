extends SceneTree

## Module research (session economia-8): modules locked at run start, unlock by
## paying Ciencia (needs a built Scriptorium), prerequisites, tiers, run reset.
##   godot --headless --path . --script res://tests/test_research.gd

var failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	var rm := root.get_node("ResourceManager") as ResourceManager
	rm.reset_resources(15, 15, 100, 20)
	rm.reset_research()
	var T := Module.ModuleType

	# Locked at start: Ballesta, Brasero, Catapulta. Free: the 3 majors + Pinchos.
	for locked in [T.BALLESTA, T.BRASERO, T.CATAPULTA]:
		_expect(not rm.is_unlocked(locked), "%s must start locked" % T.keys()[locked])
	for free in [T.FORJA, T.GRANJA, T.SCRIPTORIUM, T.PINCHOS]:
		_expect(rm.is_unlocked(free), "%s must start unlocked" % T.keys()[free])

	# Data: tier 1-3, prerequisites exist and have a lower tier.
	for entry in rm.research_config.entries:
		if entry is ModuleResearch:
			_expect(entry.tier >= 1 and entry.tier <= 3, "%s tier %d" % [entry.id, entry.tier])
			if entry.prerequisite != "":
				var pre := rm.research_config.get_entry(entry.prerequisite) as ModuleResearch
				_expect(pre != null and pre.tier < entry.tier, "%s prerequisite must be a lower-tier module research" % entry.id)

	# Needs a built Scriptorium.
	_expect(rm.get_research_block_reason("ballesta") == "Construí un Scriptorium" and not rm.research("ballesta"), "research without a Scriptorium")
	var scriptorium := (load(Module.CATALOG[T.SCRIPTORIUM]["scene"]) as PackedScene).instantiate() as GeneratorModule
	scriptorium.resource_type = "science"
	scriptorium.yield_amount = 0
	root.add_child(scriptorium)
	await process_frame
	_expect(rm.get_research_block_reason("ballesta") == "", "Scriptorium built: ballesta researchable")

	# Prerequisite: Catapulta needs Ballesta first, and spends nothing while blocked.
	_expect(rm.get_research_block_reason("catapulta") == "Requiere: Planos de ballesta", "catapulta reason: %s" % rm.get_research_block_reason("catapulta"))
	var science := rm.get_resource("science")
	_expect(not rm.research("catapulta") and rm.get_resource("science") == science, "blocked research must not spend")

	# Unlock pays its cost once, instantly, in Ciencia only.
	var ballesta_cost := rm.research_config.get_entry("ballesta").cost
	var industry := rm.get_resource("industry")
	_expect(rm.research("ballesta") and rm.is_unlocked(T.BALLESTA), "ballesta unlock")
	_expect(rm.get_resource("science") == science - ballesta_cost and rm.get_resource("industry") == industry, "only Ciencia is spent")
	_expect(not rm.research("ballesta"), "second purchase must fail")
	_expect(rm.get_research_block_reason("catapulta") == "", "catapulta researchable after ballesta")
	rm.spend_resource("science", rm.get_resource("science"))
	_expect(rm.get_research_block_reason("catapulta") == "Falta Ciencia", "short on Ciencia")
	rm.add_resource("science", 100)
	_expect(rm.research("catapulta") and rm.is_unlocked(T.CATAPULTA) and not rm.is_unlocked(T.BRASERO), "catapulta unlocks only itself")

	# A destroyed Scriptorium blocks research again.
	scriptorium.is_active = false
	_expect(rm.get_research_block_reason("brasero") == "Construí un Scriptorium", "dead Scriptorium must not count")
	scriptorium.is_active = true

	# New run wipes it.
	var main := Main.new()
	main._begin_new_run()
	main.free()
	_expect(not rm.is_researched("ballesta") and not rm.is_unlocked(T.BALLESTA) and not rm.is_unlocked(T.CATAPULTA), "_begin_new_run must reset module research")

	scriptorium.queue_free()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_research: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

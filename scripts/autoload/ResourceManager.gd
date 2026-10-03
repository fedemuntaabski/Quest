extends Node

## ResourceManager — Autoload singleton ("Banco Central").
## Single source of truth for the 4 DotE-style base resources (industry/food/science/dust).
## No persistence yet — resources reset each run (intentional simplification).

signal resource_changed(resource_key: String, new_amount: int, delta: int)
## Per-turn yield may have changed (a generator was built/destroyed). HUD reads get_turn_yield().
signal production_changed
## A research was completed or the run's research was reset.
signal research_changed

const KEYS: Array[String] = ["industry", "food", "science", "dust"]

## Base production per opened door. 0 since session bucle-7: what a door pays
## (dust + one random resource per floor) is DoorRollConfig, paid by
## FloorManager; only generator modules add to the per-turn tick.
const BASE_YIELD_INDUSTRY: int = 0
const BASE_YIELD_FOOD: int = 0
const BASE_YIELD_SCIENCE: int = 0
const BASE_YIELD_DUST: int = 0

const RESEARCH_CONFIG_PATH := "res://resources/research/research_config.tres"
const RESEARCH_RESOURCE := "science"

var _resources: Dictionary = {"industry": 0, "food": 0, "science": 0, "dust": 0}
## Research (session 10) lives here, not in its own autoload: same lifetime as
## the resources (survives floors, reset by Main._begin_new_run) and it is only
## a Ciencia sink. Tests may swap the config.
var research_config: ResearchConfig = load(RESEARCH_CONFIG_PATH)
## Ids researched this run.
var _researched: Dictionary = {}


func get_resource(key: String) -> int:
	return int(_resources.get(key, 0))


func add_resource(key: String, amount: int) -> void:
	if not _resources.has(key):
		push_error("ResourceManager: unknown resource key '%s'" % key)
		return

	_resources[key] = maxi(0, int(_resources[key]) + amount)
	resource_changed.emit(key, _resources[key], amount)


func spend_resource(key: String, amount: int) -> bool:
	if not _resources.has(key):
		push_error("ResourceManager: unknown resource key '%s'" % key)
		return false
	if amount <= 0:
		return true
	if int(_resources[key]) < amount:
		return false

	_resources[key] = int(_resources[key]) - amount
	resource_changed.emit(key, _resources[key], -amount)
	return true


## Sum of `yield_amount` from active GeneratorModules producing `resource_key`.
func _calculate_module_bonus(resource_key: String) -> int:
	var total: int = 0
	for generator in get_tree().get_nodes_in_group("generators"):
		if generator.is_working() and generator.resource_type == resource_key:
			total += generator.yield_amount
	return roundi(total * (1.0 + get_bonus(ResearchEntry.Effect.GENERATOR_YIELD_PCT)))


## Base yield + active generator bonus for one resource, paid every door-open.
func get_turn_yield(resource_key: String) -> int:
	var base: int = {"industry": BASE_YIELD_INDUSTRY, "food": BASE_YIELD_FOOD, "science": BASE_YIELD_SCIENCE, "dust": BASE_YIELD_DUST}.get(resource_key, 0)
	return base + _calculate_module_bonus(resource_key)


func notify_production_changed() -> void:
	production_changed.emit()


## Pays out the per-turn production (base yield + module bonus). Called by DoorTurnSystem.advance_turn().
func process_turn_production() -> void:
	for key: String in KEYS:
		add_resource(key, get_turn_yield(key))


func reset_resources(initial_industry: int = 15, initial_food: int = 15, initial_science: int = 10, initial_dust: int = 20) -> void:
	var initial: Dictionary = {
		"industry": initial_industry,
		"food": initial_food,
		"science": initial_science,
		"dust": initial_dust,
	}
	for key: String in KEYS:
		var old_amount: int = int(_resources[key])
		var new_amount: int = maxi(0, int(initial[key]))
		_resources[key] = new_amount
		resource_changed.emit(key, new_amount, new_amount - old_amount)


# ---------------- RESEARCH ----------------

func is_researched(id: String) -> bool:
	return _researched.has(id)


## "" if `id` can be researched now, else why not.
func get_research_block_reason(id: String) -> String:
	var entry := research_config.get_entry(id)
	if entry == null:
		return "Investigación desconocida"
	if is_researched(id):
		return "Investigada"
	if entry.prerequisite != "" and not is_researched(entry.prerequisite):
		var pre := research_config.get_entry(entry.prerequisite)
		return "Requiere: %s" % (pre.display_name if pre else entry.prerequisite)
	if get_resource(RESEARCH_RESOURCE) < entry.cost:
		return "Falta Ciencia"
	return ""


func can_research(id: String) -> bool:
	return get_research_block_reason(id) == ""


## Spends the entry's Ciencia and applies it. False (nothing spent) if blocked.
func research(id: String) -> bool:
	if not can_research(id) or not spend_resource(RESEARCH_RESOURCE, research_config.get_entry(id).cost):
		return false
	_researched[id] = true
	research_changed.emit()
	production_changed.emit()
	return true


## False only while the entry that unlocks `module` isn't researched.
func is_unlocked(module: Module.ModuleType) -> bool:
	var entry := research_config.get_unlock_entry(module)
	return entry == null or is_researched(entry.id)


## Sum of `value` over researched entries with this effect.
func get_bonus(kind: ResearchEntry.Effect) -> float:
	var total := 0.0
	for entry in research_config.entries:
		if entry.effect == kind and is_researched(entry.id):
			total += entry.value
	return total


## New run (Main._begin_new_run, next to PlayerStats.reset_run_upgrades).
func reset_research() -> void:
	_researched.clear()
	research_changed.emit()
	production_changed.emit()

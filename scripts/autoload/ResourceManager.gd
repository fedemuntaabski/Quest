extends Node

## ResourceManager — Autoload singleton ("Banco Central").
## Single source of truth for the 4 DotE-style base resources (iron/food/lore/embers).
## No persistence yet — resources reset each run (intentional simplification).

signal resource_changed(resource_key: String, new_amount: int, delta: int)
## Per-turn yield may have changed (a workshop was built/destroyed). HUD reads get_turn_yield().
signal production_changed
## A research was completed or the run's research was reset.
signal research_changed

const KEYS: Array[String] = ["iron", "food", "lore", "embers"]

## Base production per opened door. 0 since session bucle-7: what a door pays
## (embers + one random resource per floor) is DoorRollConfig, paid by
## FloorManager; only workshop buildings add to the per-turn tick.
const BASE_YIELD_IRON: int = 0
const BASE_YIELD_FOOD: int = 0
const BASE_YIELD_LORE: int = 0
const BASE_YIELD_EMBERS: int = 0

const RESEARCH_CONFIG_PATH := "res://resources/research/research_config.tres"
const RESEARCH_RESOURCE := "lore"

var _resources: Dictionary = {"iron": 0, "food": 0, "lore": 0, "embers": 0}
## Research (session 10) lives here, not in its own autoload: same lifetime as
## the resources (survives floors, reset by Main._begin_new_run) and it is only
## a Saber sink. Tests may swap the config.
var research_config: ResearchConfig = load(RESEARCH_CONFIG_PATH)
## Ids researched this run.
var research_state := ResearchState.new()


func get_resource(key: String) -> int:
	return int(_resources.get(key, 0))


func add_resource(key: String, amount: int) -> void:
	if not Net.is_authority():  # coop-12: a client mirrors the host, never mutates
		return
	if not _resources.has(key):
		push_error("ResourceManager: unknown resource key '%s'" % key)
		return

	_resources[key] = maxi(0, int(_resources[key]) + amount)
	resource_changed.emit(key, _resources[key], amount)


func spend_resource(key: String, amount: int) -> bool:
	if not Net.is_authority():  # coop-12: a client mirrors the host, never mutates
		return false
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


## Sum of `yield_amount` from active WorkshopBuildings producing `resource_key`.
func _calculate_building_bonus(resource_key: String) -> int:
	var total: int = 0
	for workshop in get_tree().get_nodes_in_group("workshops"):
		if workshop.is_working() and workshop.resource_type == resource_key:
			total += workshop.yield_amount
	return roundi(total * (1.0 + get_bonus(ResearchEntry.Effect.WORKSHOP_YIELD_PCT)))


## Base yield + active workshop bonus for one resource, paid every door-open.
func get_turn_yield(resource_key: String) -> int:
	var base: int = {"iron": BASE_YIELD_IRON, "food": BASE_YIELD_FOOD, "lore": BASE_YIELD_LORE, "embers": BASE_YIELD_EMBERS}.get(resource_key, 0)
	return base + _calculate_building_bonus(resource_key)


func notify_production_changed() -> void:
	production_changed.emit()


## Pays out the per-turn production (base yield + building bonus). Called by DoorTurnSystem.advance_turn().
func process_turn_production() -> void:
	for key: String in KEYS:
		add_resource(key, get_turn_yield(key))


func reset_resources(initial_iron: int = 15, initial_food: int = 15, initial_lore: int = 10, initial_embers: int = 20) -> void:
	var initial: Dictionary = {
		"iron": initial_iron,
		"food": initial_food,
		"lore": initial_lore,
		"embers": initial_embers,
	}
	for key: String in KEYS:
		var old_amount: int = int(_resources[key])
		var new_amount: int = maxi(0, int(initial[key]))
		_resources[key] = new_amount
		resource_changed.emit(key, new_amount, new_amount - old_amount)


# ---------------- RESEARCH ----------------

func is_researched(id: String) -> bool:
	return research_state.has(id)


## "" if `id` can be researched now, else why not.
func get_research_block_reason(id: String) -> String:
	var entry := research_config.get_entry(id)
	if entry == null:
		return "Investigación desconocida"
	if is_researched(id):
		return "Investigada"
	if not _has_working_scriptorium():
		return "Construí un Scriptorium"
	if entry.prerequisite != "" and not is_researched(entry.prerequisite):
		var pre := research_config.get_entry(entry.prerequisite)
		return "Requiere: %s" % (pre.display_name if pre else entry.prerequisite)
	if get_resource(RESEARCH_RESOURCE) < entry.cost:
		return "Falta Saber"
	return ""


## Researching needs a built, active Scriptorium (a Saber workshop).
func _has_working_scriptorium() -> bool:
	for g in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("workshops"):
		if g is WorkshopBuilding and g.resource_type == RESEARCH_RESOURCE and g.is_active:
			return true
	return false


func can_research(id: String) -> bool:
	return get_research_block_reason(id) == ""


## Spends the entry's Saber and applies it. False (nothing spent) if blocked.
func research(id: String) -> bool:
	if not Net.is_authority():  # coop-12: a client mirrors the host, never mutates
		return false
	if not can_research(id) or not spend_resource(RESEARCH_RESOURCE, research_config.get_entry(id).cost):
		return false
	research_state.add(id)
	research_changed.emit()
	production_changed.emit()
	return true


## False only while the entry that unlocks `building` isn't researched.
func is_unlocked(building: Building.BuildingType) -> bool:
	var entry := research_config.get_unlock_entry(building)
	return entry == null or is_researched(entry.id)


## Sum of `value` over researched entries with this effect.
func get_bonus(kind: ResearchEntry.Effect) -> float:
	var total := 0.0
	for entry in research_config.entries:
		if entry.effect == kind and is_researched(entry.id):
			total += entry.value
	return total


## coop-12: {resources, research} for RunState (host -> clients).
func get_state() -> Dictionary:
	var ids: Array = research_state.researched.keys()
	ids.sort()
	return {"res": _resources.duplicate(), "research": ids}


## coop-12 (client): the host's numbers, through the same signals the HUD reads.
func apply_state(d: Dictionary) -> void:
	var res: Dictionary = d.get("res", {})
	for key: String in KEYS:
		var amount := int(res.get(key, _resources[key]))
		if amount != int(_resources[key]):
			var delta := amount - int(_resources[key])
			_resources[key] = amount
			resource_changed.emit(key, amount, delta)
	var ids: Array = d.get("research", [])
	if ids.size() != research_state.researched.size():
		research_state.reset()
		for id in ids:
			research_state.add(id)
		research_changed.emit()
		production_changed.emit()


## New run (Main._begin_new_run, next to PlayerStats.reset_run_upgrades).
func reset_research() -> void:
	research_state.reset()
	research_changed.emit()
	production_changed.emit()

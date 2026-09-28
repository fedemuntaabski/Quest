extends Node

## ResourceManager — Autoload singleton ("Banco Central").
## Single source of truth for the 4 DotE-style base resources (industry/food/science/dust).
## No persistence yet — resources reset each run (intentional simplification).

signal resource_changed(resource_key: String, new_amount: int, delta: int)
## Per-turn yield may have changed (a generator was built/destroyed). HUD reads get_turn_yield().
signal production_changed

const KEYS: Array[String] = ["industry", "food", "science", "dust"]

## Base production per opened door. Dust is never generated passively.
const BASE_YIELD_INDUSTRY: int = 2
const BASE_YIELD_FOOD: int = 2
const BASE_YIELD_SCIENCE: int = 1
const BASE_YIELD_DUST: int = 0

var _resources: Dictionary = {"industry": 0, "food": 0, "science": 0, "dust": 0}


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


func add_all(industry_amt: int, food_amt: int, science_amt: int, dust_amt: int) -> void:
	add_resource("industry", industry_amt)
	add_resource("food", food_amt)
	add_resource("science", science_amt)
	add_resource("dust", dust_amt)


## Sum of `yield_amount` from active GeneratorModules producing `resource_key`.
func _calculate_module_bonus(resource_key: String) -> int:
	var total: int = 0
	for generator in get_tree().get_nodes_in_group("generators"):
		if generator.is_working() and generator.resource_type == resource_key:
			total += generator.yield_amount
	return total


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

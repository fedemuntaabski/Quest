extends Node

## ResourceManager — Autoload singleton ("Banco Central").
## Single source of truth for the 4 DotE-style base resources (industry/food/science/dust).
## No persistence yet — resources reset each run (intentional simplification).

signal resource_changed(resource_key: String, new_amount: int, delta: int)

const KEYS: Array[String] = ["industry", "food", "science", "dust"]

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

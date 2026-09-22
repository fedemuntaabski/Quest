extends Node

## ResourceManager — Autoload singleton.
## Tracks the 4 DotE-style base resources (industry/food/science/dust).
## No persistence yet — resources reset each run (intentional simplification).

signal resource_changed(resource_key: String, amount: int, delta: int)

const KEYS := ["industry", "food", "science", "dust"]

var industry: int = 0
var food: int = 0
var science: int = 0
var dust: int = 0


func get_resource(key: String) -> int:
	match key:
		"industry": return industry
		"food": return food
		"science": return science
		"dust": return dust
		_:
			push_warning("ResourceManager: unknown resource key '%s'" % key)
			return 0


func add_resource(key: String, delta: int) -> void:
	var current: int = get_resource(key)
	var next: int = maxi(0, current + delta)

	match key:
		"industry": industry = next
		"food": food = next
		"science": science = next
		"dust": dust = next
		_:
			push_warning("ResourceManager: unknown resource key '%s'" % key)
			return

	resource_changed.emit(key, next, delta)


func spend_resource(key: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if get_resource(key) < amount:
		return false
	add_resource(key, -amount)
	return true


func add_all(industry_delta: int, food_delta: int, science_delta: int, dust_delta: int) -> void:
	add_resource("industry", industry_delta)
	add_resource("food", food_delta)
	add_resource("science", science_delta)
	add_resource("dust", dust_delta)


func reset() -> void:
	for key in KEYS:
		add_resource(key, -get_resource(key))

extends RefCounted
class_name ModifierStack

var base_value: int = 0
var permanent_mod: int = 0
var runtime_total: int = 0
var _runtime_modifiers: Dictionary = {}
var _serial: int = 0

func _init(_base: int = 0) -> void:
	base_value = int(_base)

func get_total() -> int:
	return base_value + permanent_mod + runtime_total

func add_runtime_modifier(value: int, duration_turns: int = 1, source: String = "") -> String:
	_serial += 1
	var id := "rs_%d" % _serial
	_runtime_modifiers[id] = {"value": int(value), "remaining": max(1, int(duration_turns)), "source": source, "fresh": true}
	runtime_total += int(value)
	return id

func tick_turn_start() -> Array:
	return tick_turn_end()

func tick_turn_end() -> Array:
	var expired: Array = []
	var remove_keys: Array = []
	for key in _runtime_modifiers.keys():
		var m: Dictionary = _runtime_modifiers[key]
		if bool(m.get("fresh", false)):
			m["fresh"] = false
			_runtime_modifiers[key] = m
			continue
		m["remaining"] -= 1
		if m["remaining"] <= 0:
			expired.append({"id": key, "value": m["value"], "source": m.get("source", "")})
			remove_keys.append(key)
		else:
			_runtime_modifiers[key] = m
	for k in remove_keys:
		var val := int(_runtime_modifiers[k]["value"])
		runtime_total -= val
		_runtime_modifiers.erase(k)
	return expired

func clear_runtime_modifiers() -> void:
	_runtime_modifiers.clear()
	runtime_total = 0

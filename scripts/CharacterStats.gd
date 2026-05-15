extends Node
class_name CharacterStats

# -------------------------
# BASIC INFO
# -------------------------
var character_name: String = "Unnamed"

signal hp_changed(current, max)
signal died
signal stats_changed

# -------------------------
# HEALTH
# -------------------------
var max_hp: int = 20
var current_hp: int = 20

# -------------------------
# CORE STATS (BASE)
# -------------------------
var strength: int = 1
var magic: int = 1
var dexterity: int = 1

# -------------------------
# MODIFIERS (FROM UPGRADES)
# -------------------------
var strength_mod: int = 0
var magic_mod: int = 0
var dexterity_mod: int = 0

# -------------------------
# MODIFIERS (FROM TEMP BUFFS)
# -------------------------
var strength_runtime_mod: int = 0
var magic_runtime_mod: int = 0
var dexterity_runtime_mod: int = 0

var _runtime_modifiers: Dictionary = {}
var _runtime_modifier_serial: int = 0

func reset_modifiers() -> void:
	strength_mod = 0
	magic_mod = 0
	dexterity_mod = 0

func reset_runtime_modifiers() -> void:
	if _runtime_modifiers.is_empty():
		return
	_runtime_modifiers.clear()
	strength_runtime_mod = 0
	magic_runtime_mod = 0
	dexterity_runtime_mod = 0
	stats_changed.emit()

# -------------------------
# TOTAL STATS
# -------------------------
func get_total_strength() -> int:
	return strength + strength_mod + strength_runtime_mod

func get_total_magic() -> int:
	return magic + magic_mod + magic_runtime_mod

func get_total_dexterity() -> int:
	return dexterity + dexterity_mod + dexterity_runtime_mod

# -------------------------
# HEALTH SYSTEM
# -------------------------
func take_damage(amount: int) -> void:
	current_hp = max(current_hp - amount, 0)
	hp_changed.emit(current_hp, max_hp)

	if current_hp <= 0:
		died.emit()

func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)
	hp_changed.emit(current_hp, max_hp)

func is_alive() -> bool:
	return current_hp > 0

# -------------------------
# MODIFIERS
# -------------------------
func apply_modifier(stat: String, value: int) -> void:
	match stat:
		"strength":
			strength_mod += value
		"magic":
			magic_mod += value
		"dexterity":
			dexterity_mod += value
		"hp":
			max_hp = max(1, max_hp + value)
			current_hp = min(current_hp + value, max_hp)
		_:
			push_warning("Unknown stat: %s" % stat)

	stats_changed.emit()

func apply_runtime_modifier(stat: String, value: int, duration_turns: int = 1, source: String = "") -> String:
	var stat_key := stat.to_lower()
	if not _apply_runtime_delta(stat_key, value):
		push_warning("Unknown runtime stat: %s" % stat)
		return ""

	_runtime_modifier_serial += 1
	var modifier_id := "%s_runtime_%d" % [stat_key, _runtime_modifier_serial]
	_runtime_modifiers[modifier_id] = {
		"stat": stat_key,
		"value": value,
		"remaining_turns": max(1, duration_turns),
		"source": source,
	}
	stats_changed.emit()
	return modifier_id

func process_runtime_modifiers_turn_start() -> Dictionary:
	var result := {
		"changed": false,
		"expired": [],
	}

	if _runtime_modifiers.is_empty():
		return result

	var expired_ids: Array[String] = []
	for modifier_id in _runtime_modifiers.keys():
		var modifier: Dictionary = _runtime_modifiers[modifier_id]
		var remaining_turns: int = int(modifier.get("remaining_turns", 0)) - 1
		if remaining_turns <= 0:
			expired_ids.append(str(modifier_id))
			result["expired"].append(modifier.duplicate(true))
			_apply_runtime_delta(str(modifier.get("stat", "")), -int(modifier.get("value", 0)))
		else:
			modifier["remaining_turns"] = remaining_turns
			_runtime_modifiers[modifier_id] = modifier

	if expired_ids.is_empty():
		return result

	for modifier_id in expired_ids:
		_runtime_modifiers.erase(modifier_id)

	result["changed"] = true
	stats_changed.emit()
	return result

func _apply_runtime_delta(stat: String, value: int) -> bool:
	match stat:
		"strength":
			strength_runtime_mod += value
			return true
		"magic":
			magic_runtime_mod += value
			return true
		"dexterity":
			dexterity_runtime_mod += value
			return true
		_:
			return false

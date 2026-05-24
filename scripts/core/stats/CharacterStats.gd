extends Node
class_name CharacterStats

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")

# -------------------------
# BASIC INFO
# -------------------------
var character_name: String = "Unnamed"
var potions_owned: int = 1

signal hp_changed(current, max)
signal died
signal stats_changed

# -------------------------
# HEALTH
# -------------------------
var max_hp: int = StatBalance.PLAYER_BASE_HP
var current_hp: int = StatBalance.PLAYER_BASE_HP

# -------------------------
# CORE STATS (BASE)
# -------------------------
var strength: int = 1
var magic: int = 1
var dexterity: int = 1

# -------------------------
# PERMANENT MODIFIERS
# -------------------------
var strength_mod: int = 0
var magic_mod: int = 0
var dexterity_mod: int = 0

# -------------------------
# RUNTIME MODIFIER TRACKING
# -------------------------
# -------------------------
# MODIFIER STACKS
# -------------------------
var strength_stack: ModifierStack = null
var magic_stack: ModifierStack = null
var dexterity_stack: ModifierStack = null

# -------------------------
# RESET
# -------------------------
func reset_modifiers() -> void:
	strength_mod = 0
	magic_mod = 0
	dexterity_mod = 0

	max_hp = StatBalance.PLAYER_BASE_HP
	current_hp = min(current_hp, max_hp)

	if strength_stack != null:
		strength_stack.permanent_mod = 0

	if magic_stack != null:
		magic_stack.permanent_mod = 0

	if dexterity_stack != null:
		dexterity_stack.permanent_mod = 0

	hp_changed.emit(current_hp, max_hp)
	stats_changed.emit()

func reset_runtime_modifiers() -> void:
	if strength_stack != null:
		strength_stack.clear_runtime_modifiers()

	if magic_stack != null:
		magic_stack.clear_runtime_modifiers()

	if dexterity_stack != null:
		dexterity_stack.clear_runtime_modifiers()

	stats_changed.emit()

# -------------------------
# TOTAL STATS
# -------------------------
func get_total_stat(stat_key: String, fallback_key: String = "strength") -> int:
	match stat_key.to_lower():
		"strength":
			return get_total_strength()

		"magic":
			return get_total_magic()

		"dexterity":
			return get_total_dexterity()

		_:
			match fallback_key.to_lower():
				"magic":
					return get_total_magic()

				"dexterity":
					return get_total_dexterity()

				_:
					return get_total_strength()

func get_total_strength() -> int:
	_ensure_stacks()
	return strength_stack.get_total()

func get_total_magic() -> int:
	_ensure_stacks()
	return magic_stack.get_total()

func get_total_dexterity() -> int:
	_ensure_stacks()
	return dexterity_stack.get_total()

# -------------------------
# HEALTH SYSTEM
# -------------------------
func take_damage(amount: int) -> void:
	current_hp = max(current_hp - max(amount, 0), 0)

	hp_changed.emit(current_hp, max_hp)

	if current_hp <= 0:
		died.emit()

func heal(amount: int) -> void:
	current_hp = min(current_hp + max(amount, 0), max_hp)
	hp_changed.emit(current_hp, max_hp)

func use_potion() -> bool:
	if potions_owned <= 0:
		return false

	if current_hp >= max_hp:
		return false

	var heal_amount := int(ceil(float(max_hp) * 0.5))

	heal(heal_amount)

	potions_owned -= 1

	stats_changed.emit()

	return true

func is_alive() -> bool:
	return current_hp > 0

# -------------------------
# PERMANENT MODIFIERS
# -------------------------
func apply_modifier(stat: String, value: int) -> void:
	var stat_key := stat.to_lower()

	match stat_key:
		"strength":
			strength_mod += value

			if strength_stack != null:
				strength_stack.permanent_mod = strength_mod

		"magic":
			magic_mod += value

			if magic_stack != null:
				magic_stack.permanent_mod = magic_mod

		"dexterity":
			dexterity_mod += value

			if dexterity_stack != null:
				dexterity_stack.permanent_mod = dexterity_mod

		"hp":
			var hp_state := StatBalance.apply_hp_delta(max_hp, current_hp, value)

			max_hp = int(hp_state.get("max_hp", max_hp))
			current_hp = int(hp_state.get("current_hp", current_hp))

			hp_changed.emit(current_hp, max_hp)

		_:
			push_warning("Unknown stat: %s" % stat_key)
			return

	stats_changed.emit()

# -------------------------
# RUNTIME MODIFIERS
# -------------------------
func apply_runtime_modifier(
	stat: String,
	value: int,
	duration_turns: int = 1,
	source: String = ""
) -> String:

	var stat_key := stat.to_lower()

	_ensure_stacks()

	var stack: ModifierStack = null

	match stat_key:
		"strength":
			stack = strength_stack

		"magic":
			stack = magic_stack

		"dexterity":
			stack = dexterity_stack

		_:
			push_warning("Unknown runtime stat: %s" % stat_key)
			return ""

	var modifier_id := stack.add_runtime_modifier(
		value,
		duration_turns,
		source
	)

	stats_changed.emit()

	return modifier_id

func process_runtime_modifiers_turn_start() -> Dictionary:
	var result := {
		"changed": false,
		"expired": []
	}

	_ensure_stacks()

	var changed := false

	var stacks := {
		"strength": strength_stack,
		"magic": magic_stack,
		"dexterity": dexterity_stack
	}

	for stat_key in stacks.keys():
		var stack: ModifierStack = stacks[stat_key]

		if stack == null:
			continue

		var expired := stack.tick_turn_start()

		if expired.is_empty():
			continue

		changed = true

		for entry in expired:
			var payload = entry.duplicate(true)
			payload["stat"] = stat_key
			result["expired"].append(payload)

	if changed:
		result["changed"] = true
		stats_changed.emit()

	return result

# -------------------------
# STACK INITIALIZATION
# -------------------------
func _ensure_stacks() -> void:
	if strength_stack == null:
		strength_stack = ModifierStack.new(strength)

	if magic_stack == null:
		magic_stack = ModifierStack.new(magic)

	if dexterity_stack == null:
		dexterity_stack = ModifierStack.new(dexterity)

	strength_stack.base_value = strength
	magic_stack.base_value = magic
	dexterity_stack.base_value = dexterity

	strength_stack.permanent_mod = strength_mod
	magic_stack.permanent_mod = magic_mod
	dexterity_stack.permanent_mod = dexterity_mod

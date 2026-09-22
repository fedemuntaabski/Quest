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
signal potion_used(heal_amount: int, remaining: int)

# -------------------------
# HEALTH
# -------------------------
var max_hp: int = StatBalance.PLAYER_BASE_HP
var current_hp: int = StatBalance.PLAYER_BASE_HP

# -------------------------
# RESET
# -------------------------
func reset_modifiers() -> void:
	max_hp = StatBalance.PLAYER_BASE_HP
	current_hp = min(current_hp, max_hp)

	hp_changed.emit(current_hp, max_hp)
	stats_changed.emit()

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
	potion_used.emit(heal_amount, potions_owned)
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
		"hp":
			var hp_state := StatBalance.apply_hp_delta(max_hp, current_hp, value)

			max_hp = int(hp_state.get("max_hp", max_hp))
			current_hp = int(hp_state.get("current_hp", current_hp))

			hp_changed.emit(current_hp, max_hp)

		_:
			push_warning("Unknown stat: %s" % stat_key)
			return

	stats_changed.emit()

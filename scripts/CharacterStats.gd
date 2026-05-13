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
# TOTAL STATS
# -------------------------
func get_total_strength() -> int:
	return strength + strength_mod

func get_total_magic() -> int:
	return magic + magic_mod

func get_total_dexterity() -> int:
	return dexterity + dexterity_mod

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
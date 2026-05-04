extends Node
class_name CharacterStats

# -------------------------
# BASIC INFO
# -------------------------
var character_name: String = "Unnamed"

signal hp_changed(current, max)
signal died

# -------------------------
# HEALTH
# -------------------------
var max_hp: int = 10
var current_hp: int = 10

# -------------------------
# CORE STATS
# -------------------------
var stats := {
	"strength": 0,
	"agility": 0,
	"intelligence": 0
}

# -------------------------
# DAMAGE & LIFE (USED BY COMBATMANAGER)
# -------------------------

func take_damage(amount: int) -> void:
	current_hp = max(current_hp - amount, 0)
	emit_signal("hp_changed", current_hp, max_hp)

	if current_hp <= 0:
		current_hp = 0
		emit_signal("died")

func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)
	emit_signal("hp_changed", current_hp, max_hp)

func is_alive() -> bool:
	return current_hp > 0

# -------------------------
# STAT SYSTEM (USED BY COMBATRULES)
# -------------------------

func get_modifier(stat_name: String) -> int:
	if not stats.has(stat_name):
		return 0
	return stats[stat_name]

func set_stat(stat_name: String, value: int) -> void:
	stats[stat_name] = value

func add_to_stat(stat_name: String, value: int) -> void:
	if not stats.has(stat_name):
		stats[stat_name] = 0
	stats[stat_name] += value

func apply_damage(amount: int) -> void:
	take_damage(amount)
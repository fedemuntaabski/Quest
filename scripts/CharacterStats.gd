extends Node
class_name CharacterStats

# Basic info
var character_name: String = "Unnamed"

# Health
var max_hp: int = 10
var current_hp: int = 10

# Stats (podés expandir esto después)
var stats := {
	"strength": 0,
	"agility": 0,
	"intelligence": 0
}

# -------------------------
# DAMAGE & LIFE
# -------------------------

func take_damage(amount: int) -> void:
	current_hp = max(current_hp - amount, 0)

func is_alive() -> bool:
	return current_hp > 0

# -------------------------
# STATS SYSTEM
# -------------------------

func get_modifier(stat_name: String) -> int:
	if not stats.has(stat_name):
		return 0
	return stats[stat_name]

func set_stat(stat_name: String, value: int) -> void:
	stats[stat_name] = value

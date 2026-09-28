extends Node
class_name CharacterStats

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")

# -------------------------
# BASIC INFO
# -------------------------
var character_name: String = "Unnamed"

signal hp_changed(current, max)
signal died
signal stats_changed
signal attack_changed(damage: int, interval: float)

# -------------------------
# HEALTH
# -------------------------
var max_hp: int = StatBalance.PLAYER_BASE_HP
var current_hp: int = StatBalance.PLAYER_BASE_HP

# -------------------------
# ATTACK (auto-combat hitbox)
# -------------------------
## Base = CharacterData values; current = base + in-run upgrades (PlayerStats).
var base_attack_damage: int = 3
var base_attack_interval: float = 1.0
var attack_damage: int = 3
var attack_interval: float = 1.0

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

func set_base_attack(damage: int, interval: float) -> void:
	base_attack_damage = damage
	base_attack_interval = interval
	set_attack(damage, interval)


func set_attack(damage: int, interval: float) -> void:
	attack_damage = damage
	attack_interval = interval
	attack_changed.emit(attack_damage, attack_interval)
	stats_changed.emit()


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

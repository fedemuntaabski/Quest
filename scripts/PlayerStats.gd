extends Node

signal stats_changed(stats: CharacterStats)
signal upgrades_changed(upgrades: Array)
signal player_died


var stats: CharacterStats = null

# BASE STATS (PERSISTENCIA)
var base_hp: int = 10
var base_str: int = 0
var base_mag: int = 0
var base_dex: int = 0

var active_upgrades: Array = []

func register(player_stats: CharacterStats) -> void:
	if player_stats == null:
		push_error("PlayerStats.register(): null CharacterStats")
		return

	stats = player_stats

	# conectar señales
	if not stats.died.is_connected(_on_stats_died):
		stats.died.connect(_on_stats_died)

	if not stats.stats_changed.is_connected(_on_stats_updated):
		stats.stats_changed.connect(_on_stats_updated)

	_apply_base_stats()
	_reapply_upgrades()

	stats_changed.emit(stats)

func _apply_base_stats() -> void:
	stats.max_hp = base_hp
	stats.current_hp = base_hp

	stats.strength = base_str
	stats.magic = base_mag
	stats.dexterity = base_dex

func _reapply_upgrades() -> void:
	for upg in active_upgrades:
		stats.apply_modifier(
			upg.get("stat_affected", ""),
			upg.get("value_change", 0)
		)

func apply_upgrade(upgrade: Dictionary) -> void:
	if stats == null:
		return

	active_upgrades.append(upgrade)

	stats.apply_modifier(
		upgrade.get("stat_affected", ""),
		upgrade.get("value_change", 0)
	)

	upgrades_changed.emit(active_upgrades)
	stats_changed.emit(stats)

func _on_stats_updated() -> void:
	stats_changed.emit(stats)

func _on_stats_died() -> void:
	player_died.emit()
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
const MAX_UPGRADE_LEVEL: int = 10
var upgrade_levels := {
	"hp": 0,
	"strength": 0,
	"magic": 0,
	"dexterity": 0
}

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
	_rebuild_upgrade_levels()
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

func apply_upgrade(upgrade: Dictionary) -> bool:
	if stats == null:
		return false

	var stat_key := str(upgrade.get("stat_affected", ""))
	if not upgrade_levels.has(stat_key):
		return false
	if not can_upgrade_stat(stat_key):
		return false

	active_upgrades.append(upgrade)
	upgrade_levels[stat_key] = int(upgrade_levels[stat_key]) + 1

	stats.apply_modifier(
		stat_key,
		upgrade.get("value_change", 0)
	)

	upgrades_changed.emit(active_upgrades)
	stats_changed.emit(stats)
	return true

func can_upgrade_stat(stat_key: String) -> bool:
	return int(upgrade_levels.get(stat_key, 0)) < MAX_UPGRADE_LEVEL

func get_upgrade_level(stat_key: String) -> int:
	return int(upgrade_levels.get(stat_key, 0))

func get_max_upgrade_level() -> int:
	return MAX_UPGRADE_LEVEL

func _rebuild_upgrade_levels() -> void:
	for key in upgrade_levels.keys():
		upgrade_levels[key] = 0

	for upg in active_upgrades:
		var stat_key := str(upg.get("stat_affected", ""))
		if upgrade_levels.has(stat_key):
			upgrade_levels[stat_key] = min(MAX_UPGRADE_LEVEL, int(upgrade_levels[stat_key]) + 1)

func _on_stats_updated() -> void:
	stats_changed.emit(stats)

func _on_stats_died() -> void:
	player_died.emit()
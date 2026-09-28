extends Node

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")
const CharacterDatabase = preload("res://scripts/core/stats/CharacterDatabase.gd")

signal stats_changed(stats: CharacterStats)
signal upgrades_changed(upgrades: Array)
signal player_died
## In-run (Ciencia) upgrade bought: stat_key in UpgradeConfig.STAT_KEYS.
signal run_upgrades_changed(stat_key: String, level: int)

const RUN_UPGRADE_CONFIG: UpgradeConfig = preload("res://resources/upgrades/run_upgrade_config.tres")


var stats: CharacterStats = null

# BASE STATS (PERSISTENCIA)
var base_hp: int = CharacterDatabase.get_default().base_hp

var active_upgrades: Array = []
var upgrade_levels := {
	"hp": 0
}

# IN-RUN UPGRADES (Ciencia, reset per run by Main._begin_new_run; survive floors
# because this autoload outlives Main2d and refresh_stats() re-applies them)
var run_upgrade_config: UpgradeConfig = RUN_UPGRADE_CONFIG
var run_upgrade_levels := {"hp": 0, "damage": 0, "attack_speed": 0}

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

	refresh_stats()

func refresh_stats() -> void:
	if stats == null:
		return

	var hp_state := StatBalance.clamp_player_hp(base_hp, base_hp)
	base_hp = int(hp_state.get("max_hp", base_hp))

	if stats.has_method("reset_modifiers"):
		stats.reset_modifiers()

	_apply_base_stats()
	_rebuild_upgrade_levels()
	_reapply_upgrades()
	for i in int(run_upgrade_levels["hp"]):
		stats.apply_modifier("hp", run_upgrade_config.hp_per_level)
	_apply_run_attack()

	stats_changed.emit(stats)

func _apply_base_stats() -> void:
	stats.max_hp = base_hp
	stats.current_hp = base_hp

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
	return int(upgrade_levels.get(stat_key, 0)) < StatBalance.MAX_UPGRADE_LEVEL

func get_upgrade_level(stat_key: String) -> int:
	return int(upgrade_levels.get(stat_key, 0))

func get_max_upgrade_level() -> int:
	return StatBalance.MAX_UPGRADE_LEVEL

func _rebuild_upgrade_levels() -> void:
	for key in upgrade_levels.keys():
		upgrade_levels[key] = 0

	for upg in active_upgrades:
		var stat_key := str(upg.get("stat_affected", ""))
		if upgrade_levels.has(stat_key):
			upgrade_levels[stat_key] = min(StatBalance.MAX_UPGRADE_LEVEL, int(upgrade_levels[stat_key]) + 1)

# ---------------- IN-RUN UPGRADES ----------------

func get_run_upgrade_level(stat_key: String) -> int:
	return int(run_upgrade_levels.get(stat_key, 0))


## 1 + every in-run upgrade bought (there is no XP system).
func get_hero_level() -> int:
	var total := 1
	for key in run_upgrade_levels:
		total += int(run_upgrade_levels[key])
	return total


## Row data for the "Mejoras" panel: level, current/next display values, cost,
## maxed (level cap, or the HP clamp would make the purchase a no-op),
## affordable (against ResourceManager).
func get_run_upgrade_preview(stat_key: String) -> Dictionary:
	var cfg := run_upgrade_config
	var level := get_run_upgrade_level(stat_key)
	var current: Variant = 0
	var next: Variant = 0
	if stats:
		match stat_key:
			"hp":
				current = stats.max_hp
				next = int(StatBalance.apply_hp_delta(stats.max_hp, stats.current_hp, cfg.hp_per_level)["max_hp"])
			"damage":
				current = stats.attack_damage
				next = cfg.damage_at(stats.base_attack_damage, level + 1)
			"attack_speed":
				current = stats.attack_interval
				next = cfg.interval_at(stats.base_attack_interval, level + 1)
	var cost := cfg.get_cost(level)
	var rm := ManagerLocator.get_resource_manager()
	return {
		"level": level,
		"max_level": cfg.max_level,
		"current": current,
		"next": next,
		"cost": cost,
		"cost_resource": cfg.cost_resource,
		"maxed": stats == null or cfg.is_maxed(level) or current == next,
		"affordable": rm != null and rm.get_resource(cfg.cost_resource) >= cost,
	}


## Spends the config's resource and applies one level. false = maxed/unaffordable.
func buy_run_upgrade(stat_key: String) -> bool:
	if not run_upgrade_levels.has(stat_key):
		return false
	var preview := get_run_upgrade_preview(stat_key)
	if preview["maxed"]:
		return false
	var rm := ManagerLocator.get_resource_manager()
	if rm == null or not rm.spend_resource(run_upgrade_config.cost_resource, int(preview["cost"])):
		return false

	run_upgrade_levels[stat_key] = int(run_upgrade_levels[stat_key]) + 1
	if stat_key == "hp":
		stats.apply_modifier("hp", run_upgrade_config.hp_per_level)
	else:
		_apply_run_attack()
	QuestLogger.info(QuestLogger.Category.UI, "Run upgrade '%s' -> level %d." % [stat_key, run_upgrade_levels[stat_key]])
	run_upgrades_changed.emit(stat_key, int(run_upgrade_levels[stat_key]))
	stats_changed.emit(stats)
	return true


func reset_run_upgrades() -> void:
	for key in run_upgrade_levels:
		run_upgrade_levels[key] = 0


func _apply_run_attack() -> void:
	var cfg := run_upgrade_config
	stats.set_attack(
		cfg.damage_at(stats.base_attack_damage, get_run_upgrade_level("damage")),
		cfg.interval_at(stats.base_attack_interval, get_run_upgrade_level("attack_speed"))
	)


func _on_stats_updated() -> void:
	stats_changed.emit(stats)

func _on_stats_died() -> void:
	player_died.emit()
extends Node

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")
const CharacterDatabase = preload("res://scripts/core/stats/CharacterDatabase.gd")

signal stats_changed(stats: CharacterStats)
signal upgrades_changed(upgrades: Array)
signal player_died
## Hero leveled up (in-run, paid in Comida). Since session 7 every level
## raises all UpgradeConfig.STAT_KEYS together: stat_key is always "level" and
## `level` is the number of levels bought this run (hero level - 1).
signal run_upgrades_changed(stat_key: String, level: int)

const RUN_UPGRADE_CONFIG: UpgradeConfig = preload("res://resources/upgrades/run_upgrade_config.tres")


var stats: CharacterStats = null

# BASE STATS (PERSISTENCIA)
var base_hp: int = CharacterDatabase.get_default().base_hp

var active_upgrades: Array = []
var upgrade_levels := {
	"hp": 0
}

# IN-RUN HERO LEVEL (Comida, reset per run by Main._begin_new_run; survives
# floors because this autoload outlives Main2d and refresh_stats() re-applies it).
# ponytail: one level for the one hero; with several heroes this becomes a
# per-hero dict (CharacterData id → levels) and the API takes the CharacterStats.
var run_upgrade_config: UpgradeConfig = RUN_UPGRADE_CONFIG
## Levels bought this run (hero level = 1 + run_level).
var run_level: int = 0
## Read-only compat view (session 6 per-stat levels): every stat == run_level.
var run_upgrade_levels: Dictionary:
	get:
		var levels := {}
		for key in UpgradeConfig.STAT_KEYS:
			levels[key] = run_level
		return levels

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
	for i in run_level:
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

# ---------------- IN-RUN HERO LEVEL ----------------

## Compat (session 6): all stats share the hero's run level now.
func get_run_upgrade_level(stat_key: String) -> int:
	return run_level if UpgradeConfig.STAT_KEYS.has(stat_key) else 0


## 1 + levels bought this run (there is no XP system).
func get_hero_level() -> int:
	return 1 + run_level


## Popup data for "Subir de nivel": level, next level, cost (Comida), maxed,
## affordable, and one row per stat with its current → next value.
func get_level_up_preview() -> Dictionary:
	var cfg := run_upgrade_config
	var cost := cfg.get_cost(run_level)
	var rm := ManagerLocator.get_resource_manager()
	var rows: Array[Dictionary] = []
	for key in UpgradeConfig.STAT_KEYS:
		var row := get_run_upgrade_preview(key)
		rows.append({"key": key, "label": UpgradeConfig.LABELS[key], "current": row["current"], "next": row["next"]})
	return {
		"level": get_hero_level(),
		"next_level": get_hero_level() + 1,
		"max_level": 1 + cfg.max_level,
		"cost": cost,
		"cost_resource": cfg.cost_resource,
		"maxed": stats == null or cfg.is_maxed(run_level),
		"affordable": rm != null and rm.get_resource(cfg.cost_resource) >= cost,
		"rows": rows,
	}


## Compat (session 6) row for one stat: the values a level-up would give it.
func get_run_upgrade_preview(stat_key: String) -> Dictionary:
	var cfg := run_upgrade_config
	var current: Variant = 0
	var next: Variant = 0
	if stats:
		match stat_key:
			"hp":
				current = stats.max_hp
				next = int(StatBalance.apply_hp_delta(stats.max_hp, stats.current_hp, cfg.hp_per_level)["max_hp"])
			"damage":
				current = stats.attack_damage
				next = cfg.damage_at(stats.base_attack_damage, run_level + 1)
			"attack_speed":
				current = stats.attack_interval
				next = cfg.interval_at(stats.base_attack_interval, run_level + 1)
	var cost := cfg.get_cost(run_level)
	var rm := ManagerLocator.get_resource_manager()
	return {
		"level": run_level,
		"max_level": cfg.max_level,
		"current": current,
		"next": next,
		"cost": cost,
		"cost_resource": cfg.cost_resource,
		"maxed": stats == null or cfg.is_maxed(run_level),
		"affordable": rm != null and rm.get_resource(cfg.cost_resource) >= cost,
	}


## Spends Comida and raises every stat one level. false = maxed/unaffordable.
func level_up_hero() -> bool:
	if stats == null or run_upgrade_config.is_maxed(run_level):
		return false
	var rm := ManagerLocator.get_resource_manager()
	if rm == null or not rm.spend_resource(run_upgrade_config.cost_resource, run_upgrade_config.get_cost(run_level)):
		return false

	run_level += 1
	stats.apply_modifier("hp", run_upgrade_config.hp_per_level)
	_apply_run_attack()
	QuestLogger.info(QuestLogger.Category.UI, "Hero level up -> %d." % get_hero_level())
	run_upgrades_changed.emit("level", run_level)
	stats_changed.emit(stats)
	return true


## Compat (session 6): any stat key now levels the whole hero up.
func buy_run_upgrade(stat_key: String) -> bool:
	return UpgradeConfig.STAT_KEYS.has(stat_key) and level_up_hero()


func reset_run_upgrades() -> void:
	run_level = 0


func _apply_run_attack() -> void:
	var cfg := run_upgrade_config
	stats.set_attack(
		cfg.damage_at(stats.base_attack_damage, run_level),
		cfg.interval_at(stats.base_attack_interval, run_level)
	)


func _on_stats_updated() -> void:
	stats_changed.emit(stats)

func _on_stats_died() -> void:
	player_died.emit()
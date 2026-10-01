extends Node

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")
const CharacterDatabase = preload("res://scripts/core/stats/CharacterDatabase.gd")

signal stats_changed(stats: CharacterStats)
## Any hero died. Session 12: one hero down ends the run (see NOTES_SESSION.md).
signal player_died
## Objetos hallados en cofres esta partida (solo registro: no hay sistema de equipo).
signal found_items_changed
## A hero leveled up (in-run, paid in Comida). Since session 7 every level
## raises all UpgradeConfig.STAT_KEYS together: stat_key is always "level" and
## `level` is the number of levels that hero bought this run (hero level - 1).
signal run_upgrades_changed(stat_key: String, level: int, hero_id: String)

const RUN_UPGRADE_CONFIG: UpgradeConfig = preload("res://resources/upgrades/run_upgrade_config.tres")


# BASE STATS (PERSISTENCIA) — account-wide: every hero starts from base_hp.
var base_hp: int = CharacterDatabase.get_default().base_hp

# PARTY (session 12). hero_id = CharacterData.character_id (CharacterStats.hero_id).
## hero_id → live CharacterStats, in party order. Rebuilt every floor
## (Main2d: clear_party() + one register() per spawned Player).
var heroes: Dictionary = {}
## The primary selected hero (SelectionManager owns the selection); falls back
## to the first registered hero (bare CharacterStats in tests, floor start).
var active_hero_id: String:
	get:
		var selection := ManagerLocator.get_selection_manager()
		var id: String = selection.get_primary_id() if selection else ""
		if id != "" and heroes.has(id):
			return id
		for first_id: String in heroes:
			return first_id
		return ""

# IN-RUN HERO LEVELS (Comida, reset per run by Main._begin_new_run; survive
# floors because this autoload outlives Main2d and register() re-applies them).
var found_items: Array[ItemData] = []
var run_upgrade_config: UpgradeConfig = RUN_UPGRADE_CONFIG
## hero_id → levels bought this run (hero level = 1 + levels).
var run_levels: Dictionary = {}

## Compat (single-hero API): the active hero's CharacterStats.
var stats: CharacterStats:
	get:
		return get_hero_stats()
## Compat: levels the active hero bought this run.
var run_level: int:
	get:
		return _levels_of(active_hero_id)
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

	# First time this CharacterStats registers (re-registering must not double-connect).
	if not player_stats.died.is_connected(_on_stats_died):
		player_stats.died.connect(_on_stats_died)
		player_stats.died.connect(_on_hero_died.bind(player_stats.hero_id))
		player_stats.stats_changed.connect(_on_stats_updated.bind(player_stats))

	heroes[player_stats.hero_id] = player_stats
	_refresh_hero(player_stats)

func refresh_stats() -> void:
	for s in get_all_stats():
		_refresh_hero(s)

## Base HP + this hero's run levels onto its CharacterStats.
func _refresh_hero(s: CharacterStats) -> void:
	var hp_state := StatBalance.clamp_player_hp(base_hp, base_hp)
	base_hp = int(hp_state.get("max_hp", base_hp))

	s.reset_modifiers()
	_apply_base_stats(s)
	var levels := _levels_of(s.hero_id)
	for i in levels:
		s.apply_modifier("hp", run_upgrade_config.hp_per_level)
	_apply_run_attack(s, levels)

	stats_changed.emit(s)

func _apply_base_stats(s: CharacterStats) -> void:
	s.max_hp = s.base_hp
	s.current_hp = s.base_hp

# ---------------- PARTY ----------------

## `hero_id` "" = the active hero (every hero_id parameter below works this way).
func get_hero_stats(hero_id: String = "") -> CharacterStats:
	var s: Variant = heroes.get(_resolve(hero_id))
	return s if is_instance_valid(s) else null


## Live heroes' CharacterStats, in party order.
func get_all_stats() -> Array[CharacterStats]:
	var out: Array[CharacterStats] = []
	for s in heroes.values():
		if is_instance_valid(s):
			out.append(s)
	return out


func get_hero_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in heroes:
		if is_instance_valid(heroes[id]):
			out.append(id)
	return out


## Compat: select only this hero (SelectionManager.select_only). false if no
## live hero has that id.
func select_hero(hero_id: String) -> bool:
	var selection := ManagerLocator.get_selection_manager()
	return selection != null and selection.select_only(hero_id)


## Tab: next hero in party order, wrapping. false with fewer than 2 heroes.
func cycle_active_hero() -> bool:
	var ids := get_hero_ids()
	if ids.size() < 2:
		return false
	return select_hero(ids[(ids.find(active_hero_id) + 1) % ids.size()])


## New floor (Main2d, before spawning): drops last floor's CharacterStats.
## Run levels stay (reset_run_upgrades is the per-run reset).
func clear_party() -> void:
	heroes.clear()


func _resolve(hero_id: String) -> String:
	return hero_id if hero_id != "" else active_hero_id


func _levels_of(hero_id: String) -> int:
	return int(run_levels.get(hero_id, 0))

# ---------------- IN-RUN HERO LEVEL ----------------

## Compat (session 6): all stats share the hero's run level now.
func get_run_upgrade_level(stat_key: String, hero_id: String = "") -> int:
	return _levels_of(_resolve(hero_id)) if UpgradeConfig.STAT_KEYS.has(stat_key) else 0


## 1 + levels bought this run (there is no XP system).
func get_hero_level(hero_id: String = "") -> int:
	return 1 + _levels_of(_resolve(hero_id))


## Popup data for "Subir de nivel": level, next level, cost (Comida), maxed,
## affordable, and one row per stat with its current → next value.
func get_level_up_preview(hero_id: String = "") -> Dictionary:
	var id := _resolve(hero_id)
	var cfg := run_upgrade_config
	var levels := _levels_of(id)
	var cost := cfg.get_cost(levels)
	var rm := ManagerLocator.get_resource_manager()
	var rows: Array[Dictionary] = []
	for key in UpgradeConfig.STAT_KEYS:
		var row := get_run_upgrade_preview(key, id)
		rows.append({"key": key, "label": UpgradeConfig.LABELS[key], "current": row["current"], "next": row["next"]})
	return {
		"level": 1 + levels,
		"next_level": 2 + levels,
		"max_level": 1 + cfg.max_level,
		"cost": cost,
		"cost_resource": cfg.cost_resource,
		"maxed": get_hero_stats(id) == null or cfg.is_maxed(levels),
		"affordable": rm != null and rm.get_resource(cfg.cost_resource) >= cost,
		"rows": rows,
	}


## Compat (session 6) row for one stat: the values a level-up would give it.
func get_run_upgrade_preview(stat_key: String, hero_id: String = "") -> Dictionary:
	var id := _resolve(hero_id)
	var s := get_hero_stats(id)
	var levels := _levels_of(id)
	var cfg := run_upgrade_config
	var current: Variant = 0
	var next: Variant = 0
	if s:
		match stat_key:
			"hp":
				current = s.max_hp
				next = int(StatBalance.apply_hp_delta(s.max_hp, s.current_hp, cfg.hp_per_level)["max_hp"])
			"damage":
				current = s.attack_damage
				next = cfg.damage_at(s.base_attack_damage, levels + 1)
			"attack_speed":
				current = s.attack_interval
				next = cfg.interval_at(s.base_attack_interval, levels + 1)
	var cost := cfg.get_cost(levels)
	var rm := ManagerLocator.get_resource_manager()
	return {
		"level": levels,
		"max_level": cfg.max_level,
		"current": current,
		"next": next,
		"cost": cost,
		"cost_resource": cfg.cost_resource,
		"maxed": s == null or cfg.is_maxed(levels),
		"affordable": rm != null and rm.get_resource(cfg.cost_resource) >= cost,
	}


## Spends Comida and raises every stat of that hero one level.
## false = no such hero, maxed or unaffordable.
func level_up_hero(hero_id: String = "") -> bool:
	var id := _resolve(hero_id)
	var s := get_hero_stats(id)
	var levels := _levels_of(id)
	if s == null or run_upgrade_config.is_maxed(levels):
		return false
	var rm := ManagerLocator.get_resource_manager()
	if rm == null or not rm.spend_resource(run_upgrade_config.cost_resource, run_upgrade_config.get_cost(levels)):
		return false

	levels += 1
	run_levels[id] = levels
	s.apply_modifier("hp", run_upgrade_config.hp_per_level)
	_apply_run_attack(s, levels)
	QuestLogger.info(QuestLogger.Category.UI, "Hero '%s' level up -> %d." % [id, 1 + levels])
	run_upgrades_changed.emit("level", levels, id)
	stats_changed.emit(s)
	return true


## Compat (session 6): any stat key now levels the whole hero up.
func buy_run_upgrade(stat_key: String, hero_id: String = "") -> bool:
	return UpgradeConfig.STAT_KEYS.has(stat_key) and level_up_hero(hero_id)


## New run: every hero back to level 1.
func reset_run_upgrades() -> void:
	run_levels.clear()


func _apply_run_attack(s: CharacterStats, levels: int) -> void:
	var cfg := run_upgrade_config
	s.set_attack(
		cfg.damage_at(s.base_attack_damage, levels),
		cfg.interval_at(s.base_attack_interval, levels)
	)


func _on_stats_updated(s: CharacterStats) -> void:
	stats_changed.emit(s)

func _on_hero_died(hero_id: String) -> void:
	var selection := ManagerLocator.get_selection_manager()
	if selection:
		selection.remove_hero(hero_id)


func _on_stats_died() -> void:
	player_died.emit()


func add_found_item(item: ItemData) -> void:
	if item == null:
		return
	found_items.append(item)
	found_items_changed.emit()


func clear_found_items() -> void:
	found_items.clear()
	found_items_changed.emit()

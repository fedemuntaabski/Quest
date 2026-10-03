extends Node

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")
const CharacterDatabase = preload("res://scripts/core/stats/CharacterDatabase.gd")

signal stats_changed(stats: CharacterStats)
## Any hero died. Session 12: one hero down ends the run (see NOTES_SESSION.md).
signal player_died
## The party stash changed (chest found, equipped/unequipped): CharacterPopup "Hallazgos"
## (alias of PartyInventory.stash, retired by the equipment UI).
signal found_items_changed
## A hero leveled up (in-run, paid in Comida). Since session 7 every level
## raises all UpgradeConfig.STAT_KEYS together: stat_key is always "level" and
## `level` is the number of levels that hero bought this run (hero level - 1).
signal run_upgrades_changed(stat_key: String, level: int, hero_id: String)
## A hero picked a class perk (HeroPerk, 1-of-2 at hero level 3 and 5).
signal perk_chosen(hero_id: String, perk_id: StringName)

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
## Read-only view of the party stash (PartyInventory owns the items).
var found_items: Array[ItemData]:
	get:
		var inventory := ManagerLocator.get_party_inventory()
		return inventory.stash_items() if inventory else ([] as Array[ItemData])
var run_upgrade_config: UpgradeConfig = RUN_UPGRADE_CONFIG
## hero_id → levels bought this run (hero level = 1 + levels).
var run_levels: Dictionary = {}
## hero_id -> ids of the class perks picked this run (reset with the levels).
var run_perks: Dictionary = {}
## hero_id -> HP the third layer (perks, later equipment) currently adds to that
## hero, so a change only applies the difference.
var _applied_hp_bonus: Dictionary = {}

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

func _ready() -> void:
	# PartyInventory is listed before this autoload in project.godot. Not through
	# ManagerLocator: the main loop is not set yet while autoloads get their _ready.
	var inventory := get_node_or_null("/root/PartyInventory") as PartyInventory
	if inventory:
		inventory.stash_changed.connect(func() -> void: found_items_changed.emit())
		inventory.equipment_changed.connect(func(hero_id: String, _slot: ItemData.Slot, _item: ItemData) -> void: _rebonus(hero_id))


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
		s.apply_modifier("hp", _config_for(s.hero_id).hp_per_level)
	var bonus := _bonus(s.hero_id)
	if int(bonus["hp"]) != 0:
		s.apply_modifier("hp", int(bonus["hp"]))
	_applied_hp_bonus[s.hero_id] = int(bonus["hp"])
	_apply_run_attack(s, levels)

	stats_changed.emit(s)

## The third layer changed (perk picked): applies only the HP difference, then
## re-derives attack damage/interval/range from base -> level -> bonus.
## Never kills: shrinking max HP leaves at least 1 HP.
func _rebonus(hero_id: String) -> void:
	var s := get_hero_stats(hero_id)
	if s == null:
		return
	var delta := int(_bonus(hero_id)["hp"]) - int(_applied_hp_bonus.get(hero_id, 0))
	if delta != 0:
		var was_alive := s.is_alive()
		s.apply_modifier("hp", delta)
		if was_alive and s.current_hp < 1:
			s.current_hp = 1
			s.hp_changed.emit(s.current_hp, s.max_hp)
		_applied_hp_bonus[hero_id] += delta
	_apply_run_attack(s, _levels_of(hero_id))
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
	var cfg := _config_for(id)
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
	var cfg := _config_for(id)
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
	var cfg := _config_for(id)
	if s == null or cfg.is_maxed(levels):
		return false
	var rm := ManagerLocator.get_resource_manager()
	if rm == null or not rm.spend_resource(cfg.cost_resource, cfg.get_cost(levels)):
		return false

	levels += 1
	run_levels[id] = levels
	s.apply_modifier("hp", cfg.hp_per_level)
	_apply_run_attack(s, levels)
	QuestLogger.info(QuestLogger.Category.UI, "Hero '%s' level up -> %d." % [id, 1 + levels])
	run_upgrades_changed.emit("level", levels, id)
	stats_changed.emit(s)
	return true


## Comida to fully heal that hero (0 = nothing to heal / unknown hero).
func get_heal_cost(hero_id: String = "") -> int:
	var s := get_hero_stats(_resolve(hero_id))
	return 0 if s == null or not s.is_alive() else _config_for(_resolve(hero_id)).heal_cost(s.max_hp - s.current_hp)


## Spends Comida to restore that hero's missing HP. false = nothing to heal or short.
func heal_hero(hero_id: String = "") -> bool:
	var id := _resolve(hero_id)
	var cost := get_heal_cost(id)
	var rm := ManagerLocator.get_resource_manager()
	if cost <= 0 or rm == null or not rm.spend_resource(_config_for(id).cost_resource, cost):
		return false
	var s := get_hero_stats(id)
	s.heal(s.max_hp - s.current_hp)
	return true


## Compat (session 6): any stat key now levels the whole hero up.
func buy_run_upgrade(stat_key: String, hero_id: String = "") -> bool:
	return UpgradeConfig.STAT_KEYS.has(stat_key) and level_up_hero(hero_id)


## New run: every hero back to level 1.
func reset_run_upgrades() -> void:
	run_levels.clear()
	run_perks.clear()
	_applied_hp_bonus.clear()


## base -> level -> bonus (perks, later equipment): the bonus is added after the
## level curve so buying a level never overwrites it.
func _apply_run_attack(s: CharacterStats, levels: int) -> void:
	var cfg := _config_for(s.hero_id)
	var bonus := _bonus(s.hero_id)
	s.set_attack(
		cfg.damage_at(s.base_attack_damage, levels) + int(bonus["attack_damage"]),
		maxf(cfg.min_attack_interval, cfg.interval_at(s.base_attack_interval, levels) + float(bonus["attack_interval"]))
	)
	s.set_attack_range(s.base_attack_range + float(bonus["attack_range"]))


## The hero's own level curve (CharacterData.upgrade_override) or the global one.
func _config_for(hero_id: String) -> UpgradeConfig:
	var data := _data_of(hero_id)
	return data.upgrade_override if data and data.upgrade_override else run_upgrade_config


## CharacterData of a registered hero id; null for bare test stats (hero_id "").
func _data_of(hero_id: String) -> CharacterData:
	for data in CharacterDatabase.get_all():
		if data.character_id == hero_id and hero_id != "":
			return data
	return null


# ---------------- CLASS PERKS (session impl-6) ----------------

## Sum of a mod key over the perks this hero picked (HeroPerk.MOD_KEYS).
func perk_mod(hero_id: String, key: String) -> float:
	var total := 0.0
	for perk in get_perks_of(_resolve(hero_id)):
		total += float(perk.mods.get(key, 0.0))
	return total


## Perks the hero picked this run, in the order they were picked.
func get_perks_of(hero_id: String) -> Array[HeroPerk]:
	var out: Array[HeroPerk] = []
	var data := _data_of(_resolve(hero_id))
	if data == null:
		return out
	for perk_id: StringName in run_perks.get(_resolve(hero_id), []):
		for perk in data.perks:
			if perk.id == perk_id:
				out.append(perk)
	return out


## The two perks to choose from right now (lowest unlocked level whose group has no pick), [] if none.
func get_pending_perk_choices(hero_id: String = "") -> Array[HeroPerk]:
	var id := _resolve(hero_id)
	var out: Array[HeroPerk] = []
	var data := _data_of(id)
	if data == null:
		return out
	var level := get_hero_level(id)
	var picked_groups := {}
	for perk in get_perks_of(id):
		picked_groups[perk.exclusive_group] = true
	var best_level := 0
	for perk in data.perks:
		if perk.unlock_level <= level and not picked_groups.has(perk.exclusive_group) and (best_level == 0 or perk.unlock_level < best_level):
			best_level = perk.unlock_level
	if best_level == 0:
		return out
	for perk in data.perks:
		if perk.unlock_level == best_level and not picked_groups.has(perk.exclusive_group):
			out.append(perk)
	return out


func has_pending_perk(hero_id: String = "") -> bool:
	return not get_pending_perk_choices(hero_id).is_empty()


## Picks one of get_pending_perk_choices(); false (nothing changes) if it is not on offer.
func choose_perk(hero_id: String, perk_id: StringName) -> bool:
	var id := _resolve(hero_id)
	var chosen: HeroPerk = null
	for perk in get_pending_perk_choices(id):
		if perk.id == perk_id:
			chosen = perk
	if chosen == null:
		return false
	var picked: Array = run_perks.get(id, [])
	picked.append(perk_id)
	run_perks[id] = picked
	_rebonus(id)
	QuestLogger.info(QuestLogger.Category.UI, "Hero '%s' chose perk '%s'." % [id, perk_id])
	perk_chosen.emit(id, perk_id)
	return true


## Third stat layer for a hero: class perks + equipped items (PartyInventory).
## Keys: hp (int), attack_damage (int), attack_interval (s, negative = faster), attack_range (px).
func _bonus(hero_id: String) -> Dictionary:
	var bonus := {"hp": 0, "attack_damage": 0, "attack_interval": 0.0, "attack_range": 0.0}
	for perk in get_perks_of(hero_id):
		bonus["hp"] += int(perk.mods.get("hp", 0))
		bonus["attack_damage"] += int(perk.mods.get("attack_damage", 0))
		bonus["attack_interval"] += float(perk.mods.get("attack_interval", 0.0))
		bonus["attack_range"] += float(perk.mods.get("attack_range", 0.0))
	var inventory := ManagerLocator.get_party_inventory()
	if inventory and hero_id != "":
		var equipment := inventory.get_equipment_bonus(hero_id)
		for key: String in bonus:
			bonus[key] += equipment[key]
	return bonus


## What perks + equipment add to this hero right now (CharacterPopup shows "base + nivel + extras").
func get_bonus(hero_id: String = "") -> Dictionary:
	return _bonus(_resolve(hero_id))


func _on_stats_updated(s: CharacterStats) -> void:
	stats_changed.emit(s)

func _on_hero_died(hero_id: String) -> void:
	var selection := ManagerLocator.get_selection_manager()
	if selection:
		selection.remove_hero(hero_id)


func _on_stats_died() -> void:
	player_died.emit()


## Compat: puts the item in the party stash.
func add_found_item(item: ItemData) -> void:
	var inventory := ManagerLocator.get_party_inventory()
	if inventory:
		inventory.add_item(item)


## Compat: empties the stash and the loadouts (new run).
func clear_found_items() -> void:
	var inventory := ManagerLocator.get_party_inventory()
	if inventory:
		inventory.reset()

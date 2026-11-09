extends RefCounted
class_name BalanceSim

## BalanceSim: pure-math duel / wave / Relic model over the real data (.tres
## heroes, EnemyTypes, FloorConfig, UpgradeConfig) and the real formulas
## (Enemy.resolved_*, FloorConfig multipliers, UpgradeConfig curves). No scene,
## no randomness: tools/balance_sim.gd exports it as CSV, tests/test_balance.gd
## asserts the targets on it. Model (documented in docs/BALANCE.md):
##  - heroes-9: the hero hits ONE enemy (the nearest) each `interval` (free-running
##    Timer: the first tick lands uniformly within one interval, so the first enemy
##    is exposed for (hits - 0.5) * interval on average, each next one `hits *
##    interval` longer); enemies hit on contact every CONTACT_HIT_INTERVAL. A RANGED
##    hero (Mage) shoots while the wave walks in: every enemy's exposure shrinks by
##    the approach time (range - CONTACT_PX) / speed. Damage taken is the
##    expectation (no rounding to whole ticks);
##  - an encounter = the floor's invasion wave at turn WAVE_TURN, all arriving at
##    once, split over the starting party (PARTY_SIZE heroes in the room: each
##    hero faces wave / PARTY_SIZE enemies on average, a fraction weighting the last);
##  - hero level on floor f = f - 1 (one level-up bought per floor).

const HERO_IDS: Array[String] = ["warrior", "mage", "rogue", "tank"]
const FLOORS := 5
const WAVE_TURN := 5
const LAYOUT_SEEDS := 30
const FLOOR_CONFIG_PATH := "res://resources/floors/default_floor_config.tres"
const UPGRADE_CONFIG_PATH := "res://resources/upgrades/run_upgrade_config.tres"
## Sapper/raider hit-the-Relic timer (Enemy.attack_speed default).
const RELIC_TICK_SEC := 1.0
## ResourceManager.reset_resources() default embers at the start of a run.
const RESET_EMBERS := 20
## Distance (px) at which an enemy's contact hitbox reaches a hero (radius ~24 + reach).
const CONTACT_PX := 40.0
## progresion-10: difficulty applied over the run curve by enemy_stats (null = Normal).
## Set by difficulty_rows() while it runs; every other table stays on Normal.
static var difficulty: DifficultyLevel
## calidad-13: human players (1-4) applied by enemy_stats / encounter_loss through
## PlayerScaling; 1 = every table except scaling_rows().
static var players: int = 1
## Heroes in the party per player count (NetSession.heroes_per_player: 2 alone, 1 each in co-op).
const PARTY_BY_PLAYERS := [2, 2, 3, 4]
## Party used for the boss time-to-kill (the two heroes picked by default).
const BOSS_PARTY: Array[String] = ["warrior", "mage"]


static func floor_config() -> FloorConfig:
	return load(FLOOR_CONFIG_PATH) as FloorConfig


static func upgrade_config() -> UpgradeConfig:
	return load(UPGRADE_CONFIG_PATH) as UpgradeConfig


static func hero_data(hero_id: String) -> CharacterData:
	return load("res://resources/characters/%s.tres" % hero_id) as CharacterData


## What PlayerStats applies: base + per-level bonuses (+ passives, see passive_*).
static func hero_stats(hero_id: String, level: int) -> Dictionary:
	var data := hero_data(hero_id)
	var up := data.upgrade_override if data.upgrade_override else upgrade_config()  # PlayerStats._config_for
	var damage := up.damage_at(data.attack_damage, level)
	var interval := up.interval_at(data.attack_interval, level)
	var hp := data.base_hp + up.hp_per_level * level
	var reduction := damage_reduction_pct(data)
	var dps := damage / interval
	var ehp := hp / maxf(1.0 - reduction, 0.01)
	var active := data.active
	var active_dps := dps
	var active_ehp := ehp
	if active:
		var uptime := minf(active.duration / maxf(active.cooldown, 0.001), 1.0)
		match active.effect:
			AbilityData.Effect.TEAM_ATTACK_BUFF:
				active_dps = dps * (1.0 + active.value * uptime)
			AbilityData.Effect.BURST_STRIKE:
				active_dps = dps + damage * active.value / active.cooldown
			AbilityData.Effect.TEAM_SHIELD:
				active_ehp = ehp / (1.0 - active.value * uptime)
	return {
		"hero": hero_id, "level": level, "hp": hp, "damage": damage, "interval": interval,
		"dps": dps, "range": data.attack_range,
		"ranged": data.attack_style == CharacterData.AttackStyle.RANGED,
		"speed": MoveAction.DEFAULT_SPEED_PX * data.move_speed_mult,
		"reduction_pct": reduction,
		"ehp": ehp,
		"active_dps": active_dps, "active_ehp": active_ehp,
	}


## Always-on passive reduction (Piel de Hierro). Position-dependent ones
## (Muro Viviente, only near the Relic) are not counted: conservative.
static func damage_reduction_pct(data: CharacterData) -> float:
	if data.passive and data.passive.effect == AbilityData.Effect.DAMAGE_REDUCTION_PCT:
		return data.passive.value
	return 0.0


## Enemy numbers after floor + type multipliers, exactly as Enemy.configure() applies them.
static func enemy_stats(type: EnemyType, floor_index: int) -> Dictionary:
	var cfg := floor_config()
	var scaling := PlayerScaling.get_default()
	var hp_mult := cfg.enemy_hp_multiplier(floor_index) * type.hp_mult * (difficulty.hp_mult if difficulty else 1.0) * scaling.hp(players)
	var dmg_mult := cfg.enemy_damage_multiplier(floor_index) * type.damage_mult * (difficulty.damage_mult if difficulty else 1.0) * scaling.damage(players)
	return {
		"enemy": type.id, "floor": floor_index, "role": "raider" if type.role == EnemyType.Role.RAIDER else "hunter",
		"hp": maxi(1, roundi(Enemy.resolved_hp(type) * hp_mult)),
		"contact": maxi(1, roundi(Enemy.resolved_contact_damage(type) * dmg_mult)),
		"relic": maxi(1, roundi(type.damage_vs_relic * dmg_mult)) if type.damage_vs_relic > 0 else 0,
		"building": maxi(1, roundi(Enemy.resolved_building_damage(type) * dmg_mult)),
		"speed": Enemy.resolved_speed(type) * type.speed_mult,
	}


static func pool_types(floor_index: int) -> Array[EnemyType]:
	var pool := floor_config().enemy_pool(floor_index)
	return pool.types if pool else ([] as Array[EnemyType])


static func wave_size(floor_index: int) -> int:
	return floor_config().door_roll.enemy_count(WAVE_TURN, floor_index)


## Hero (level) vs one enemy of `floor_index`: hits/time to kill it, time to be killed by it.
static func duel(hero_id: String, level: int, type: EnemyType, floor_index: int) -> Dictionary:
	var hero := hero_stats(hero_id, level)
	var enemy := enemy_stats(type, floor_index)
	var hits := ceili(float(enemy["hp"]) / float(hero["damage"]))
	var ttk_enemy := hits * float(hero["interval"])
	var hit := maxi(1, roundi(int(enemy["contact"]) * (1.0 - float(hero["reduction_pct"]))))
	var ttk_hero := ceili(float(hero["hp"]) / float(hit)) * Enemy.CONTACT_HIT_INTERVAL
	var exposure := (hits - 0.5) * float(hero["interval"])
	return {
		"hero": hero_id, "level": level, "enemy": type.id, "floor": floor_index,
		"enemy_hp": enemy["hp"], "hero_dmg": hero["damage"], "hits_to_kill": hits,
		"ttk_enemy_s": ttk_enemy, "ttk_hero_s": ttk_hero,
		"enemy_dps": float(hit) / Enemy.CONTACT_HIT_INTERVAL, "hero_dps": hero["dps"],
		"exposure_s": exposure,
		"hp_lost": hit * exposure / Enemy.CONTACT_HIT_INTERVAL,
		"hit_taken": hit,
	}


## Fraction of the hero's max HP lost to its share of the wave, killed one by one
## (single target): enemy i stays (hits - 0.5 + (i - 1) * hits) * interval, minus the
## approach a ranged hero shoots through.
static func encounter_loss(hero_id: String, level: int, type: EnemyType, floor_index: int) -> float:
	var d := duel(hero_id, level, type, floor_index)
	var hero := hero_stats(hero_id, level)
	var enemy := enemy_stats(type, floor_index)
	var approach := approach_sec(hero, float(enemy["speed"]))
	var per_kill := int(d["hits_to_kill"]) * float(hero["interval"])
	var share := float(PlayerScaling.get_default().wave(wave_size(floor_index), players)) / party_size()
	var exposure := 0.0
	for i in ceili(share):
		var weight := minf(share - i, 1.0)
		exposure += weight * maxf(float(d["exposure_s"]) + i * per_kill - approach, 0.0)
	return int(d["hit_taken"]) * exposure / Enemy.CONTACT_HIT_INTERVAL / float(hero["hp"])


## Seconds a ranged hero shoots before the enemy reaches contact (0 for melee).
static func approach_sec(hero: Dictionary, enemy_speed: float) -> float:
	if not hero.get("ranged", false):
		return 0.0
	return maxf(float(hero["range"]) - CONTACT_PX, 0.0) / maxf(enemy_speed, 1.0)


## Weighted mean of encounter_loss over the floor's pool.
static func pool_encounter_loss(hero_id: String, level: int, floor_index: int) -> float:
	var pool := floor_config().enemy_pool(floor_index)
	if pool == null:
		return 0.0
	var total := 0.0
	var loss := 0.0
	for i in pool.types.size():
		var w := pool.weight_of(i)
		total += w
		loss += w * encounter_loss(hero_id, level, pool.types[i], floor_index)
	return loss / maxf(total, 0.001)


static func encounter_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for hero_id in HERO_IDS:
		for f in range(1, FLOORS + 1):
			rows.append({
				"hero": hero_id, "floor": f, "level": f - 1, "wave": wave_size(f),
				"hp": hero_stats(hero_id, f - 1)["hp"],
				"loss_pct": snappedf(pool_encounter_loss(hero_id, f - 1, f) * 100.0, 0.1),
			})
	return rows


## heroes-9 roles per floor (level = floor - 1), weighted over the floor's pool:
## ttk_s = mean seconds to kill one enemy (single target); ttd_1_s / ttd_3_s =
## seconds to fall to 1 / 3 enemies hitting at once (their hits already reduced by
## the always-on passive, duel()["enemy_dps"]);
## dps, hp, speed (px/s). The Tank must outlast everyone and kill slowest; the
## Rogue must be the most fragile, the fastest and hit hardest per second.
static func hero_matchup_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for f in range(1, FLOORS + 1):
		var pool := floor_config().enemy_pool(f)
		for hero_id in HERO_IDS:
			var hero := hero_stats(hero_id, f - 1)
			var ttk := 0.0
			var enemy_dps := 0.0
			var total := 0.0
			for i in pool.types.size():
				var w := pool.weight_of(i)
				var d := duel(hero_id, f - 1, pool.types[i], f)
				ttk += w * float(d["ttk_enemy_s"])
				enemy_dps += w * float(d["enemy_dps"])
				total += w
			ttk /= maxf(total, 0.001)
			enemy_dps /= maxf(total, 0.001)
			rows.append({
				"hero": hero_id, "floor": f, "level": f - 1, "hp": hero["hp"],
				"dps": snappedf(float(hero["dps"]), 0.01),
				"ttk_s": snappedf(ttk, 0.01),
				"ttd_1_s": snappedf(float(hero["hp"]) / maxf(enemy_dps, 0.001), 0.1),
				"ttd_3_s": snappedf(float(hero["hp"]) / maxf(enemy_dps * 3.0, 0.001), 0.1),
				"speed": hero["speed"],
				"ranged": hero["ranged"],
			})
	return rows


static func duel_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for f in range(1, FLOORS + 1):
		for type in pool_types(f):
			for hero_id in HERO_IDS:
				var d := duel(hero_id, f - 1, type, f)
				for key in ["ttk_enemy_s", "ttk_hero_s", "enemy_dps", "hero_dps", "exposure_s", "hp_lost"]:
					d[key] = snappedf(float(d[key]), 0.01)
				rows.append(d)
	return rows


static func hero_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for hero_id in HERO_IDS:
		for level in [0, 5]:
			var s := hero_stats(hero_id, level)
			for key in ["dps", "ehp", "active_dps", "active_ehp"]:
				s[key] = snappedf(float(s[key]), 0.01)
			rows.append(s)
	return rows


## Centers (px) are the room rect centers; a path = the chain of entry corridors
## up to the start room (a tree, so it is the only way for a raider).
static func _arrival_lengths(layout: MapLayout) -> Array[float]:
	var lengths: Array[float] = []
	var cell := float(ArtConfig.CELL_PX)
	for room in layout.rooms:
		if room.is_start:
			continue
		var length := 0.0
		var current := room
		while current != null and not current.is_start:
			var entry := layout.get_entry_corridor(current.id)
			var parent := layout.get_room(entry.room_a) if entry else null
			if parent == null:
				length = INF
				break
			length += (Vector2(current.pos) + Vector2(current.size) / 2.0).distance_to(Vector2(parent.pos) + Vector2(parent.size) / 2.0) * cell
			current = parent
		lengths.append(length)
	return lengths


## Per raider type in the floor's pool: seconds to reach the Relic from the nearest
## spawnable room (>= raider_min_arrival_sec, the spawn gate) and mean over rooms,
## then seconds to destroy it with 1 and 3 raiders.
static func relic_rows() -> Array[Dictionary]:
	var cfg := floor_config()
	var rows: Array[Dictionary] = []
	for f in range(1, FLOORS + 1):
		var layouts: Array[MapLayout] = []
		for s in range(1, LAYOUT_SEEDS + 1):
			layouts.append(MapGenerator.generate_floor(s, cfg, f))
		for type in pool_types(f):
			if type.role != EnemyType.Role.RAIDER:
				continue
			var e := enemy_stats(type, f)
			var arrivals: Array[float] = []
			for layout in layouts:
				for length in _arrival_lengths(layout):
					var sec := length / float(e["speed"])
					if sec >= cfg.raider_min_arrival_sec and sec < INF:
						arrivals.append(sec)
			arrivals.sort()
			var mean := 0.0
			for a in arrivals:
				mean += a
			rows.append({
				"floor": f, "enemy": type.id, "relic_hp": cfg.relic_max_hp, "dmg_per_tick": e["relic"],
				"arrival_min_s": snappedf(arrivals[0], 0.1) if not arrivals.is_empty() else -1.0,
				"arrival_mean_s": snappedf(mean / arrivals.size(), 0.1) if not arrivals.is_empty() else -1.0,
				"destroy_1_s": destroy_sec(cfg.relic_max_hp, int(e["relic"]), 1),
				"destroy_3_s": destroy_sec(cfg.relic_max_hp, int(e["relic"]), 3),
			})
	return rows


## Tower breakers (TargetProfile "tower_breaker") vs one defense, 1v1: the defense
## shoots every fire_rate from the moment the enemy is in range, the breaker hits
## every RELIC_TICK_SEC (Enemy.attack_speed). `defense_hp_lost_pct` = share of the
## defense's HP gone by the time the defense has killed it (100 = the defense dies first).
static func tower_rows() -> Array[Dictionary]:
	var defense: Dictionary = Building.CATALOG[Building.BuildingType.BALLESTA]
	var rows: Array[Dictionary] = []
	for f in range(1, FLOORS + 1):
		for type in pool_types(f):
			if type.get_target_profile().id != &"tower_breaker":
				continue
			var e := enemy_stats(type, f)
			var defense_ttk := ceili(float(e["hp"]) / float(defense["damage"])) * float(defense["fire_rate"])
			var destroy := ceili(float(defense["hp"]) / float(e["building"])) * RELIC_TICK_SEC
			rows.append({
				"floor": f, "enemy": type.id, "enemy_hp": e["hp"], "building_dmg_per_s": e["building"],
				"defense_kills_enemy_s": defense_ttk, "enemy_destroys_defense_s": destroy,
				"defense_hp_lost_pct": snappedf(minf(100.0, 100.0 * defense_ttk / destroy), 0.1),
			})
	return rows


static func destroy_sec(relic_hp: int, dmg_per_tick: int, raiders: int) -> float:
	if dmg_per_tick <= 0:
		return INF
	return ceili(float(relic_hp) / float(dmg_per_tick * raiders)) * RELIC_TICK_SEC


## Door loop (session bucle-7): per floor, opening every room once (rooms - 1 doors).
## chance_* = DoorRollConfig.threat_chance at the 1st / 5th / last door; threats and enemies
## are expectations (enemies capped by FloorConfig.max_enemies per wave, not over time);
## embers/bonus = what the doors pay; lit_rooms = rooms the starting embers + the doors' embers
## can light with the growing cost (RoomZone.LIGHT_COST + light_cost_step per lit room).
static func door_rows() -> Array[Dictionary]:
	var config := floor_config()
	var roll := config.door_roll
	var rows: Array[Dictionary] = []
	for f in range(1, FLOORS + 1):
		var doors := config.room_count(f) - 1
		var threats := 0.0
		var enemies := 0.0
		for n in range(1, doors + 1):
			var chance := roll.threat_chance(n, f)
			threats += chance
			enemies += chance * minf(roll.enemy_count(n, f), config.max_enemies(f))
		var embers := roll.embers_reward(f) * doors
		var budget := RESET_EMBERS + embers
		var lit := 0
		var spent := 0
		while spent + RoomZone.LIGHT_COST + config.light_cost_step * lit <= budget:
			spent += RoomZone.LIGHT_COST + config.light_cost_step * lit
			lit += 1
		rows.append({
			"floor": f, "rooms": doors + 1,
			"chance_door1": snappedf(roll.threat_chance(1, f), 0.01),
			"chance_door5": snappedf(roll.threat_chance(5, f), 0.01),
			"chance_last": snappedf(roll.threat_chance(doors, f), 0.01),
			"threats": snappedf(threats, 0.1), "enemies": snappedf(enemies, 0.1),
			"cap": config.max_enemies(f), "embers": embers, "bonus_each": roll.bonus_amount(f),
			"bonus_total": roll.bonus_amount(f) * doors, "lit_rooms": lit,
		})
	return rows


## Extraction waves per floor and stage: wave size, gap between waves and the spawn rate it implies.
static func extraction_rows() -> Array[Dictionary]:
	var config := floor_config()
	var rows: Array[Dictionary] = []
	for f in range(1, FLOORS + 1):
		for stage in config.extraction_stage_count:
			var size := config.extraction_wave_size(stage)
			var gap := config.extraction_stage_interval(f, stage)
			rows.append({
				"floor": f, "stage": stage, "wave": size, "gap_sec": snappedf(gap, 0.1),
				"enemies_per_min": snappedf(size * 60.0 / gap, 0.1), "cap": config.max_enemies(f),
			})
	return rows


const BUILDING_YIELD := 3
## ResourceManager.reset_resources() defaults: what a run starts with.
const START_RESOURCES := {"iron": 15, "food": 15, "lore": 10, "embers": 20}
## Heroes in a run (GameSession.PARTY_SIZE, the picked pair before recruits; they also
## share each invasion wave) and HP a hero loses (and heals back with Comida) per floor.
const PARTY_SIZE := 2
const HEAL_HP_PER_HERO := 30


## Economy (session economia-8): per floor and resource, what a reference player earns and
## what there is to spend it on. Reference player: every lit room (+ the free start room)
## gets its major, split evenly over Forja/Granja/Scriptorium, and 2 minors split over
## Ballesta/Pinchos, bought with the rising cost curve; majors work half the floor's doors on
## average; research (all entries) and hero levels are spread evenly over the floors; Comida
## also heals PARTY_SIZE heroes HEAL_HP_PER_HERO HP per floor; Brasas lights the lit rooms.
## income = doors (DoorRollConfig) + workshops; run_ratio = cumulative income / cumulative
## sink (> 1 = surplus, < 1 = shortfall); a resource with no sink or no income is "useless".
static func economy_rows() -> Array[Dictionary]:
	var config := floor_config()
	var roll := config.door_roll
	var up := upgrade_config()
	var curve := BuildingCostCurve.get_default()
	var research_total := 0
	for entry in (load("res://resources/research/research_config.tres") as ResearchConfig).entries:
		research_total += entry.cost
	var level_total := 0
	for lvl in up.max_level:
		level_total += up.get_cost(lvl)
	var rows: Array[Dictionary] = []
	var income_run := {"iron": 0.0, "food": 0.0, "lore": 0.0, "embers": 0.0}
	var sink_run := {"iron": 0.0, "food": 0.0, "lore": 0.0, "embers": 0.0}
	for f in range(1, FLOORS + 1):
		var doors := config.room_count(f) - 1
		var lit := 0
		var spent := 0
		var budget := RESET_EMBERS + roll.embers_reward(f) * doors
		var embers_sink := 0
		while spent + RoomZone.LIGHT_COST + config.light_cost_step * lit <= budget:
			var cost := RoomZone.LIGHT_COST + config.light_cost_step * lit
			spent += cost
			embers_sink += cost
			lit += 1
		var majors := lit + 1
		var minors := 2 * (lit + 1)
		var weights: Vector3 = roll.bonus_weights_by_floor[clampi(f - 1, 0, roll.bonus_weights_by_floor.size() - 1)]
		var share := {"iron": weights.x / (weights.x + weights.y + weights.z), "food": weights.y / (weights.x + weights.y + weights.z), "lore": weights.z / (weights.x + weights.y + weights.z)}
		var build_sink := 0
		for k in ceili(majors / 3.0):
			build_sink += 3 * curve.cost(Building.CATALOG[Building.BuildingType.FORJA]["cost"], k)
		for k in ceili(minors / 2.0):
			build_sink += 2 * curve.cost(Building.CATALOG[Building.BuildingType.BALLESTA]["cost"], k)
		for key in ["iron", "food", "lore", "embers"]:
			var income := 0.0
			if key == "embers":
				income = roll.embers_reward(f) * doors
			else:
				income = roll.bonus_amount(f) * doors * share[key] + (majors / 3.0) * BUILDING_YIELD * doors / 2.0
			if f == 1:
				income += START_RESOURCES[key]
			var sink := 0.0
			match key:
				"iron":
					sink = build_sink
				"food":
					sink = PARTY_SIZE * level_total / float(FLOORS) + PARTY_SIZE * up.heal_cost(HEAL_HP_PER_HERO)
				"lore":
					sink = research_total / float(FLOORS)
				"embers":
					sink = embers_sink
			income_run[key] += income
			sink_run[key] += sink
			rows.append({
				"floor": f, "resource": key, "income": snappedf(income, 0.1), "sink": snappedf(sink, 0.1),
				"run_ratio": snappedf(income_run[key] / maxf(sink_run[key], 0.001), 0.01),
			})
	return rows


## progresion-10: the run curve per floor in both difficulties: multipliers, door
## threat at WAVE_TURN, cap, Relic HP, mean party loss per encounter (heroes at level
## f - 1) and, on boss floors, the boss's HP, its charge and the seconds BOSS_PARTY
## needs to kill it (sum of DPS, no misses).
static func difficulty_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var cfg := floor_config()
	for level in DifficultyConfig.get_default().levels:
		difficulty = level
		for f in range(1, FLOORS + 1):
			var theme := cfg.theme(f)
			var loss := 0.0
			for hero_id in HERO_IDS:
				loss += pool_encounter_loss(hero_id, f - 1, f)
			var row := {
				"difficulty": level.id, "floor": f, "theme": theme.display_name if theme else "",
				"hp_mult": snappedf(cfg.enemy_hp_multiplier(f) * level.hp_mult, 0.01),
				"dmg_mult": snappedf(cfg.enemy_damage_multiplier(f) * level.damage_mult, 0.01),
				"threat_pct": snappedf(clampf(cfg.door_roll.threat_chance(WAVE_TURN, f) * cfg.threat_multiplier(f) * level.threat_mult, 0.0, cfg.door_roll.max_chance) * 100.0, 0.1),
				"max_enemies": cfg.max_enemies(f) + level.extra_max_enemies,
				"relic_hp": roundi(cfg.relic_max_hp * level.relic_hp_mult),
				"loss_pct": snappedf(loss / HERO_IDS.size() * 100.0, 0.1),
				"boss": "", "boss_hp": 0, "boss_charge": 0, "boss_ttk_s": 0.0,
			}
			if theme and theme.boss:
				var boss := enemy_stats(theme.boss, f)
				var dps := 0.0
				for hero_id in BOSS_PARTY:
					dps += float(hero_stats(hero_id, f - 1)["dps"])
				row["boss"] = theme.boss.id
				row["boss_hp"] = boss["hp"]
				row["boss_charge"] = maxi(1, roundi(theme.boss.charge_damage * cfg.enemy_damage_multiplier(f) * theme.boss.damage_mult * level.damage_mult))
				row["boss_ttk_s"] = snappedf(float(boss["hp"]) / maxf(dps, 0.01), 0.1)
			rows.append(row)
	difficulty = null
	return rows


static func party_size() -> int:
	return PARTY_BY_PLAYERS[clampi(players - 1, 0, PARTY_BY_PLAYERS.size() - 1)]


## Expected invasions on floor f (one roll per door, rooms - 1 doors), with the
## floor's threat_mult, the difficulty's and the player scaling's (capped like FloorManager).
static func floor_threats(f: int) -> float:
	var cfg := floor_config()
	var mult := cfg.threat_multiplier(f) * (difficulty.threat_mult if difficulty else 1.0) * PlayerScaling.get_default().threat(players)
	var threats := 0.0
	for n in range(1, cfg.room_count(f)):
		threats += clampf(cfg.door_roll.threat_chance(n, f) * mult, 0.0, cfg.door_roll.max_chance)
	return threats


## calidad-13: every floor x difficulty x 1-4 players (party 2/2/3/4, heroes at level
## f - 1). loss_pct = mean HP % a hero loses to its share of one invasion wave;
## floor_loss_pct = that x the floor's expected invasions (the per-hero pressure of a
## floor); parity = floor_loss / the solo floor_loss of the same difficulty and floor
## (1.0 = co-op feels like solo per hero). PlayerScaling is tuned so 2-4 players sit in
## [PARITY_MIN, PARITY_MAX]. relic_destroy_s = seconds 3 of the floor's strongest raider
## need to break the (scaled) Relic; max_enemies = live cap.
const PARITY_MIN := 0.85
const PARITY_MAX := 1.2


static func scaling_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var cfg := floor_config()
	var scaling := PlayerScaling.get_default()
	for level in DifficultyConfig.get_default().levels:
		difficulty = level
		var solo := {}
		for p in range(1, 5):
			players = p
			for f in range(1, FLOORS + 1):
				var loss := 0.0
				for hero_id in HERO_IDS:
					loss += pool_encounter_loss(hero_id, f - 1, f)
				loss /= HERO_IDS.size()
				var floor_loss := loss * floor_threats(f)
				if p == 1:
					solo[f] = floor_loss
				var relic_hp := roundi(cfg.relic_max_hp * level.relic_hp_mult * scaling.relic_hp(p))
				var raider_dmg := 0
				for type in pool_types(f):
					if type.role == EnemyType.Role.RAIDER:
						raider_dmg = maxi(raider_dmg, int(enemy_stats(type, f)["relic"]))
				rows.append({
					"difficulty": level.id, "players": p, "party": party_size(), "floor": f,
					"hp_mult": snappedf(cfg.enemy_hp_multiplier(f) * level.hp_mult * scaling.hp(p), 0.01),
					"threats": snappedf(floor_threats(f), 0.01),
					"max_enemies": cfg.max_enemies(f) + level.extra_max_enemies + scaling.extra_enemies(p),
					"loss_pct": snappedf(loss * 100.0, 0.1),
					"floor_loss_pct": snappedf(floor_loss * 100.0, 0.1),
					"parity": snappedf(floor_loss / maxf(float(solo[f]), 0.0001), 0.01),
					"relic_hp": relic_hp,
					"relic_destroy_s": destroy_sec(relic_hp, raider_dmg, 3) if raider_dmg > 0 else -1.0,
				})
	players = 1
	difficulty = null
	return rows


## juego-22: Monte Carlo run model. Per (party, difficulty) RUNS runs of floors 1-5 over the
## real data: a generated map per floor (MapGenerator), doors opened in a random reveal order
## until the exit shows up (turns), each door pays discovery embers + its random resource and
## rolls the threat (DoorRollConfig x floor x difficulty x PlayerScaling, wave capped); a wave
## is rolled from the floor pool and dealt round-robin to the living heroes, each killing its
## share one by one (same exposure model as encounter_loss, per real enemy). Then the carrier
## walks start -> exit at carrier speed under the stage-0 extraction waves; on boss floors the
## whole party hits the boss while it hits one hero (contact + Embestida every charge_cooldown).
## Spending (each floor start, in this order): revive the downed, level every hero up to
## floor - 1, heal with what is left (all Comida); each discovered room is lit when the Brasas
## allow it and gets a Forja/Granja/Scriptorium (round robin) when the Hierro allows it;
## workshops pay BUILDING_YIELD per door; discovery passives pay their Saber/Brasas. After every
## fight a downed hero is revived (Comida) while an ally stands. Actives by uptime (duration /
## cooldown): Golpe Furtivo in the Rogue's active_dps, Grito de Guerra x the living party's DPS,
## Interposición x the damage the party takes. Not modelled: towers/traps, Rest/Elite/Loot rooms,
## items, perks, raiders on the Relic. A floor is lost when every hero is down.
## Rows per (difficulty, party, floor): win_rate (share of runs that cleared this floor), party
## DPS, hp_lost_pct (damage taken / party max HP), resources at floor end and turns to the exit
## (means over the runs that played the floor).
const RUNS := 50
## Average px walked per room on the carrier's path (half a slot pitch of 64 px cells).
const ROOM_WALK_PX := MapGenerator.SLOT_PITCH * 64.0 * 0.5
static var _duel_cache: Dictionary = {}


## Every hero alone, every pair, every trio and the four.
static func run_parties() -> Array:
	var out: Array = []
	for i in HERO_IDS.size():
		out.append([HERO_IDS[i]])
	for i in HERO_IDS.size():
		for j in range(i + 1, HERO_IDS.size()):
			out.append([HERO_IDS[i], HERO_IDS[j]])
	for i in HERO_IDS.size():
		var trio: Array = HERO_IDS.duplicate()
		trio.remove_at(i)
		out.append(trio)
	out.append(HERO_IDS.duplicate())
	return out


static func run_rows(runs: int = RUNS, parties: Array = [], levels: Array = []) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if parties.is_empty():
		parties = run_parties()
	if levels.is_empty():
		levels = DifficultyConfig.get_default().levels
	for level: DifficultyLevel in levels:
		difficulty = level
		for party: Array in parties:
			players = 1 if party.size() <= 2 else party.size()  # alone = 2 heroes; co-op = 1 each
			_duel_cache.clear()
			var acc: Array[Dictionary] = []
			for f in FLOORS:
				acc.append({"played": 0, "won": 0, "dps": 0.0, "lost": 0.0, "iron": 0.0, "food": 0.0, "lore": 0.0, "embers": 0.0, "turns": 0.0})
			for r in runs:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(["run", party, level.id, r])
				_simulate_run(party, rng, acc)
			for f in FLOORS:
				var a: Dictionary = acc[f]
				var n := maxf(float(a["played"]), 1.0)
				rows.append({
					"difficulty": level.id, "party": "+".join(party), "size": party.size(), "floor": f + 1,
					"runs": runs, "win_rate": snappedf(float(a["won"]) / runs, 0.01),
					"dps": snappedf(a["dps"] / n, 0.01), "hp_lost_pct": snappedf(a["lost"] / n * 100.0, 0.1),
					"iron": snappedf(a["iron"] / n, 0.1), "food": snappedf(a["food"] / n, 0.1),
					"lore": snappedf(a["lore"] / n, 0.1), "embers": snappedf(a["embers"] / n, 0.1),
					"turns": snappedf(a["turns"] / n, 0.1),
				})
	players = 1
	difficulty = null
	_duel_cache.clear()
	return rows


static func _cached_duel(hero_id: String, lvl: int, type: EnemyType, f: int) -> Dictionary:
	var key := "%s|%d|%s|%d" % [hero_id, lvl, type.id, f]
	if not _duel_cache.has(key):
		var d := duel(hero_id, lvl, type, f)
		var hero := hero_stats(hero_id, lvl)
		d["approach"] = approach_sec(hero, float(enemy_stats(type, f)["speed"]))
		d["interval"] = float(hero["interval"])
		_duel_cache[key] = d
	return _duel_cache[key]


static func _max_hp(id: String, lvl: int) -> float:
	return float(_cached_hero(id, lvl)["hp"])


static func _cached_hero(id: String, lvl: int) -> Dictionary:
	var key := "hero|%s|%d" % [id, lvl]
	if not _duel_cache.has(key):
		_duel_cache[key] = hero_stats(id, lvl)
	return _duel_cache[key]


static func _simulate_run(party: Array, rng: RandomNumberGenerator, acc: Array[Dictionary]) -> void:
	var cfg := floor_config()
	var up := upgrade_config()
	var scaling := PlayerScaling.get_default()
	var curve := BuildingCostCurve.get_default()
	var res := START_RESOURCES.duplicate()
	var levels := {}
	var hp := {}
	for id: String in party:
		levels[id] = 0
		hp[id] = _max_hp(id, 0)
	for f in range(1, FLOORS + 1):
		var a: Dictionary = acc[f - 1]
		a["played"] += 1
		for id: String in party:  # revive (a hero lost on an earlier floor stays at -INF)
			if hp[id] == 0.0 and res["food"] >= up.revive_cost(f):
				res["food"] -= up.revive_cost(f)
				hp[id] = _max_hp(id, levels[id]) * up.revive_hp_pct
		for id: String in party:  # level up to floor - 1
			while hp[id] > 0.0 and levels[id] < mini(f - 1, up.max_level) and res["food"] >= up.get_cost(levels[id]):
				res["food"] -= up.get_cost(levels[id])
				var before := _max_hp(id, levels[id])
				levels[id] += 1
				hp[id] += _max_hp(id, levels[id]) - before
		for id: String in party:  # heal with the rest
			var missing := floori(_max_hp(id, levels[id]) - hp[id])
			if hp[id] > 0.0 and missing > 0:
				var heal := mini(missing, floori(res["food"] / maxf(up.heal_cost_per_hp, 0.001)))
				while heal > 0 and up.heal_cost(heal) > res["food"]:
					heal -= 1
				if heal > 0:
					res["food"] -= up.heal_cost(heal)
					hp[id] += heal
		var max_total := 0.0
		var dps := 0.0
		for id: String in party:
			if hp[id] > 0.0:
				max_total += _max_hp(id, levels[id])
				dps += float(_cached_hero(id, levels[id])["dps"])
		a["dps"] += dps
		var damage := [0.0]
		var layout := MapGenerator.generate_floor(rng.randi(), cfg, f)
		var start_id := layout.get_start_room_id()
		var revealed := {start_id: true}
		var exit_id := ""
		for room in layout.rooms:
			if room.is_exit:
				exit_id = room.id
		var lit := 0
		var workshops := {"iron": 0, "food": 0, "lore": 0}
		var built := 0
		var turns := 0
		var threat_mult := cfg.threat_multiplier(f) * difficulty.threat_mult * scaling.threat(players)
		var cap := cfg.max_enemies(f) + difficulty.extra_max_enemies + scaling.extra_enemies(players)
		while not revealed.has(exit_id) and _alive(party, hp):
			var frontier: Array[String] = []
			for c in layout.corridors:
				if c.is_secret:
					continue
				if revealed.has(c.room_a) and not revealed.has(c.room_b) and not frontier.has(c.room_b):
					frontier.append(c.room_b)
				elif revealed.has(c.room_b) and not revealed.has(c.room_a) and not frontier.has(c.room_a):
					frontier.append(c.room_a)
			if frontier.is_empty():
				break
			revealed[frontier[rng.randi_range(0, frontier.size() - 1)]] = true
			turns += 1
			res["embers"] += cfg.discovery_embers(f)
			for id: String in party:
				var passive := hero_data(id).passive
				if hp[id] > 0.0 and passive and passive.effect == AbilityData.Effect.LORE_ON_DISCOVERY:
					res["lore"] += roundi(passive.value)
				elif hp[id] > 0.0 and passive and passive.effect == AbilityData.Effect.EMBERS_ON_DISCOVERY:
					res["embers"] += roundi(passive.value)
			var bonus_key := cfg.door_roll.roll_bonus_resource(f, rng)
			if bonus_key != "":
				res[bonus_key] += cfg.door_roll.bonus_amount(f)
			for key in workshops:
				res[key] += workshops[key] * BUILDING_YIELD
			var light_cost := RoomZone.LIGHT_COST + cfg.light_cost_step * lit
			if res["embers"] >= light_cost:
				res["embers"] -= light_cost
				lit += 1
				var cost := curve.cost(Building.CATALOG[Building.BuildingType.FORJA]["cost"], built)
				if res["iron"] >= cost:
					res["iron"] -= cost
					workshops[["iron", "food", "lore"][built % 3]] += 1
					built += 1
			if rng.randf() < clampf(cfg.door_roll.threat_chance(turns, f) * threat_mult, 0.0, cfg.door_roll.max_chance):
				var count := mini(scaling.wave(cfg.door_roll.enemy_count(turns, f), players), cap)
				_fight(party, levels, hp, _roll_wave(f, count, rng), f, rng, damage)
				_revive_downed(party, levels, hp, res, f)
		a["turns"] += turns
		var walk_sec := ROOM_WALK_PX * maxi(_room_path(layout, start_id, exit_id).size() - 1, 1) / (MoveAction.DEFAULT_SPEED_PX * cfg.carrier_speed_mult)
		var waves := 1 + int(walk_sec / cfg.extraction_stage_interval(f, 0))
		for _w in waves:
			if _alive(party, hp):
				_fight(party, levels, hp, _roll_wave(f, mini(scaling.wave(cfg.extraction_wave_size(0), players), cap), rng), f, rng, damage)
				_revive_downed(party, levels, hp, res, f)
		var theme := cfg.theme(f)
		if theme and theme.boss and _alive(party, hp):
			_boss_fight(party, levels, hp, theme.boss, f, damage, res)
		a["lost"] += damage[0] / maxf(max_total, 1.0)
		for key in ["iron", "food", "lore", "embers"]:
			a[key] += res[key]
		if not _alive(party, hp):
			return
		a["won"] += 1
		for id: String in party:  # still down when the floor ends: lost for the run
			if hp[id] == 0.0:
				hp[id] = -INF


## Party-wide active uptime: [DPS multiplier (Grito de Guerra), damage-taken multiplier (Interposición)]
## from the living heroes' TEAM_ATTACK_BUFF / TEAM_SHIELD actives.
static func _team_mults(party: Array, hp: Dictionary) -> Array[float]:
	var dps := 1.0
	var taken := 1.0
	for id: String in party:
		var active := hero_data(id).active
		if hp[id] <= 0.0 or active == null:
			continue
		var uptime := minf(active.duration / maxf(active.cooldown, 0.001), 1.0)
		if active.effect == AbilityData.Effect.TEAM_ATTACK_BUFF:
			dps *= 1.0 + active.value * uptime
		elif active.effect == AbilityData.Effect.TEAM_SHIELD:
			taken *= 1.0 - active.value * uptime
	return [dps, taken]


## A downed hero gets up (Comida) while somebody stands (PlayerStats.revive_hero needs an ally).
static func _revive_downed(party: Array, levels: Dictionary, hp: Dictionary, res: Dictionary, f: int) -> void:
	var up := upgrade_config()
	for id: String in party:
		if hp[id] == 0.0 and _alive(party, hp) and res["food"] >= up.revive_cost(f):
			res["food"] -= up.revive_cost(f)
			hp[id] = _max_hp(id, levels[id]) * up.revive_hp_pct


static func _alive(party: Array, hp: Dictionary) -> bool:
	return party.any(func(id: String) -> bool: return hp[id] > 0.0)


static func _roll_wave(f: int, count: int, rng: RandomNumberGenerator) -> Array[EnemyType]:
	var pool := floor_config().enemy_pool(f)
	var out: Array[EnemyType] = []
	for i in count:
		var t := pool.roll(rng) if pool else null
		if t:
			out.append(t)
	return out


## Round-robin over the living heroes; one that falls hands its unkilled enemies on.
static func _fight(party: Array, levels: Dictionary, hp: Dictionary, wave: Array[EnemyType], f: int, rng: RandomNumberGenerator, damage: Array) -> void:
	var queue: Array[EnemyType] = wave.duplicate()
	while not queue.is_empty():
		var alive := party.filter(func(id: String) -> bool: return hp[id] > 0.0)
		if alive.is_empty():
			return
		var shares := {}
		for i in queue.size():
			var id: String = alive[i % alive.size()]
			if not shares.has(id):
				shares[id] = []
			shares[id].append(queue[i])
		queue.clear()
		var mults := _team_mults(party, hp)
		for id: String in shares:
			var left: Array = shares[id]
			var hero := _cached_hero(id, levels[id])
			var speedup := mults[0] * float(hero["active_dps"]) / maxf(float(hero["dps"]), 0.001)
			var t := rng.randf() * float(_cached_duel(id, levels[id], left[0], f)["interval"])
			for i in left.size():
				var d := _cached_duel(id, levels[id], left[i], f)
				t += int(d["hits_to_kill"]) * float(d["interval"]) / speedup
				var exposure := maxf(t - float(d["interval"]) - float(d["approach"]), 0.0)
				var hit := float(d["hit_taken"]) * mults[1] * exposure / Enemy.CONTACT_HIT_INTERVAL
				damage[0] += minf(hit, hp[id])
				hp[id] -= hit
				if hp[id] <= 0.0:
					hp[id] = 0.0
					for j in range(i + 1, left.size()):
						queue.append(left[j])
					break


static func _boss_fight(party: Array, levels: Dictionary, hp: Dictionary, boss: EnemyType, f: int, damage: Array, res: Dictionary) -> void:
	var stats := enemy_stats(boss, f)
	var boss_hp := float(stats["hp"])
	var charge := maxf(1.0, roundf(boss.charge_damage * floor_config().enemy_damage_multiplier(f) * boss.damage_mult * difficulty.damage_mult))
	while boss_hp > 0.0 and _alive(party, hp):
		var dps := 0.0
		var target := ""
		var mults := _team_mults(party, hp)
		for id: String in party:
			if hp[id] > 0.0:
				dps += float(_cached_hero(id, levels[id])["active_dps"]) * mults[0]
				if target == "":
					target = id
		var hero := _cached_hero(target, levels[target])
		var per_sec := (float(stats["contact"]) * (1.0 - float(hero["reduction_pct"])) / Enemy.CONTACT_HIT_INTERVAL + charge / maxf(boss.charge_cooldown, 0.1)) * mults[1]
		var t := minf(boss_hp / maxf(dps, 0.01), hp[target] / maxf(per_sec, 0.01))
		boss_hp -= dps * t
		var taken := minf(per_sec * t, hp[target])
		hp[target] -= taken
		damage[0] += taken
		if hp[target] <= 0.001:
			hp[target] = 0.0
			_revive_downed(party, levels, hp, res, f)


## Rooms on the shortest corridor path (both ends included).
static func _room_path(layout: MapLayout, from: String, to: String) -> Array[String]:
	var prev := {from: ""}
	var frontier: Array[String] = [from]
	while not frontier.is_empty():
		var at: String = frontier.pop_front()
		if at == to:
			break
		for c in layout.corridors:
			var other := c.room_b if c.room_a == at else (c.room_a if c.room_b == at else "")
			if other != "" and not prev.has(other):
				prev[other] = at
				frontier.append(other)
	var path: Array[String] = []
	var cur := to
	while cur != "" and prev.has(cur):
		path.push_front(cur)
		cur = prev[cur]
	return path


static func to_csv(rows: Array[Dictionary]) -> String:
	if rows.is_empty():
		return ""
	var keys: Array = rows[0].keys()
	var lines: Array[String] = [",".join(keys)]
	for row in rows:
		var cells: Array[String] = []
		for key in keys:
			cells.append(str(row[key]))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


static func to_markdown(rows: Array[Dictionary]) -> String:
	if rows.is_empty():
		return ""
	var keys: Array = rows[0].keys()
	var lines: Array[String] = ["| " + " | ".join(keys) + " |", "|" + "---|".repeat(keys.size())]
	for row in rows:
		var cells: Array[String] = []
		for key in keys:
			cells.append(str(row[key]))
		lines.append("| " + " | ".join(cells) + " |")
	return "\n".join(lines) + "\n"

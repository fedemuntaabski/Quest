extends RefCounted
class_name BalanceSim

## BalanceSim: pure-math duel / wave / Nexo model over the real data (.tres
## heroes, EnemyTypes, FloorConfig, UpgradeConfig) and the real formulas
## (Enemy.resolved_*, FloorConfig multipliers, UpgradeConfig curves). No scene,
## no randomness: tools/balance_sim.gd exports it as CSV, tests/test_balance.gd
## asserts the targets on it. Model (documented in docs/BALANCE.md):
##  - hero AoE hits every enemy in range each `interval` (free-running Timer: the
##    first tick lands uniformly within one interval, so the enemy is exposed for
##    (hits - 0.5) * interval on average); enemies hit on contact every
##    CONTACT_HIT_INTERVAL. Damage taken is the expectation (no rounding to whole ticks);
##  - an encounter = the floor's invasion wave at turn WAVE_TURN, all in range at once;
##  - hero level on floor f = f - 1 (one level-up bought per floor).

const HERO_IDS: Array[String] = ["warrior", "mage", "rogue", "tank"]
const FLOORS := 5
const WAVE_TURN := 5
const LAYOUT_SEEDS := 30
const FLOOR_CONFIG_PATH := "res://resources/floors/default_floor_config.tres"
const UPGRADE_CONFIG_PATH := "res://resources/upgrades/run_upgrade_config.tres"
## Sapper/raider hit-the-Nexo timer (Enemy.attack_speed default).
const NEXO_TICK_SEC := 1.0


static func floor_config() -> FloorConfig:
	return load(FLOOR_CONFIG_PATH) as FloorConfig


static func upgrade_config() -> UpgradeConfig:
	return load(UPGRADE_CONFIG_PATH) as UpgradeConfig


static func hero_data(hero_id: String) -> CharacterData:
	return load("res://resources/characters/%s.tres" % hero_id) as CharacterData


## What PlayerStats applies: base + per-level bonuses (+ passives, see passive_*).
static func hero_stats(hero_id: String, level: int) -> Dictionary:
	var data := hero_data(hero_id)
	var up := upgrade_config()
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
		"reduction_pct": reduction,
		"ehp": ehp,
		"active_dps": active_dps, "active_ehp": active_ehp,
	}


## Always-on passive reduction (Piel de Hierro). Position-dependent ones
## (Muro Viviente, only near the Nexo) are not counted: conservative.
static func damage_reduction_pct(data: CharacterData) -> float:
	if data.passive and data.passive.effect == AbilityData.Effect.DAMAGE_REDUCTION_PCT:
		return data.passive.value
	return 0.0


## Enemy numbers after floor + type multipliers, exactly as Enemy.configure() applies them.
static func enemy_stats(type: EnemyType, floor_index: int) -> Dictionary:
	var cfg := floor_config()
	var hp_mult := cfg.enemy_hp_multiplier(floor_index) * type.hp_mult
	var dmg_mult := cfg.enemy_damage_multiplier(floor_index) * type.damage_mult
	return {
		"enemy": type.id, "floor": floor_index, "role": "raider" if type.role == EnemyType.Role.RAIDER else "hunter",
		"hp": maxi(1, roundi(Enemy.resolved_hp(type) * hp_mult)),
		"contact": maxi(1, roundi(Enemy.resolved_contact_damage(type) * dmg_mult)),
		"nexo": maxi(1, roundi(type.damage_vs_nexo * dmg_mult)) if type.damage_vs_nexo > 0 else 0,
		"speed": Enemy.resolved_speed(type) * type.speed_mult,
	}


static func pool_types(floor_index: int) -> Array[EnemyType]:
	var pool := floor_config().enemy_pool(floor_index)
	return pool.types if pool else ([] as Array[EnemyType])


static func wave_size(floor_index: int) -> int:
	return 1 + int(WAVE_TURN / 5.0) + floor_config().extra_invasion_enemies(floor_index)


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


## Fraction of the hero's max HP lost to a whole wave (all in range, killed together by AoE).
static func encounter_loss(hero_id: String, level: int, type: EnemyType, floor_index: int) -> float:
	var d := duel(hero_id, level, type, floor_index)
	var hero := hero_stats(hero_id, level)
	return wave_size(floor_index) * float(d["hp_lost"]) / float(hero["hp"])


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


## Per raider type in the floor's pool: seconds to reach the Nexo from the nearest
## spawnable room (>= raider_min_arrival_sec, the spawn gate) and mean over rooms,
## then seconds to destroy it with 1 and 3 raiders.
static func nexo_rows() -> Array[Dictionary]:
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
				"floor": f, "enemy": type.id, "nexo_hp": cfg.nexo_max_hp, "dmg_per_tick": e["nexo"],
				"arrival_min_s": snappedf(arrivals[0], 0.1) if not arrivals.is_empty() else -1.0,
				"arrival_mean_s": snappedf(mean / arrivals.size(), 0.1) if not arrivals.is_empty() else -1.0,
				"destroy_1_s": destroy_sec(cfg.nexo_max_hp, int(e["nexo"]), 1),
				"destroy_3_s": destroy_sec(cfg.nexo_max_hp, int(e["nexo"]), 3),
			})
	return rows


static func destroy_sec(nexo_hp: int, dmg_per_tick: int, raiders: int) -> float:
	if dmg_per_tick <= 0:
		return INF
	return ceili(float(nexo_hp) / float(dmg_per_tick * raiders)) * NEXO_TICK_SEC


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

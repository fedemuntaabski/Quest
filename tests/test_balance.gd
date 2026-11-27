extends SceneTree

## Balance targets (docs/BALANCE.md) checked on BalanceSim over the real .tres data:
##  - a floor-1 enemy dies in 2-4 hero hits (every hero, every floor-1 type);
##  - the basic (floor-1) encounter costs a hero at most 1/3 of its HP;
##  - difficulty grows floor by floor without sudden jumps;
##  - the Relic survives long enough to react to the alert, but falls if ignored;
##  - no hero is strictly better than another (HP, DPS, range), at level 0 and 5;
##  - heroes-9 roles on every floor: the Tank outlasts everyone but kills slowest,
##    the Rogue is the most fragile, the fastest and has the highest DPS;
##  - juego-22 Monte Carlo runs (BalanceSim.run_rows): floor 1 is won by every party of 2 on
##    both difficulties, and in parties of 2-4 no hero's mean win rate is more than
##    RUN_HERO_SPREAD_PP from the heroes' mean (per difficulty).
##   godot --headless --path . --script res://tests/test_balance.gd

const MAX_BASIC_LOSS_PCT := 33.4
const MAX_STEP_PCT := 20.0
const MAX_FLOOR5_LOSS_PCT := 70.0
const RELIC_ONE_RAIDER_SEC := Vector2(15.0, 45.0)
const RELIC_THREE_RAIDERS_MIN_SEC := 6.0
## Tower breakers (session impl-6): they must hurt a defense yet lose to it 1v1.
const TOWER_HP_LOST_PCT := Vector2(30.0, 99.9)

## Economy (session economia-8): every resource earns and has something to buy, and over
## the run neither runs dry (< MIN) nor piles up unspent (> MAX).
const ECONOMY_RUN_RATIO := Vector2(0.2, 3.0)
const RUN_FLOOR1_PAIR_WIN := 0.9
const RUN_HERO_SPREAD_PP := 10.0
## juego-26: the floor-3/5 boss pays FloorConfig.boss_food_reward Comida, so floor 4 stops being a
## Comida wall (Normal pairs: of the floor-3 wins, at least REACH4_MIN also win floor 4; 47 % without
## it, 61 % at 200 runs with 15), floor 3 does not get trivial and Hard stays hard.
const BOSS_FOOD_REWARD := 15
const NORMAL_REACH4_MIN := 0.5
const NORMAL_FLOOR3_MAX := 0.85  # juego-30: 0.65 -> 0.8 (66 % at 200 runs with Saber levels); juego-41: 0.85 (72 %)
const HARD_FLOOR4_MAX := 0.7  # juego-28: 0.1 -> 0.2 (11 %); juego-29: 0.4 (28 %); juego-30: 0.55 (43 %); juego-41: 0.7 (57 % at 200 runs)
## juego-27: +30 Comida on reaching floors 4 and 5, Señor Demonio 150 HP (owner's pick).
const DESCEND_FOOD := 30
const DESCEND_FOOD_FROM := 4
const BOSS5_HP := 150
const NORMAL_REACH5_MIN := 0.3
const HARD_FLOOR5_MAX := 0.35  # juego-30: 0.05 -> 0.15 (9 % at 200 runs); juego-41: 0.35 (25 %)
## juego-28 (owner's pick): Hard's bosses skip its multipliers (Hard pairs floor 3: 10 -> 33 % at
## 200 runs) and co-op of 3 / 4 gets +10 / +20 Comida per descent (the four, Normal: floor 4
## 31 -> 83 %). Normal pairs stay at 51 / 42 / 19 % (200 runs): these are 50-run floors with margin.
const HARD_FLOOR3_MIN := 0.55  # juego-29: 0.25 -> 0.35 (45 %); juego-30: 0.5 (62 %); juego-41: 0.55 (71 % at 200 runs)
const DESCENT_FOOD_BY_PLAYERS := [0, 0, 10, 20]
const NORMAL_PAIR_FLOORS_MIN := {3: 0.62, 4: 0.55, 5: 0.38}  # juego-30: 66 / 57 / 31 %; juego-41 (Obras, room rewards, heal before the extraction): 72 / 66 / 49 % at 200 runs
const FOUR_NORMAL_FLOOR4_MIN := 0.6
const FOUR_NORMAL_FLOOR5_MAX := 0.9  # juego-41: 0.5 -> 0.9 (83 % at 200 runs)
## juego-29 (owner's pick A1 + B): Hard's damage 1.25 -> 1.1 and its start resources x0.75 -> x1
## (Hard pairs 33 / 11 / 1 -> 45 / 28 / 3 % at 200 runs; the floor-4 wall was the door waves a
## level behind), and the Prisoner ransom halved to 8 Comida / 10 Hierro (+5 per floor): offline
## pairs that recruit (BalanceSim "recruit") 48 / 40 / 16 -> 54 / 46 / 20 % on Normal. Hard never
## beats Normal on a floor (pairs) and recruiting is not a loss.
const HARD_DAMAGE_MULT := 1.1
const HARD_FLOOR4_MIN := 0.4  # juego-30: 0.18 -> 0.3; juego-41: 0.4
## juego-30 (owner's pick A + B): a level the Comida can't pay costs 2 Saber per Comida
## (UpgradeConfig.alt_*) and the cell also takes 15 Saber (+5 per floor). Normal pairs 51 / 42 / 19 ->
## 66 / 57 / 31 %, the four 99 / 83 / 25 -> 100 / 86 / 33, Hard pairs 45 / 28 / 3 -> 62 / 43 / 9 (200 runs).
const RECRUIT_COSTS := {"food": 8, "iron": 10, "lore": 15}
const LEVEL_ALT := ["lore", 2.0]
const RECRUIT_COST_PER_FLOOR := 5
var _pair_won := {}

var failures: Array[String] = []


func _initialize() -> void:
	_check_floor1_hits()
	_check_encounters()
	_check_relic()
	_check_towers()
	_check_economy()
	_check_no_dominance(0)
	_check_no_dominance(5)
	_check_hero_roles()
	_check_scaling()
	_check_runs()
	_check_run_towers()
	_check_obras_model()
	_check_boss_play()
	_check_recruits()
	_expect(BalanceSim.encounter_rows() == BalanceSim.encounter_rows(), "BalanceSim is not deterministic")
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_balance: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check_runs() -> void:
	var rows := BalanceSim.run_rows()
	_expect(rows.size() == BalanceSim.run_parties().size() * BalanceSim.FLOORS * DifficultyConfig.get_default().levels.size(), "run rows: %d" % rows.size())
	_expect(BalanceSim.players == 1 and BalanceSim.difficulty == null, "run_rows restores players/difficulty")
	for level in DifficultyConfig.get_default().levels:
		var per_hero := {}
		for row in rows:
			if row["difficulty"] != level.id or int(row["size"]) < 2:
				continue
			if int(row["size"]) == 2 and int(row["floor"]) == 1:
				_expect(float(row["win_rate"]) >= RUN_FLOOR1_PAIR_WIN, "%s: %s wins floor 1 in %.0f %% of runs" % [level.id, row["party"], float(row["win_rate"]) * 100.0])
			for hero_id: String in str(row["party"]).split("+"):
				if not per_hero.has(hero_id):
					per_hero[hero_id] = []
				per_hero[hero_id].append(float(row["win_rate"]))
		_check_food_floor4(rows, level.id)
		var means := {}
		var total := 0.0
		for hero_id in per_hero:
			var sum := 0.0
			for w in per_hero[hero_id]:
				sum += w
			means[hero_id] = sum / per_hero[hero_id].size()
			total += means[hero_id]
		var mean := total / maxf(means.size(), 1)
		for hero_id in means:
			_expect(absf(means[hero_id] - mean) * 100.0 <= RUN_HERO_SPREAD_PP, "%s: %s wins %.1f pp off the mean (parties of 2-4)" % [level.id, hero_id, (means[hero_id] - mean) * 100.0])
	for f in range(1, BalanceSim.FLOORS + 1):
		_expect(float(_pair_won["hard"][f]) <= float(_pair_won["normal"][f]) + 0.001, "floor %d: Hard pairs %.2f beat Normal %.2f" % [f, _pair_won["hard"][f], _pair_won["normal"][f]])


func _check_food_floor4(rows: Array[Dictionary], level_id: String) -> void:
	var cfg := BalanceSim.floor_config()
	_expect(cfg.boss_food_reward == BOSS_FOOD_REWARD and cfg.food_bonus_on_descend == DESCEND_FOOD and cfg.food_bonus_from_floor == DESCEND_FOOD_FROM,
		"Comida: boss %d, descend %d from floor %d" % [cfg.boss_food_reward, cfg.food_bonus_on_descend, cfg.food_bonus_from_floor])
	_expect(cfg.theme(5).boss.base_hp == BOSS5_HP, "floor-5 boss HP %d" % cfg.theme(5).boss.base_hp)
	_expect(not DifficultyConfig.get_default().get_level("hard").scales_bosses, "juego-28: Hard scales its bosses")
	_expect(Array(PlayerScaling.get_default().descent_food) == DESCENT_FOOD_BY_PLAYERS, "descent Comida by players %s" % PlayerScaling.get_default().descent_food)
	var hard := DifficultyConfig.get_default().get_level("hard")
	_expect(is_equal_approx(hard.damage_mult, HARD_DAMAGE_MULT) and is_equal_approx(hard.start_resource_mult, 1.0), "juego-29: Hard damage %.2f, start x%.2f" % [hard.damage_mult, hard.start_resource_mult])
	var rule := cfg.get_room_type_rule(RoomData.RoomType.PRISONER)
	var up := BalanceSim.upgrade_config()
	_expect(up.alt_resource == LEVEL_ALT[0] and is_equal_approx(up.alt_cost_mult, LEVEL_ALT[1]), "juego-30: levels also in %s x%.1f" % [up.alt_resource, up.alt_cost_mult])
	_expect(rule.recruit_costs == RECRUIT_COSTS and rule.recruit_cost_per_floor == RECRUIT_COST_PER_FLOOR, "juego-29: ransom %s +%d per floor" % [rule.recruit_costs, rule.recruit_cost_per_floor])
	var per_floor := {}
	for row in rows:
		if row["difficulty"] == level_id and int(row["size"]) == 2:
			per_floor[int(row["floor"])] = float(per_floor.get(int(row["floor"]), 0.0)) + float(row["win_rate"]) / 6.0
	_pair_won[level_id] = per_floor
	var won := {3: 0.0, 4: 0.0, 5: 0.0}
	var pairs := 0
	for row in rows:
		if row["difficulty"] == level_id and int(row["size"]) == 2 and won.has(int(row["floor"])):
			won[int(row["floor"])] += float(row["win_rate"])
			pairs += 1 if int(row["floor"]) == 3 else 0
	var reach4 := float(won[4]) / maxf(float(won[3]), 0.001)
	var floor3 := float(won[3]) / maxi(pairs, 1)
	var floor4 := float(won[4]) / maxi(pairs, 1)
	var reach5 := float(won[5]) / maxf(float(won[4]), 0.001)
	var floor5 := float(won[5]) / maxi(pairs, 1)
	print("%s pairs: floor 3 %.2f, floor 4 %.2f (%.2f of those who reach it), floor 5 %.2f (%.2f)" % [level_id, floor3, floor4, reach4, floor5, reach5])
	if level_id == "normal":
		_expect(reach4 >= NORMAL_REACH4_MIN, "normal: floor 4 won by %.2f of the pairs that reach it" % reach4)
		_expect(floor3 <= NORMAL_FLOOR3_MAX, "normal: floor 3 won by %.2f of the pairs" % floor3)
		_expect(reach5 >= NORMAL_REACH5_MIN, "normal: floor 5 won by %.2f of the pairs that reach it" % reach5)
		for f: int in NORMAL_PAIR_FLOORS_MIN:
			_expect(float(won[f]) / maxi(pairs, 1) >= NORMAL_PAIR_FLOORS_MIN[f], "normal: floor %d won by %.2f of the pairs" % [f, float(won[f]) / maxi(pairs, 1)])
		var four := rows.filter(func(r: Dictionary) -> bool: return r["difficulty"] == level_id and int(r["size"]) == 4)
		var four_won := {}
		for r in four:
			four_won[int(r["floor"])] = float(r["win_rate"])
		print("normal, the four (co-op 4): floor 3 %.2f, floor 4 %.2f, floor 5 %.2f" % [four_won[3], four_won[4], four_won[5]])
		_expect(four_won[4] >= FOUR_NORMAL_FLOOR4_MIN, "normal: the co-op four win floor 4 in %.2f" % four_won[4])
		_expect(four_won[5] <= FOUR_NORMAL_FLOOR5_MAX, "normal: the co-op four win the run in %.2f" % four_won[5])
	else:
		_expect(floor3 >= HARD_FLOOR3_MIN, "%s: floor 3 won by %.2f of the pairs" % [level_id, floor3])
		_expect(floor4 <= HARD_FLOOR4_MAX and floor4 >= HARD_FLOOR4_MIN, "%s: floor 4 won by %.2f of the pairs" % [level_id, floor4])
		_expect(floor5 <= HARD_FLOOR5_MAX, "%s: floor 5 won by %.2f of the pairs" % [level_id, floor5])


## juego-29: offline pairs that free up to 2 prisoners (Normal, BalanceSim "recruit"): they do recruit
## (more than 2 heroes on floor 3) and win floors 3-5 at least as often as without recruiting.
func _check_recruits() -> void:
	var pairs: Array = []
	for i in BalanceSim.HERO_IDS.size():
		for j in range(i + 1, BalanceSim.HERO_IDS.size()):
			pairs.append([BalanceSim.HERO_IDS[i], BalanceSim.HERO_IDS[j]])
	var normal: Array = [DifficultyConfig.get_default().levels[0]]
	var sum := func(rows: Array[Dictionary], key: String, floors: Array) -> float:
		var total := 0.0
		for r in rows:
			if int(r["floor"]) in floors:
				total += float(r[key])
		return total / pairs.size()
	var base := BalanceSim.run_rows(50, pairs, normal)
	var with := BalanceSim.run_rows(50, pairs, normal, true, BalanceSim.BOSS_NEAR_TOWERS, {"recruit": 2})
	var heroes3: float = sum.call(with, "heroes", [3])
	var won_base: float = sum.call(base, "win_rate", [3, 4, 5])
	var won_with: float = sum.call(with, "win_rate", [3, 4, 5])
	print("normal pairs recruiting up to 2: %.2f heroes on floor 3, floors 3-5 won %.2f (without %.2f)" % [heroes3, won_with, won_base])
	_expect(heroes3 > 2.3, "recruits: %.2f heroes on floor 3" % heroes3)
	_expect(won_with >= won_base, "recruiting is a loss: floors 3-5 won %.2f vs %.2f" % [won_with, won_base])
	_expect(BalanceSim._play == BalanceSim.BOSS_PLAY, "run_rows restores the play")
	# juego-30: Saber-paid levels are not a loss, and the "research" what-if spends the Saber.
	var comida_only := BalanceSim.run_rows(50, pairs, normal, true, BalanceSim.BOSS_NEAR_TOWERS, {"level_lore": 0.0})
	var won_comida: float = sum.call(comida_only, "win_rate", [3, 4, 5])
	print("normal pairs, levels in Comida only: floors 3-5 won %.2f (with Saber %.2f)" % [won_comida, won_base])
	_expect(won_base >= won_comida, "Saber levels are a loss: floors 3-5 won %.2f vs %.2f" % [won_base, won_comida])
	var research := BalanceSim.run_rows(50, pairs, normal, true, BalanceSim.BOSS_NEAR_TOWERS, {"research": BalanceSim.RESEARCH_ORDER})
	var bought5: float = sum.call(research, "research", [5])
	var lore5: float = sum.call(research, "lore", [5])
	print("normal pairs, research what-if: %.1f entries bought by floor 5, %.1f Saber left (default %.1f / %.1f)" % [bought5, lore5, sum.call(base, "research", [5]), sum.call(base, "lore", [5])])
	_expect(is_equal_approx(sum.call(base, "research", [5]), 1.0), "default run buys more than the Ballesta")
	_expect(bought5 > 4.0 and lore5 < sum.call(base, "lore", [5]), "research what-if: %.1f entries, %.1f Saber left" % [bought5, lore5])
	_expect(BalanceSim._bonus.is_empty() and BalanceSim._research == null, "run_rows clears the research bonuses")


## juego-23: the runs build Ballestas (every party has one on floor 1) and pulling the floor-3
## boss to one beats fighting it in the dark; towers off builds none.
func _check_run_towers() -> void:
	var pair: Array = [["warrior", "tank"]]
	var normal: Array = [DifficultyConfig.get_default().levels[0]]
	var win3 := func(rows: Array[Dictionary]) -> float:
		return float(rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == 3)[0]["win_rate"])
	var dark: Array[Dictionary] = BalanceSim.run_rows(50, pair, normal, true, 0.0)
	var near: Array[Dictionary] = BalanceSim.run_rows(50, pair, normal, true, 1.0)
	var off: Array[Dictionary] = BalanceSim.run_rows(50, pair, normal, false)
	_expect(float(dark[0]["towers"]) >= 1.0, "runs: %.1f Ballestas on floor 1" % float(dark[0]["towers"]))
	_expect(float(off[0]["towers"]) == 0.0, "runs without towers built %.1f" % float(off[0]["towers"]))
	_expect(win3.call(near) > win3.call(dark) + 0.2, "boss next to a Ballesta %.2f vs in the dark %.2f" % [win3.call(near), win3.call(dark)])
	# juego-41: same on Hard (200 runs, pairs: 91 vs 50 %); the Obras' share of the enemy HP is counted.
	var hard: Array = [DifficultyConfig.get_default().levels[1]]
	var hard_dark: Array[Dictionary] = BalanceSim.run_rows(50, pair, hard, true, 0.0)
	var hard_near: Array[Dictionary] = BalanceSim.run_rows(50, pair, hard, true, 1.0)
	_expect(win3.call(hard_near) > win3.call(hard_dark) + 0.2, "hard: boss next to the Defensas %.2f vs in the dark %.2f" % [win3.call(hard_near), win3.call(hard_dark)])
	_expect(float(dark[0]["dmg_by_towers_pct"]) > 5.0 and float(off[0]["dmg_by_towers_pct"]) == 0.0,
		"Obras' share of the damage: %.1f %% with towers, %.1f %% without" % [float(dark[0]["dmg_by_towers_pct"]), float(off[0]["dmg_by_towers_pct"])])
	var f3 := func(rows: Array[Dictionary]) -> Dictionary:
		return rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == 3)[0]
	_expect(float(f3.call(hard_near)["dmg_by_towers_pct"]) > float(f3.call(hard_dark)["dmg_by_towers_pct"]), "the boss next to the Defensas gives them more of the damage")
	_expect(float(f3.call(dark)["relic_hp_end"]) > 0.0 and float(f3.call(dark)["relic_hp_end"]) <= 1.0, "Relic HP at floor end %.2f" % float(f3.call(dark)["relic_hp_end"]))


## juego-41: one room's Obras as BalanceSim fights next to them (BuildingDef data): a Defensa only works
## lit (requires_light), the Catapulta's splash grows with the wave up to SPLASH_HITS, Pinchos work
## dark, and a fight there gives the Obras their share and makes the raiders wear the Relic down.
func _check_obras_model() -> void:
	var B := Building.BuildingType
	var cat: Dictionary = Building.CATALOG[B.CATAPULTA]
	var bal_dps := float(Building.CATALOG[B.BALLESTA]["damage"]) / float(Building.CATALOG[B.BALLESTA]["fire_rate"])
	var cat_dps := float(cat["damage"]) / float(cat["fire_rate"])
	_expect(BalanceSim._room_dps({"lit": false, B.BALLESTA: 1}, 1) == 0.0, "a dark Ballesta shoots")
	_expect(is_equal_approx(BalanceSim._room_dps({"lit": true, B.BALLESTA: 2}, 4), 2.0 * bal_dps), "two lit Ballestas: %.1f" % BalanceSim._room_dps({"lit": true, B.BALLESTA: 2}, 4))
	_expect(is_equal_approx(BalanceSim._room_dps({"lit": true, B.CATAPULTA: 1}, 1), cat_dps)
		and is_equal_approx(BalanceSim._room_dps({"lit": true, B.CATAPULTA: 1}, 9), cat_dps * BalanceSim.SPLASH_HITS), "Catapulta splash")
	_expect(BalanceSim._room_spikes({"lit": false, B.PINCHOS: 1}) == float(Building.CATALOG[B.PINCHOS]["spike_damage"]), "dark Pinchos don't hurt")
	var cost: int = Building.CATALOG[B.BALLESTA]["cost"]
	var res := {"iron": cost}
	var counts := {}
	var room := {"lit": true}
	_expect(BalanceSim._build(room, B.BALLESTA, res, counts) and res["iron"] == 0 and not BalanceSim._build(room, B.BALLESTA, {"iron": cost}, counts),
		"the second Ballesta costs more (BuildingCostCurve)")
	var rest_hp := {"mage": 1.0}  # juego-42: the Rest room is free, so it heals with no Comida
	var no_food := {"food": 0}
	BalanceSim._heal_with_food(["mage"], {"mage": 1}, rest_hp, no_food, 0.0)
	_expect(rest_hp["mage"] >= floorf(BalanceSim._max_hp("mage", 1)) and no_food["food"] == 0, "a free heal fills HP with 0 Comida: %s" % [rest_hp])
	var raider: EnemyType
	for type in BalanceSim.pool_types(3):
		if type.role == EnemyType.Role.RAIDER and type.damage_vs_relic > 0:
			raider = type
	BalanceSim.difficulty = DifficultyConfig.get_default().levels[0]
	var wave: Array[EnemyType] = [raider, raider, raider]
	var outs := []
	for obras: Dictionary in [{}, {"lit": true, B.BALLESTA: 2, B.PINCHOS: 1}]:
		var hp := {"mage": 999.0}
		var tw := [0.0, 0.0]
		var relic := [100.0]
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		BalanceSim._fight(["mage"], {"mage": 2}, hp, wave, 3, rng, [0.0], obras, tw, relic)
		outs.append([tw[0] / maxf(tw[1], 1.0), relic[0], hp["mage"]])
	# juego-44: the Relic left in the start room while the party explores (BOSS_PLAY "relic_left"): a
	# door wave's raiders go for it and only the Obras there stand in their way.
	_expect(float(BalanceSim.BOSS_PLAY.get("relic_left", -1.0)) == 0.0, "BOSS_PLAY relic_left missing or not 0 by default")
	if BalanceSim.BOSS_PLAY.has("relic_left"):
		var sim: Script = BalanceSim  # called by name: this check was written before the model
		var alone := [100.0]
		var guarded := [100.0]
		sim.call("_raid_relic", [raider] as Array[EnemyType], 3, {"lit": true}, alone, [0.0, 0.0])
		sim.call("_raid_relic", [raider] as Array[EnemyType], 3, {"lit": true, B.BALLESTA: 2}, guarded, [0.0, 0.0])
		print("a floor-3 %s on the Relic left alone: bare room %.1f, 2 lit Ballestas %.1f (of 100)" % [raider.id, alone[0], guarded[0]])
		_expect(alone[0] < 100.0, "a raider alone with the Relic leaves it at %.1f" % alone[0])
		_expect(guarded[0] == 100.0, "2 lit Ballestas let a raider hit the Relic: %.1f" % guarded[0])
	# juego-45 "relic_back_sec": the party walks back to the start room; the raider hits the Relic only until
	# then, and the ones still standing are left for the party (returned).
	_expect(float(BalanceSim.BOSS_PLAY.get("relic_back_sec", -1.0)) == INF, "BOSS_PLAY relic_back_sec missing or not INF by default")
	if BalanceSim.BOSS_PLAY.has("relic_back_sec"):
		var sim: Script = BalanceSim
		var late := [100.0]
		var early := [100.0]
		var late_left: Array = sim.call("_raid_relic", [raider] as Array[EnemyType], 3, {"lit": true}, late, [0.0, 0.0], 999.0)
		var early_left: Array = sim.call("_raid_relic", [raider] as Array[EnemyType], 3, {"lit": true}, early, [0.0, 0.0], 0.0)
		print("Relic left alone, party back after 999 s: %.1f (%d raiders left); after 0 s: %.1f (%d left)" % [late[0], late_left.size(), early[0], early_left.size()])
		_expect(late[0] < 100.0, "party back after 999 s and the Relic is whole: %.1f" % late[0])
		_expect(early[0] == 100.0 and early_left.size() == 1, "party back at once: Relic %.1f, %d raiders left for it" % [early[0], early_left.size()])
	BalanceSim.difficulty = null
	BalanceSim._duel_cache.clear()
	print("raiders on floor 3 vs a Mage: bare room %s, 2 Ballestas + Pinchos %s ([Obras share, Relic, HP])" % [outs[0], outs[1]])
	_expect(outs[0][0] == 0.0 and outs[1][0] > 0.3, "Obras' share in the fight %.2f / %.2f" % [outs[0][0], outs[1][0]])
	_expect(outs[0][1] < 100.0 and outs[1][1] > outs[0][1] and outs[1][2] > outs[0][2], "Defensas save the Relic and the hero: %s" % [outs])


## juego-24: the boss-play assumptions move the floor-3 boss the right way (Guerrero + Paladín,
## Hard, always next to a Ballesta; on Normal it already wins ~90 %): healing with Comida first raises the HP it is met with,
## meeting it before the extraction waves too, and dodging every Embestida wins more fights.
func _check_boss_play() -> void:
	var pair: Array = [["warrior", "tank"]]
	var hard: Array = [DifficultyConfig.get_default().levels[1]]
	var f3 := func(play: Dictionary) -> Dictionary:
		return BalanceSim.run_rows(50, pair, hard, true, 1.0, play).filter(func(r: Dictionary) -> bool: return int(r["floor"]) == 3)[0]
	var none: Dictionary = f3.call({"dodge": 0.0, "heal": "none", "boss_first": false})
	var first: Dictionary = f3.call({"dodge": 0.0, "heal": "none", "boss_first": true})
	var healed: Dictionary = f3.call({"dodge": 0.0, "heal": "comida", "boss_first": true})
	var dodged: Dictionary = f3.call({"dodge": 1.0, "heal": "comida", "boss_first": true})
	_expect(float(first["boss_hp_in"]) > float(none["boss_hp_in"]), "boss before the extraction: HP in %.2f vs after %.2f" % [first["boss_hp_in"], none["boss_hp_in"]])
	# juego-25: 0.9 -> 0.8. Hard now starts with x0.75 resources in the model (as in the game), so
	# the Comida no longer heals this pair to 90 % (0.86 measured).
	_expect(float(healed["boss_hp_in"]) >= 0.8 and float(healed["boss_hp_in"]) > float(first["boss_hp_in"]), "heal with Comida first: HP in %.2f vs %.2f" % [healed["boss_hp_in"], first["boss_hp_in"]])
	_expect(float(dodged["boss_win"]) > float(healed["boss_win"]), "dodging every Embestida: boss won %.2f vs %.2f" % [dodged["boss_win"], healed["boss_win"]])
	_expect(BalanceSim._play == BalanceSim.BOSS_PLAY, "run_rows restores the boss play")


## calidad-13: 5 floors x both difficulties x 1-4 players. Per-hero pressure of a
## floor stays within [PARITY_MIN, PARITY_MAX] of solo; the cap grows with the party;
## the static player count is restored; the table is deterministic.
func _check_scaling() -> void:
	var rows := BalanceSim.scaling_rows()
	_expect(rows.size() == BalanceSim.FLOORS * 4 * DifficultyConfig.get_default().levels.size(), "scaling rows: %d" % rows.size())
	var cap := {}
	for row in rows:
		var p: int = row["players"]
		_expect(float(row["parity"]) >= BalanceSim.PARITY_MIN and float(row["parity"]) <= BalanceSim.PARITY_MAX,
			"%s floor %d, %d players: parity %.2f outside [%.2f, %.2f]" % [row["difficulty"], row["floor"], p, row["parity"], BalanceSim.PARITY_MIN, BalanceSim.PARITY_MAX])
		var key: String = "%s_%d" % [row["difficulty"], row["floor"]]
		if p > 1:
			_expect(int(row["max_enemies"]) >= int(cap[key]), "%s: cap shrinks with %d players" % [key, p])
		cap[key] = row["max_enemies"]
	_expect(BalanceSim.players == 1 and BalanceSim.difficulty == null, "scaling_rows restores players/difficulty")
	_expect(rows == BalanceSim.scaling_rows(), "scaling_rows is not deterministic")
	var scaling := PlayerScaling.get_default()
	_expect(scaling.wave(3, 1) == 3 and scaling.wave(3, 4) >= 6 and scaling.wave(3, 9) == scaling.wave(3, 4), "PlayerScaling.wave: rows by players, clamped")


func _check_economy() -> void:
	var last := {}
	for row in BalanceSim.economy_rows():
		_expect(float(row["income"]) > 0.0, "floor %d: %s has no income" % [row["floor"], row["resource"]])
		_expect(float(row["sink"]) > 0.0, "floor %d: %s has nothing to spend on" % [row["floor"], row["resource"]])
		last[row["resource"]] = float(row["run_ratio"])
	for key in last:
		_expect(last[key] >= ECONOMY_RUN_RATIO.x and last[key] <= ECONOMY_RUN_RATIO.y, "%s run income/sink %.2f outside %s" % [key, last[key], ECONOMY_RUN_RATIO])


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _check_floor1_hits() -> void:
	for type in BalanceSim.pool_types(1):
		for hero_id in BalanceSim.HERO_IDS:
			var hits: int = BalanceSim.duel(hero_id, 0, type, 1)["hits_to_kill"]
			_expect(hits >= 2 and hits <= 4, "%s needs %d hits to kill %s on floor 1 (want 2-4)" % [hero_id, hits, type.id])


func _check_encounters() -> void:
	var rows := BalanceSim.encounter_rows()
	var mean_by_floor: Array[float] = []
	for f in range(1, BalanceSim.FLOORS + 1):
		mean_by_floor.append(0.0)
	for hero_id in BalanceSim.HERO_IDS:
		var previous := -1.0
		for row in rows:
			if row["hero"] != hero_id:
				continue
			var loss: float = row["loss_pct"]
			var f: int = row["floor"]
			mean_by_floor[f - 1] += loss / BalanceSim.HERO_IDS.size()
			if f == 1:
				_expect(loss <= MAX_BASIC_LOSS_PCT, "%s loses %.1f%% HP in the basic encounter (max %.1f%%)" % [hero_id, loss, MAX_BASIC_LOSS_PCT])
			if previous >= 0.0:
				_expect(loss - previous <= MAX_STEP_PCT, "%s: floor %d jumps %.1f points (max %.1f)" % [hero_id, f, loss - previous, MAX_STEP_PCT])
			if f == BalanceSim.FLOORS:
				_expect(loss <= MAX_FLOOR5_LOSS_PCT, "%s loses %.1f%% HP on floor 5 (max %.1f%%)" % [hero_id, loss, MAX_FLOOR5_LOSS_PCT])
			previous = loss
	_expect(mean_by_floor[-1] > mean_by_floor[0], "difficulty does not grow from floor 1 to 5")
	for i in range(1, mean_by_floor.size()):
		_expect(mean_by_floor[i] >= mean_by_floor[i - 1] - 5.0, "average difficulty drops %.1f points on floor %d" % [mean_by_floor[i - 1] - mean_by_floor[i], i + 1])


func _check_relic() -> void:
	var min_arrival := BalanceSim.floor_config().raider_min_arrival_sec
	var rows := BalanceSim.relic_rows()
	_expect(not rows.is_empty(), "no raider in any pool")
	for row in rows:
		var label := "floor %s %s" % [row["floor"], row["enemy"]]
		var one: float = row["destroy_1_s"]
		_expect(one >= RELIC_ONE_RAIDER_SEC.x and one <= RELIC_ONE_RAIDER_SEC.y, "%s: 1 raider destroys the Reliquia in %.0fs (want %.0f-%.0f)" % [label, one, RELIC_ONE_RAIDER_SEC.x, RELIC_ONE_RAIDER_SEC.y])
		_expect(float(row["destroy_3_s"]) >= RELIC_THREE_RAIDERS_MIN_SEC, "%s: 3 raiders destroy the Reliquia in %.0fs (min %.0f)" % [label, row["destroy_3_s"], RELIC_THREE_RAIDERS_MIN_SEC])
		_expect(float(row["arrival_min_s"]) >= min_arrival, "%s: arrives in %.1fs (< gate %.1fs)" % [label, row["arrival_min_s"], min_arrival])


func _check_towers() -> void:
	var rows := BalanceSim.tower_rows()
	_expect(not rows.is_empty(), "no tower breaker in any pool")
	for row in rows:
		var lost: float = row["defense_hp_lost_pct"]
		_expect(lost >= TOWER_HP_LOST_PCT.x and lost <= TOWER_HP_LOST_PCT.y, "floor %s %s: takes %.1f%% of a defense before dying (want %.0f-%.0f)" % [row["floor"], row["enemy"], lost, TOWER_HP_LOST_PCT.x, TOWER_HP_LOST_PCT.y])


## heroes-9: hero_matchup_rows (single target, level = floor - 1).
func _check_hero_roles() -> void:
	var by_floor: Dictionary = {}
	for row in BalanceSim.hero_matchup_rows():
		if not by_floor.has(row["floor"]):
			by_floor[row["floor"]] = {}
		by_floor[row["floor"]][row["hero"]] = row
	for f: int in by_floor:
		var rows: Dictionary = by_floor[f]
		var tank: Dictionary = rows["tank"]
		var rogue: Dictionary = rows["rogue"]
		for hero_id: String in rows:
			if hero_id == "tank":
				continue
			var other: Dictionary = rows[hero_id]
			_expect(float(tank["ttd_1_s"]) > float(other["ttd_1_s"]), "floor %d: tank must outlast %s (%.1fs vs %.1fs)" % [f, hero_id, tank["ttd_1_s"], other["ttd_1_s"]])
			_expect(float(tank["ttk_s"]) >= float(other["ttk_s"]), "floor %d: tank must kill slowest (%.2fs vs %s %.2fs)" % [f, tank["ttk_s"], hero_id, other["ttk_s"]])
		for hero_id: String in rows:
			if hero_id == "rogue":
				continue
			var other: Dictionary = rows[hero_id]
			_expect(int(rogue["hp"]) < int(other["hp"]), "floor %d: rogue must be the most fragile (%d HP vs %s %d)" % [f, rogue["hp"], hero_id, other["hp"]])
			_expect(float(rogue["dps"]) > float(other["dps"]), "floor %d: rogue must have the highest DPS (%.2f vs %s %.2f)" % [f, rogue["dps"], hero_id, other["dps"]])
			_expect(float(rogue["speed"]) > float(other["speed"]), "floor %d: rogue must be the fastest" % f)


## A dominates B when it is >= on every axis and > on at least one.
func _check_no_dominance(level: int) -> void:
	var stats: Dictionary = {}
	for hero_id in BalanceSim.HERO_IDS:
		var s := BalanceSim.hero_stats(hero_id, level)
		stats[hero_id] = [float(s["ehp"]), float(s["dps"]), float(s["range"])]
	for a in BalanceSim.HERO_IDS:
		for b in BalanceSim.HERO_IDS:
			if a == b:
				continue
			var all_ge := true
			var any_gt := false
			for i in 3:
				if stats[a][i] < stats[b][i]:
					all_ge = false
				elif stats[a][i] > stats[b][i]:
					any_gt = true
			_expect(not (all_ge and any_gt), "level %d: %s is strictly better than %s (EHP/DPS/range)" % [level, a, b])

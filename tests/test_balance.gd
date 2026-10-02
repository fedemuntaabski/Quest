extends SceneTree

## Balance targets (docs/BALANCE.md) checked on BalanceSim over the real .tres data:
##  - a floor-1 enemy dies in 2-4 hero hits (every hero, every floor-1 type);
##  - the basic (floor-1) encounter costs a hero at most 1/3 of its HP;
##  - difficulty grows floor by floor without sudden jumps;
##  - the Nexo survives long enough to react to the alert, but falls if ignored;
##  - no hero is strictly better than another (HP, DPS, range), at level 0 and 5.
##   godot --headless --path . --script res://tests/test_balance.gd

const MAX_BASIC_LOSS_PCT := 33.4
const MAX_STEP_PCT := 20.0
const MAX_FLOOR5_LOSS_PCT := 70.0
const NEXO_ONE_RAIDER_SEC := Vector2(15.0, 45.0)
const NEXO_THREE_RAIDERS_MIN_SEC := 6.0

var failures: Array[String] = []


func _initialize() -> void:
	_check_floor1_hits()
	_check_encounters()
	_check_nexo()
	_check_no_dominance(0)
	_check_no_dominance(5)
	_expect(BalanceSim.encounter_rows() == BalanceSim.encounter_rows(), "BalanceSim is not deterministic")
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_balance: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


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


func _check_nexo() -> void:
	var min_arrival := BalanceSim.floor_config().raider_min_arrival_sec
	var rows := BalanceSim.nexo_rows()
	_expect(not rows.is_empty(), "no raider in any pool")
	for row in rows:
		var label := "floor %s %s" % [row["floor"], row["enemy"]]
		var one: float = row["destroy_1_s"]
		_expect(one >= NEXO_ONE_RAIDER_SEC.x and one <= NEXO_ONE_RAIDER_SEC.y, "%s: 1 raider destroys the Nexo in %.0fs (want %.0f-%.0f)" % [label, one, NEXO_ONE_RAIDER_SEC.x, NEXO_ONE_RAIDER_SEC.y])
		_expect(float(row["destroy_3_s"]) >= NEXO_THREE_RAIDERS_MIN_SEC, "%s: 3 raiders destroy the Nexo in %.0fs (min %.0f)" % [label, row["destroy_3_s"], NEXO_THREE_RAIDERS_MIN_SEC])
		_expect(float(row["arrival_min_s"]) >= min_arrival, "%s: arrives in %.1fs (< gate %.1fs)" % [label, row["arrival_min_s"], min_arrival])


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

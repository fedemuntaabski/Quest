extends SceneTree

## juego-28 sweep (not a test): the two walls left, by cause.
##   godot --headless --path . --script res://tests/tools/sweep_juego28.gd -- [runs]
## 1. Hard, floors 1-3, the six pairs: cause columns + what-ifs (doors, floor-3 boss, Comida,
##    levels, x0.75 start resources, each Hard multiplier back to Normal).
## 2. The four, Normal, floors 3-5: co-op of 4 (PlayerScaling of 4) and offline (scaling of 1),
##    cause columns + what-ifs (Comida, levels, scaling).

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]
const CAUSE_COLS := ["win_rate", "heroes", "lvl_gap", "food_short", "food", "hp_start", "door_fights", "dmg_door_pct", "die_door", "boss_hp_in", "boss_win", "die_boss", "dmg_boss_pct", "die_extr", "dmg_extr_pct", "items"]
## name -> [play what-ifs, DifficultyLevel overrides]
const HARD_WHATIFS := {
	"base": [{}, {}],
	"free Comida": [{"free_food": true}, {}],
	"free levels": [{"free_levels": true}, {}],
	"no door waves on 3": [{"no_doors": 3}, {}],
	"no boss on 3": [{"no_boss": 3}, {}],
	"no extraction on 3": [{"no_extr": 3}, {}],
	"start resources x1": [{}, {"start_resource_mult": 1.0}],
	"enemy HP x1": [{}, {"hp_mult": 1.0}],
	"enemy damage x1": [{}, {"damage_mult": 1.0}],
	"threat x1": [{}, {"threat_mult": 1.0}],
	"no extra cap": [{}, {"extra_max_enemies": 0}],
}
const FOUR_WHATIFS := {
	"co-op 4": {},
	"co-op 4, free Comida": {"free_food": true},
	"co-op 4, free levels": {"free_levels": true},
	"co-op 4, no door waves on 4": {"no_doors": 4},
	"co-op 4, no boss on 5": {"no_boss": 5},
	"co-op 4, scaling of 2 players": {"players": 2},
	"offline 4 (scaling of 1)": {"players": 1},
	"offline 4, free Comida": {"players": 1, "free_food": true},
	"offline 4, free levels": {"players": 1, "free_levels": true},
}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0]) if a.size() > 0 else 200
	var levels := DifficultyConfig.get_default().levels
	var normal: DifficultyLevel = levels[0]
	var hard: DifficultyLevel = levels[1]
	var four: Array = [BalanceSim.HERO_IDS.duplicate()]
	print("\n## Hard, floors 1-3 by cause (%d runs, items on)" % runs)
	_print(BalanceSim.run_rows(runs, PAIRS, [hard], true, BalanceSim.BOSS_NEAR_TOWERS, {}), [1, 2, 3])
	print("\n## Hard what-ifs (pairs): floor 1 / 2 / 3 / 4, floor 3 of those who reach it")
	print("| what-if | f1 | f2 | f3 | f4 | f3 of reached |")
	print("|---|---|---|---|---|---|")
	for name: String in HARD_WHATIFS:
		var w: Array = HARD_WHATIFS[name]
		var keep := {}
		for k: String in w[1]:
			keep[k] = hard.get(k)
			hard.set(k, w[1][k])
		var rows := BalanceSim.run_rows(runs, PAIRS, [hard], true, BalanceSim.BOSS_NEAR_TOWERS, w[0])
		for k: String in keep:
			hard.set(k, keep[k])
		print("| %s | %s | %s | %s | %s | %s |" % [name, _mean(rows, 1), _mean(rows, 2), _mean(rows, 3), _mean(rows, 4), _reach(rows, 3)])
	print("\n## The four, Normal, floors 3-5 by cause (%d runs, items on)" % runs)
	for name: String in ["co-op 4", "offline 4 (scaling of 1)"]:
		print("\n### " + name)
		_print(BalanceSim.run_rows(runs, four, [normal], true, BalanceSim.BOSS_NEAR_TOWERS, FOUR_WHATIFS[name]), [3, 4, 5])
	print("\n## The four what-ifs (Normal): floor 3 / 4 / 5, floor 4 of those who reach it")
	print("| what-if | f3 | f4 | f5 | f4 of reached |")
	print("|---|---|---|---|---|")
	for name: String in FOUR_WHATIFS:
		var rows := BalanceSim.run_rows(runs, four, [normal], true, BalanceSim.BOSS_NEAR_TOWERS, FOUR_WHATIFS[name])
		print("| %s | %s | %s | %s | %s |" % [name, _mean(rows, 3), _mean(rows, 4), _mean(rows, 5), _reach(rows, 4)])
	quit(0)


func _print(rows: Array[Dictionary], floors: Array) -> void:
	print("| party | floor | " + " | ".join(CAUSE_COLS) + " |")
	for row in rows:
		if int(row["floor"]) in floors:
			print("| %s | %d | %s |" % [row["party"], row["floor"], " | ".join(CAUSE_COLS.map(func(c: String) -> String: return str(row[c])))])


func _mean(rows: Array[Dictionary], f: int) -> String:
	var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == f)
	return "%.0f %%" % (of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r["win_rate"]), 0.0) / of.size() * 100.0)


## Floor f wins / floor f - 1 wins, over all the parties.
func _reach(rows: Array[Dictionary], f: int) -> String:
	var won := 0.0
	var reached := 0.0
	for r in rows:
		if int(r["floor"]) == f:
			won += float(r["win_rate"])
		elif int(r["floor"]) == f - 1:
			reached += float(r["win_rate"])
	return "%.0f %%" % (won / maxf(reached, 0.001) * 100.0)

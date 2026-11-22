extends SceneTree

## juego-29 sweep (not a test): Hard floor 4 by cause, and offline pairs that recruit.
##   godot --headless --path . --script res://tests/tools/sweep_juego29.gd -- [runs] [section]
## section 1: Hard floors 3-5, the six pairs and co-op 4: cause columns + floor-4 what-ifs.
## section 2: offline pairs recruiting 0 / 1 / 2 (BalanceSim "recruit"), Normal and Hard, next to
##            the juego-28 approximation (the four from floor 1, scaling of 1).
## No section = both.

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]
const CAUSE_COLS := ["win_rate", "heroes", "lvl_gap", "food_short", "food", "iron", "hp_start", "door_fights", "dmg_door_pct", "die_door", "boss_hp_in", "boss_win", "die_boss", "dmg_boss_pct", "die_extr", "dmg_extr_pct", "items"]
## name -> [play what-ifs, DifficultyLevel overrides]
const RECRUIT_CASES := {
	"pairs, no recruit": {},
	"pairs, up to 1": {"recruit": 1},
	"pairs, up to 2": {"recruit": 2},
	"pairs, up to 2, half price": {"recruit": 2, "recruit_cost_mult": 0.5},
	"pairs, up to 2, free": {"recruit": 2, "recruit_cost_mult": 0.0},
	"pairs, up to 2, at party level": {"recruit": 2, "recruit_levels": true},
	"pairs, up to 2, free, at party level": {"recruit": 2, "recruit_cost_mult": 0.0, "recruit_levels": true},
	"the four from floor 1 (juego-28)": {"players": 1},
}
const WHATIFS := {
	"base": [{}, {}],
	"free Comida": [{"free_food": true}, {}],
	"free levels": [{"free_levels": true}, {}],
	"full HP at floor 4 start": [{"full_hp": 4}, {}],
	"no door waves on 4": [{"no_doors": 4}, {}],
	"no extraction on 4": [{"no_extr": 4}, {}],
	"no items": [{"items": false}, {}],
	"start resources x1": [{}, {"start_resource_mult": 1.0}],
	"enemy HP x1": [{}, {"hp_mult": 1.0}],
	"enemy damage x1": [{}, {"damage_mult": 1.0}],
	"threat x1": [{}, {"threat_mult": 1.0}],
	"no extra cap": [{}, {"extra_max_enemies": 0}],
}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0]) if a.size() > 0 else 200
	var section := int(a[1]) if a.size() > 1 else 0
	var levels := DifficultyConfig.get_default().levels
	var normal: DifficultyLevel = levels[0]
	var hard: DifficultyLevel = levels[1]
	var four: Array = [BalanceSim.HERO_IDS.duplicate()]
	if section in [0, 1]:
		print("\n## Hard, floors 3-5 by cause (%d runs, items on)" % runs)
		_print(BalanceSim.run_rows(runs, PAIRS + four, [hard], true, BalanceSim.BOSS_NEAR_TOWERS, {}), [3, 4, 5])
		print("\n## Hard what-ifs: floors 3 / 4 / 5 and floor 4 of those who reach it")
		print("| what-if | pairs f3 | f4 | f5 | f4 of reached | co-op 4 f3 | f4 | f5 | f4 of reached |")
		print("|---|---|---|---|---|---|---|---|---|")
		for name: String in WHATIFS:
			var w: Array = WHATIFS[name]
			var keep := {}
			for k: String in w[1]:
				keep[k] = hard.get(k)
				hard.set(k, w[1][k])
			var p := BalanceSim.run_rows(runs, PAIRS, [hard], true, BalanceSim.BOSS_NEAR_TOWERS, w[0])
			var q := BalanceSim.run_rows(runs, four, [hard], true, BalanceSim.BOSS_NEAR_TOWERS, w[0])
			for k: String in keep:
				hard.set(k, keep[k])
			print("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [name, _mean(p, 3), _mean(p, 4), _mean(p, 5), _reach(p, 4), _mean(q, 3), _mean(q, 4), _mean(q, 5), _reach(q, 4)])
	if section in [0, 2]:
		print("\n## Offline with recruits (%d runs): floors 1 / 2 / 3 / 4 / 5, heroes on floors 3 / 4 / 5" % runs)
		print("| difficulty | party | f1 | f2 | f3 | f4 | f5 | heroes f3 | f4 | f5 |")
		print("|---|---|---|---|---|---|---|---|---|---|")
		for level: DifficultyLevel in [normal, hard]:
			for name: String in RECRUIT_CASES:
				var parties: Array = four if name.begins_with("the four") else PAIRS
				var play: Dictionary = RECRUIT_CASES[name]
				var rows := BalanceSim.run_rows(runs, parties, [level], true, BalanceSim.BOSS_NEAR_TOWERS, play)
				print("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [level.id, name, _mean(rows, 1), _mean(rows, 2), _mean(rows, 3), _mean(rows, 4), _mean(rows, 5), _col(rows, 3, "heroes"), _col(rows, 4, "heroes"), _col(rows, 5, "heroes")])
		print("\n## Offline pairs, up to 2 recruits, by cause (Normal and Hard, floors 3-5)")
		_print(BalanceSim.run_rows(runs, PAIRS, [normal, hard], true, BalanceSim.BOSS_NEAR_TOWERS, {"recruit": 2}), [3, 4, 5])
	quit(0)


func _print(rows: Array[Dictionary], floors: Array) -> void:
	print("| difficulty | party | floor | " + " | ".join(CAUSE_COLS) + " |")
	print("|---|---|---|" + "---|".repeat(CAUSE_COLS.size()))
	for row in rows:
		if int(row["floor"]) in floors:
			print("| %s | %s | %d | %s |" % [row["difficulty"], row["party"], row["floor"], " | ".join(CAUSE_COLS.map(func(c: String) -> String: return str(row[c])))])


func _mean(rows: Array[Dictionary], f: int) -> String:
	var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == f)
	return "%.0f" % (of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r["win_rate"]), 0.0) / of.size() * 100.0)


## Mean of a column on floor f over the parties (weighted by the runs that played it).
func _col(rows: Array[Dictionary], f: int, key: String) -> String:
	var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == f)
	return "%.2f" % (of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r[key]), 0.0) / of.size())


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

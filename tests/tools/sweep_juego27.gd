extends SceneTree

## juego-27 sweep (not a test): where floor 5 is lost, by cause.
##   godot --headless --path . --script res://tests/tools/sweep_juego27.gd -- [runs]
## Prints markdown tables (docs/BALANCE.md «Piso 5 por causa»).

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]
const CAUSE_COLS := ["win_rate", "heroes", "lvl_gap", "food_short", "hp_start", "door_fights", "dmg_door_pct", "die_door", "hp_exit", "boss_hp_in", "boss_win", "die_boss", "dmg_boss_pct", "die_extr", "items"]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0]) if a.size() > 0 else 200
	var levels := DifficultyConfig.get_default().levels
	var parties: Array = PAIRS.duplicate()
	parties.append(BalanceSim.HERO_IDS.duplicate())
	for level in levels:
		print("\n## %s: floors 4-5 by cause (%d runs, items on)" % [level.id, runs])
		_print(BalanceSim.run_rows(runs, parties, [level], true, BalanceSim.BOSS_NEAR_TOWERS, {}), [4, 5])
	print("\n## What decides floor 5 (pairs): floor 3 / 4 / 5 / floor 5 of those who reach it")
	var whatifs := {
		"base": {}, "free_food": {"free_food": true}, "no door waves on 5": {"no_doors": 5},
		"no extraction on 5": {"no_extr": 5}, "no boss on 5": {"no_boss": 5},
		"no doors + no boss on 5": {"no_doors": 5, "no_boss": 5},
	}
	for level in levels:
		for name: String in whatifs:
			var rows := BalanceSim.run_rows(runs, PAIRS, [level], true, BalanceSim.BOSS_NEAR_TOWERS, whatifs[name])
			print("| %s | %s | %s | %s | %s | %s |" % [level.id, name, _mean(rows, 3), _mean(rows, 4), _mean(rows, 5), _reach(rows, 5)])
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

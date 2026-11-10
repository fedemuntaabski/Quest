extends SceneTree

## juego-25 sweep (not a test): where floor 4 is lost and why Mago + Pícaro never beats the boss.
##   godot --headless --path . --script res://tests/tools/sweep_juego25.gd
## Prints markdown tables (docs/BALANCE.md «Piso 4 por causa»). Lives here because BalanceSim
## runs >1000x slower from a script outside res://.

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]
const RUNS := 200
const CAUSE_COLS := ["win_rate", "heroes", "lvl_gap", "food_short", "hp_start", "door_fights", "dmg_door_pct", "die_door", "hp_exit", "die_boss", "dmg_extr_pct", "die_extr", "items"]


func _initialize() -> void:
	var levels := DifficultyConfig.get_default().levels
	var parties: Array = PAIRS.duplicate()
	parties.append(BalanceSim.HERO_IDS.duplicate())
	for level in levels:
		for items in [false, true]:
			print("\n## %s, items %s: floors 3-5 by cause (%d runs)" % [level.id, items, RUNS])
			_print(BalanceSim.run_rows(RUNS, parties, [level], true, BalanceSim.BOSS_NEAR_TOWERS, {"items": items}), [3, 4, 5])
	print("\n## What decides floor 4 (pairs, items on): mean floor-4 win rate of the runs that reach it")
	var whatifs := {
		"base": {}, "free_food": {"free_food": true}, "no door waves on 4": {"no_doors": 4},
		"no extraction waves on 4": {"no_extr": 4}, "neither": {"no_doors": 4, "no_extr": 4},
	}
	for level in levels:
		for name: String in whatifs:
			var rows := BalanceSim.run_rows(RUNS, PAIRS, [level], true, BalanceSim.BOSS_NEAR_TOWERS, whatifs[name])
			print("| %s | %s | floor 3 %s | floor 4 %s | floor 4 of those who reach it %s | floor 5 %s |" % [level.id, name, _mean(rows, 3), _mean(rows, 4), _reach(rows, 4), _mean(rows, 5)])
	print("\n## Mago + Pícaro against the floor-3 boss (Normal)")
	for near in [0.0, 0.5, 1.0]:
		for play: Dictionary in [{"items": false}, {"items": true}, {"items": true, "dodge": 1.0}]:
			var row: Dictionary = BalanceSim.run_rows(RUNS, [["mage", "rogue"]], [levels[0]], true, near, play).filter(func(r: Dictionary) -> bool: return int(r["floor"]) == 3)[0]
			print("| boss_near %.1f | %s | HP in %.2f | boss fights won %.2f | floor 3 %.2f |" % [near, play, row["boss_hp_in"], row["boss_win"], row["win_rate"]])
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

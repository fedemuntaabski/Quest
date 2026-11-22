extends SceneTree

## juego-28 sweep (not a test): floors 3 / 4 / 5 with the shipped data, pairs (mean), trios
## (co-op 3, mean) and the four (co-op 4), both difficulties, plus the four offline (scaling of 1).
##   godot --headless --path . --script res://tests/tools/sweep_juego28_final.gd -- [runs]

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0]) if a.size() > 0 else 200
	var four: Array = [BalanceSim.HERO_IDS.duplicate()]
	var trios: Array = []
	for i in 4:
		var t: Array = BalanceSim.HERO_IDS.duplicate()
		t.remove_at(i)
		trios.append(t)
	print("| Dificultad | Pares 3 / 4 / 5 | Tríos (co-op 3) | Los 4 (co-op 4) | Los 4 sin conexión |")
	print("|---|---|---|---|---|")
	for level: DifficultyLevel in DifficultyConfig.get_default().levels:
		var cells: Array[String] = []
		for job in [[PAIRS, {}], [trios, {}], [four, {}], [four, {"players": 1}]]:
			var rows := BalanceSim.run_rows(runs, job[0], [level], true, BalanceSim.BOSS_NEAR_TOWERS, job[1])
			cells.append("%s / %s / %s" % [_mean(rows, 3), _mean(rows, 4), _mean(rows, 5)])
		print("| %s | %s |" % [level.id, " | ".join(cells)])
	quit(0)


func _mean(rows: Array[Dictionary], f: int) -> String:
	var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == f)
	return "%.0f" % (of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r["win_rate"]), 0.0) / of.size() * 100.0)

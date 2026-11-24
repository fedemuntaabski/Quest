extends SceneTree

## juego-41 sweep (not a test): pairs (mean of 6), trios (co-op 3, mean of 4) and the four
## (co-op 4), Normal and Difícil, floors 1-5 with the shipped data; writes docs/balance/juego41_<tag>_runs.csv.
##   godot --headless --path . --script res://tests/tools/sweep_juego41.gd -- [runs] [tag] [play json]
## A play json (BalanceSim.BOSS_PLAY keys, plus "towers": false and "boss_near": x for run_rows) runs a what-if.

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]
const COLS := ["win_rate", "towers", "dmg_by_towers_pct", "die_door", "die_boss", "die_extr", "die_relic", "relic_hp_end"]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0]) if a.size() > 0 else 200
	var tag: String = a[1] if a.size() > 1 else "despues"
	var play: Dictionary = JSON.parse_string(a[2]) if a.size() > 2 else {}
	var trios: Array = []
	for i in 4:
		var t: Array = BalanceSim.HERO_IDS.duplicate()
		t.remove_at(i)
		trios.append(t)
	var all: Array[Dictionary] = []
	print("| Dificultad | Grupo | Victoria 1/2/3/4/5 (%) | Defensas 1/3/5 | Daño de Defensas 1/3/5 (%) | Muere por la Reliquia 3/5 (%) |")
	print("|---|---|---|---|---|---|")
	for level: DifficultyLevel in DifficultyConfig.get_default().levels:
		for job in [["pares", PAIRS], ["tríos", trios], ["los 4", [BalanceSim.HERO_IDS.duplicate()]]]:
			var rows := BalanceSim.run_rows(runs, job[1], [level], play.get("towers", true), play.get("boss_near", BalanceSim.BOSS_NEAR_TOWERS), play)
			all.append_array(rows)
			print("| %s | %s | %s | %s | %s | %s |" % [level.id, job[0], _m(rows, "win_rate", [1, 2, 3, 4, 5], 100.0),
				_m(rows, "towers", [1, 3, 5], 1.0, "%.1f"), _m(rows, "dmg_by_towers_pct", [1, 3, 5], 1.0), _m(rows, "die_relic", [3, 5], 100.0)])
	var f := FileAccess.open("res://docs/balance/juego41_%s_runs.csv" % tag, FileAccess.WRITE)
	f.store_string(BalanceSim.to_csv(all))
	f.close()
	quit(0)


## Mean of `key` over the rows of each floor (missing column = "-").
func _m(rows: Array[Dictionary], key: String, floors: Array, scale: float, fmt := "%.0f") -> String:
	var out: Array[String] = []
	for fl: int in floors:
		var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == fl)
		if not of[0].has(key):
			out.append("-")
			continue
		out.append(fmt % (of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r[key]), 0.0) / of.size() * scale))
	return " / ".join(out)

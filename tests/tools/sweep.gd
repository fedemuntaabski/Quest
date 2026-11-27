extends SceneTree

## BalanceSim sweep (not a test): every pair, trio (co-op 3) and four (co-op 4) of BalanceSim.HERO_IDS
## (personajes-46: 6 heroes = 15 / 20 / 15 groups) plus "pares 4" = the 6 pairs of the first four heroes
## (the pre-personajes-46 "pares", to compare old tables), Normal and Difícil, with the shipped data.
## Prints one markdown row per group (mean of its parties).
##   godot --headless --path . --script res://tests/tools/sweep.gd -- [runs] [tag] [play json] [cols]
## runs: default 200. tag: writes docs/balance/<tag>_runs.csv ("" or "-" = no CSV).
## play json: BalanceSim.BOSS_PLAY keys, plus "towers": false and "boss_near": x for run_rows.
## cols: comma list of <row key>@<floors joined by />, default "win_rate@1/2/3/4/5"
##   (e.g. "win_rate@3/4/5,towers@1/3/5,dmg_by_towers_pct@1/3/5,relic_hp_end@3/5").
## Shares (win_rate, boss_win, die_*) print ×100 as %, the rest with one decimal.
## The juego-25..30 one-off sweeps live in git history (docs/archive/BALANCE_HISTORIA.md).

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0]) if a.size() > 0 else 200
	var tag: String = a[1] if a.size() > 1 else ""
	var play: Dictionary = JSON.parse_string(a[2]) if a.size() > 2 and a[2] != "" else {}
	var cols: Array = []
	for spec: String in (a[3] if a.size() > 3 else "win_rate@1/2/3/4/5").split(","):
		var p := spec.split("@")
		cols.append([p[0], Array(p[1].split("/")).map(func(s: String) -> int: return int(s))])
	var ids: Array = BalanceSim.HERO_IDS.duplicate()
	var head := "| Dificultad | Grupo |"
	for c in cols:
		head += " %s %s |" % [c[0], "/".join(c[1])]
	print(head)
	print("|---|---|" + "---|".repeat(cols.size()))
	var all: Array[Dictionary] = []
	for level: DifficultyLevel in DifficultyConfig.get_default().levels:
		for job in [["pares 4", PAIRS], ["pares", BalanceSim._combos(ids, 2)], ["tríos", BalanceSim._combos(ids, 3)], ["de a 4", BalanceSim._combos(ids, 4)]]:
			var rows := BalanceSim.run_rows(runs, job[1], [level], play.get("towers", true), play.get("boss_near", BalanceSim.BOSS_NEAR_TOWERS), play)
			all.append_array(rows)
			var line := "| %s | %s |" % [level.id, job[0]]
			for c in cols:
				line += " %s |" % _m(rows, c[0], c[1])
			print(line)
	if tag != "" and tag != "-":
		var f := FileAccess.open("res://docs/balance/%s_runs.csv" % tag, FileAccess.WRITE)
		f.store_string(BalanceSim.to_csv(all))
		f.close()
	quit(0)


## Mean of `key` over the rows of each floor.
func _m(rows: Array[Dictionary], key: String, floors: Array) -> String:
	var pct := key in ["win_rate", "boss_win"] or key.begins_with("die_")
	var out: Array[String] = []
	for fl: int in floors:
		var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == fl)
		var mean: float = of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r.get(key, 0.0)), 0.0) / maxf(of.size(), 1)
		out.append(("%.0f" % (mean * 100.0)) if pct else ("%.1f" % mean))
	return " / ".join(out)

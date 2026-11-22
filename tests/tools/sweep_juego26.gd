extends SceneTree

## juego-26 sweep (not a test): Comida levers against the floor-4 wall.
##   godot --headless --path . --script res://tests/tools/sweep_juego26.gd -- <runs> <normal|hard> <descend> <boss> <base_cost> <cost_growth>
## One config per process (run several in parallel); prints one "ROW {json}" line:
## mean win rate per floor over the six pairs, floor 4 among those who reach it, and per pair.
## Overrides are in memory only (FloorConfig.food_bonus_on_descend / boss_food_reward,
## UpgradeConfig base_cost / cost_growth on the shared and the Paladín configs).

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0])
	var cfg := BalanceSim.floor_config()
	cfg.food_bonus_on_descend = int(a[2])
	cfg.boss_food_reward = int(a[3])
	for path in [BalanceSim.UPGRADE_CONFIG_PATH, "res://resources/upgrades/tank_upgrade_config.tres"]:
		var up := load(path) as UpgradeConfig
		up.base_cost = int(a[4])
		up.cost_growth = float(a[5])
	var level: DifficultyLevel = null
	for l in DifficultyConfig.get_default().levels:
		if l.id == a[1]:
			level = l
	var rows := BalanceSim.run_rows(runs, PAIRS, [level], true, BalanceSim.BOSS_NEAR_TOWERS, {"items": true})
	var out := {"cfg": a, "floor": [], "reach4": 0.0, "pair4": {}, "pair_reach4": {}, "food_short4": 0.0}
	var won := [0.0, 0.0, 0.0, 0.0, 0.0]
	for r in rows:
		won[int(r["floor"]) - 1] += float(r["win_rate"]) / PAIRS.size()
		if int(r["floor"]) == 4:
			out["pair4"][r["party"]] = r["win_rate"]
			out["food_short4"] += float(r["food_short"]) / PAIRS.size()
	for r in rows:
		if int(r["floor"]) == 4:
			var prev: Dictionary = rows.filter(func(x: Dictionary) -> bool: return x["party"] == r["party"] and int(x["floor"]) == 3)[0]
			out["pair_reach4"][r["party"]] = snappedf(float(r["win_rate"]) / maxf(float(prev["win_rate"]), 0.001), 0.01)
	out["floor"] = won.map(func(w: float) -> float: return snappedf(w, 0.01))
	out["reach4"] = snappedf(won[3] / maxf(won[2], 0.001), 0.01)
	print("ROW " + JSON.stringify(out))
	quit(0)

extends SceneTree
## personajes-46 scratch probe (not committed): floor-3 boss near/dark on Hard for warrior+tank,
## with the new enemies' numbers overridden from the args: shot_damage hp_mult heal weight3.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var pumpkin := load("res://resources/enemies/pumpkin.tres") as EnemyType
	var swampy := load("res://resources/enemies/swampy.tres") as EnemyType
	var cfg := BalanceSim.floor_config()
	var keep := [pumpkin, swampy, cfg]
	if args.size() >= 4:
		pumpkin.shot_damage = int(args[0])
		pumpkin.hp_mult = float(args[1])
		swampy.heal_amount = int(args[2])
		swampy.hp_mult = float(args[3])
	var pair: Array = [["warrior", "tank"]]
	for lvl in [1]:
		var level: Array = [DifficultyConfig.get_default().levels[lvl]]
		var w := []
		for near in [0.0, 1.0]:
			var rows := BalanceSim.run_rows(200, pair, level, true, near)
			w.append(rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == 3)[0]["win_rate"])
		print("args %s level %d: dark %.2f near %.2f diff %.2f" % [args, lvl, w[0], w[1], w[1] - w[0]])
	keep.clear()
	quit()

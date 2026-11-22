extends SceneTree
## juego-27: where BalanceSim.run_rows spends its time with items on.
## godot --headless --path . --script res://tests/tools/bench_balancesim.gd -- [runs]

const Sim := preload("res://tools/BalanceSim.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 20
	var party := [["warrior", "mage"]]
	var normal: Array = [DifficultyConfig.get_default().levels[1]]
	Sim.difficulty = normal[0]
	var n := 2000
	var t := Time.get_ticks_usec()
	for i in n:
		Sim.hero_stats("warrior", 2, {"attack_damage": 3, "armor": 2})
	_p("hero_stats", t, n)
	t = Time.get_ticks_usec()
	for i in n:
		Sim.armor_ehp_mult(2, 3)
	_p("armor_ehp_mult", t, n)
	t = Time.get_ticks_usec()
	for i in n:
		Sim._gear_power("warrior", 2, 3, {"attack_damage": 3, "armor": 2})
	_p("_gear_power", t, n)
	var mods := {"attack_damage": 3, "armor": 2, "hp": 10}
	t = Time.get_ticks_usec()
	for i in n:
		mods.hash()
	_p("mods.hash", t, n)
	var cfg := Sim.floor_config()
	t = Time.get_ticks_usec()
	for i in 50:
		MapGenerator.generate_floor(i, cfg, 3)
	_p("generate_floor", t, 50)
	Sim.difficulty = null
	for items in [false, true]:
		t = Time.get_ticks_usec()
		var rows := Sim.run_rows(runs, party, normal, true, Sim.BOSS_NEAR_TOWERS, {"items": items})
		var floors := 0.0
		for r: Dictionary in rows:
			floors += float(r["win_rate"])
		print("run_rows items=%s: %.2f s, floors won/run %.2f" % [items, (Time.get_ticks_usec() - t) / 1e6, floors])
	quit(0)


func _p(what: String, t: int, n: int) -> void:
	print("%s: %.1f us/call" % [what, float(Time.get_ticks_usec() - t) / n])

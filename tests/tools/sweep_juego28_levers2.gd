extends SceneTree

## juego-28 sweep (not a test): second round of levers, in memory only.
##   godot --headless --path . --script res://tests/tools/sweep_juego28_levers2.gd -- [runs]
## Hard: bosses without Hard's multipliers. Co-op four: extra Comida on each descent (BOSS_PLAY
## "extra_food" from floor 2 to "extra_food_to"), alone or with a smaller wave.

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]
const CONFIGS := {
	"base": {},
	"jefes sin vida ni daño de Difícil": {"boss_hard": true, "boss_hard_dmg": true},
	"jefes sin vida ni daño de Difícil + inicio x1": {"boss_hard": true, "boss_hard_dmg": true, "hard_start_resource_mult": 1.0},
	"jefes sin vida de Difícil + daño Difícil 1,1": {"boss_hard": true, "hard_damage_mult": 1.1},
	"Jefe orco -15 % vida + jefes sin vida de Difícil": {"boss3_mult": 0.85, "boss_hard": true},
	"co-op 4: +15 Comida al bajar (2-5)": {"play4": {"extra_food": 15}},
	"co-op 4: +20 Comida al bajar (2-5)": {"play4": {"extra_food": 20}},
	"co-op 4: +30 Comida al bajar (2-3)": {"play4": {"extra_food": 30, "extra_food_to": 3}},
	"co-op 4: +20 Comida al bajar (2-5) + oleada x1,75": {"play4": {"extra_food": 20}, "wave4": 1.75},
	"co-op 4: +15 Comida al bajar (2-5) + oleada x1,5": {"play4": {"extra_food": 15}, "wave4": 1.5},
}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0]) if a.size() > 0 else 200
	var cfg := BalanceSim.floor_config()
	var scaling := PlayerScaling.get_default()
	var boss3: EnemyType = cfg.theme(3).boss
	var boss5: EnemyType = cfg.theme(5).boss
	var levels := DifficultyConfig.get_default().levels
	var hard: DifficultyLevel = levels[1]
	var keep := {"b3": boss3.base_hp, "b5": boss5.base_hp, "d3": boss3.damage_mult, "d5": boss5.damage_mult, "wave": scaling.wave_mult.duplicate(),
		"dmg": hard.damage_mult, "start": hard.start_resource_mult}
	var four: Array = [BalanceSim.HERO_IDS.duplicate()]
	var trios: Array = []
	for i in 4:
		var t: Array = BalanceSim.HERO_IDS.duplicate()
		t.remove_at(i)
		trios.append(t)
	print("| Cambio | Normal pares 3 / 4 / 5 | Difícil pares 3 / 4 / 5 | Normal los 4 3 / 4 / 5 | Difícil los 4 3 / 4 / 5 | Normal tríos 3 / 4 / 5 |")
	print("|---|---|---|---|---|---|")
	for name: String in CONFIGS:
		var c: Dictionary = CONFIGS[name]
		hard.damage_mult = c.get("hard_damage_mult", keep["dmg"])
		hard.start_resource_mult = c.get("hard_start_resource_mult", keep["start"])
		var w: PackedFloat32Array = keep["wave"].duplicate()
		w[3] = c.get("wave4", w[3])
		scaling.wave_mult = w
		var cells: Array[String] = []
		for job in [[PAIRS, levels[0]], [PAIRS, hard], [four, levels[0]], [four, hard], [trios, levels[0]]]:
			var level: DifficultyLevel = job[1]
			var on_hard: bool = level == hard
			boss3.base_hp = roundi(keep["b3"] * float(c.get("boss3_mult", 1.0)) / (hard.hp_mult if on_hard and c.get("boss_hard", false) else 1.0))
			boss5.base_hp = roundi(keep["b5"] / (hard.hp_mult if on_hard and c.get("boss_hard", false) else 1.0))
			boss3.damage_mult = keep["d3"] / (hard.damage_mult if on_hard and c.get("boss_hard_dmg", false) else 1.0)
			boss5.damage_mult = keep["d5"] / (hard.damage_mult if on_hard and c.get("boss_hard_dmg", false) else 1.0)
			var play: Dictionary = c.get("play4", {}) if job[0] == four else {}
			var rows := BalanceSim.run_rows(runs, job[0], [level], true, BalanceSim.BOSS_NEAR_TOWERS, play)
			cells.append("%s / %s / %s" % [_mean(rows, 3), _mean(rows, 4), _mean(rows, 5)])
		print("| %s | %s |" % [name, " | ".join(cells)])
	boss3.base_hp = keep["b3"]
	boss5.base_hp = keep["b5"]
	quit(0)


func _mean(rows: Array[Dictionary], f: int) -> String:
	var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == f)
	return "%.0f" % (of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r["win_rate"]), 0.0) / of.size() * 100.0)

extends SceneTree

## juego-29 sweep (not a test): levers for Hard floor 4 and offline recruits, in memory only.
##   godot --headless --path . --script res://tests/tools/sweep_juego29_levers.gd -- [runs] [lever names, ';'-separated]
## Per lever, floors 3 / 4 / 5 on Normal and Hard: pairs, co-op trios, co-op four and offline pairs
## that recruit up to 2 (BalanceSim "recruit"). "hard_food" = Comida on each descent on Hard only
## (BOSS_PLAY "extra_food", a DifficultyLevel field if picked).

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]
const CONFIGS := {
	"base": {},
	"rescate sin +5 por piso": {"per_floor": 0},
	"rescate a mitad de precio": {"costs": {"food": 8, "iron": 10}},
	"rescate también por 15 Saber": {"costs": {"food": 15, "iron": 20, "lore": 15}},
	"rescate sin +5 por piso, entra con el nivel del grupo": {"per_floor": 0, "recruit_levels": true},
	"rescate por 15 Saber, entra con el nivel del grupo": {"costs": {"food": 15, "iron": 20, "lore": 15}, "recruit_levels": true},
	"Difícil: inicio x1": {"hard_start": 1.0},
	"Difícil: +10 Comida al bajar": {"hard_food": 10},
	"Difícil: +15 Comida al bajar": {"hard_food": 15},
	"Difícil: +20 Comida al bajar": {"hard_food": 20},
	"Difícil: +15 Comida al bajar + inicio x1": {"hard_food": 15, "hard_start": 1.0},
	"Difícil: daño 1,25 -> 1,1": {"hard_damage": 1.1},
	"Difícil: +15 Comida al bajar a 4 y 5": {"hard_food": 15, "hard_food_from": 4},
	"Difícil: +20 Comida al bajar a 4 y 5": {"hard_food": 20, "hard_food_from": 4},
	"Difícil: +25 Comida al bajar a 4 y 5": {"hard_food": 25, "hard_food_from": 4},
	"rescate a mitad de precio, entra con el nivel del grupo": {"costs": {"food": 8, "iron": 10}, "recruit_levels": true},
	"Difícil: amenaza 1,25 -> 1,1": {"hard_threat": 1.1},
	"Difícil: +5 Comida al bajar": {"hard_food": 5},
	"Difícil: vida 1,35 -> 1,2": {"hard_hp": 1.2},
	"Difícil: vida 1,35 -> 1,2 + daño 1,25 -> 1,1": {"hard_hp": 1.2, "hard_damage": 1.1},
	"Difícil: daño 1,25 -> 1,1 + amenaza 1,25 -> 1,1": {"hard_damage": 1.1, "hard_threat": 1.1},
	"Difícil: daño 1,25 -> 1,1 + inicio x1": {"hard_damage": 1.1, "hard_start": 1.0},
}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0]) if a.size() > 0 else 200
	var only: PackedStringArray = a[1].split(";") if a.size() > 1 else PackedStringArray()
	var cfg := BalanceSim.floor_config()  # held: the edits below live on this instance
	var rule := cfg.get_room_type_rule(RoomData.RoomType.PRISONER)
	var levels := DifficultyConfig.get_default().levels
	var hard: DifficultyLevel = levels[1]
	var keep := {"costs": rule.recruit_costs.duplicate(), "per_floor": rule.recruit_cost_per_floor,
		"start": hard.start_resource_mult, "damage": hard.damage_mult, "threat": hard.threat_mult, "hp": hard.hp_mult}
	var four: Array = [BalanceSim.HERO_IDS.duplicate()]
	var trios: Array = []
	for i in 4:
		var t: Array = BalanceSim.HERO_IDS.duplicate()
		t.remove_at(i)
		trios.append(t)
	print("| Cambio | Dificultad | Pares | Tríos (co-op 3) | Los 4 (co-op 4) | Pares sin conexión, hasta 2 reclutas |")
	print("|---|---|---|---|---|---|")
	for name: String in CONFIGS:
		if not only.is_empty() and name not in only:
			continue
		var c: Dictionary = CONFIGS[name]
		rule.recruit_costs = c.get("costs", keep["costs"])
		rule.recruit_cost_per_floor = c.get("per_floor", keep["per_floor"])
		hard.start_resource_mult = c.get("hard_start", keep["start"])
		hard.damage_mult = c.get("hard_damage", keep["damage"])
		hard.threat_mult = c.get("hard_threat", keep["threat"])
		hard.hp_mult = c.get("hard_hp", keep["hp"])
		for level: DifficultyLevel in levels:
			var play := {"extra_food": int(c.get("hard_food", 0)), "extra_food_from": int(c.get("hard_food_from", 2))} if level == hard else {}
			var cells: Array[String] = []
			for parties: Array in [PAIRS, trios, four, PAIRS]:
				var p := play.duplicate()
				if cells.size() == 3:
					p.merge({"recruit": 2, "recruit_levels": c.get("recruit_levels", false)}, true)
				var rows := BalanceSim.run_rows(runs, parties, [level], true, BalanceSim.BOSS_NEAR_TOWERS, p)
				cells.append("%s / %s / %s" % [_mean(rows, 3), _mean(rows, 4), _mean(rows, 5)])
			print("| %s | %s | %s |" % [name, level.display_name, " | ".join(cells)])
	quit(0)


func _mean(rows: Array[Dictionary], f: int) -> String:
	var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == f)
	return "%.0f" % (of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r["win_rate"]), 0.0) / of.size() * 100.0)

extends SceneTree

## juego-28 sweep (not a test): levers for Hard floor 3 and the co-op four, in memory only.
##   godot --headless --path . --script res://tests/tools/sweep_juego28_levers.gd -- [runs]
## Per config: floors 3 / 4 / 5 (mean of the six pairs) and the four (co-op, PlayerScaling of 4),
## Normal and Hard.

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]
## name -> {boss3_hp (Jefe orco base_hp), boss_hard (bosses skip Hard's hp_mult), hard_* (DifficultyLevel
## hard overrides), wave4 / cap4 (PlayerScaling for 4 players), food4 / food4_from (descent Comida, the four only)}
const CONFIGS := {
	"base": {},
	"Jefe orco -25 % vida": {"boss3_mult": 0.75},
	"Jefe orco -40 % vida": {"boss3_mult": 0.6},
	"jefes sin la vida de Difícil": {"boss_hard": true},
	"Difícil daño 1,25 -> 1,1": {"hard_damage_mult": 1.1},
	"Difícil recursos de inicio x1": {"hard_start_resource_mult": 1.0},
	"jefes sin vida de Difícil + inicio x1": {"boss_hard": true, "hard_start_resource_mult": 1.0},
	"co-op 4: oleada x2 -> x1,5": {"wave4": 1.5},
	"co-op 4: oleada x2 -> x1,75": {"wave4": 1.75},
	"co-op 4: tope +8 -> +4": {"cap4": 4},
	"co-op 4: Comida al bajar x2 (60, pisos 4-5)": {"food4": 60},
	"co-op 4: +30 Comida desde el piso 2": {"food4_from": 2},
	"co-op 4: +30 desde el 2 y 60 en 4-5": {"food4": 60, "food4_from": 2, "food4_split": 30},
	"co-op 4: oleada x1,75 + 30 desde el 2": {"wave4": 1.75, "food4_from": 2},
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
	var keep := {"b3": boss3.base_hp, "b5": boss5.base_hp, "wave": scaling.wave_mult.duplicate(), "cap": scaling.extra_max_enemies.duplicate(),
		"food": cfg.food_bonus_on_descend, "from": cfg.food_bonus_from_floor, "dmg": hard.damage_mult, "start": hard.start_resource_mult}
	var four: Array = [BalanceSim.HERO_IDS.duplicate()]
	print("| Cambio | Normal pares 3 / 4 / 5 | Difícil pares 3 / 4 / 5 | Normal los 4 3 / 4 / 5 | Difícil los 4 3 / 4 / 5 |")
	print("|---|---|---|---|---|")
	for name: String in CONFIGS:
		var c: Dictionary = CONFIGS[name]
		hard.damage_mult = c.get("hard_damage_mult", keep["dmg"])
		hard.start_resource_mult = c.get("hard_start_resource_mult", keep["start"])
		var w: PackedFloat32Array = keep["wave"].duplicate()
		w[3] = c.get("wave4", w[3])
		scaling.wave_mult = w
		var cap: PackedInt32Array = keep["cap"].duplicate()
		cap[3] = c.get("cap4", cap[3])
		scaling.extra_max_enemies = cap
		var cells: Array[String] = []
		for party_set in [PAIRS, four]:
			for level: DifficultyLevel in levels:
				var b3 := roundi(keep["b3"] * float(c.get("boss3_mult", 1.0)))
				var b5: int = keep["b5"]
				if c.get("boss_hard", false) and level == hard:
					b3 = roundi(b3 / hard.hp_mult)
					b5 = roundi(b5 / hard.hp_mult)
				boss3.base_hp = b3
				boss5.base_hp = b5
				var rows: Array[Dictionary] = []
				if party_set == four and c.has("food4_split"):
					rows = _four_split(runs, level, c)
				else:
					cfg.food_bonus_on_descend = c.get("food4", keep["food"]) if party_set == four else keep["food"]
					cfg.food_bonus_from_floor = c.get("food4_from", keep["from"]) if party_set == four else keep["from"]
					rows = BalanceSim.run_rows(runs, party_set, [level], true, BalanceSim.BOSS_NEAR_TOWERS, {})
				cells.append("%s / %s / %s" % [_mean(rows, 3), _mean(rows, 4), _mean(rows, 5)])
		cfg.food_bonus_on_descend = keep["food"]
		cfg.food_bonus_from_floor = keep["from"]
		print("| %s | %s | %s | %s | %s |" % [name, cells[0], cells[1], cells[2], cells[3]])
	boss3.base_hp = keep["b3"]
	boss5.base_hp = keep["b5"]
	quit(0)


## "+30 from floor 2 and 60 on 4-5" needs two amounts; BalanceSim pays one: run it as
## food_bonus_on_descend = food4_split from floor 2 plus BOSS_PLAY "extra_food" (unused) -> approximated
## by 45 from floor 2 (same total over floors 2-5: 30+30+60+60 = 180 = 4 x 45).
func _four_split(runs: int, level: DifficultyLevel, c: Dictionary) -> Array[Dictionary]:
	var cfg := BalanceSim.floor_config()
	cfg.food_bonus_on_descend = 45
	cfg.food_bonus_from_floor = 2
	return BalanceSim.run_rows(runs, [BalanceSim.HERO_IDS.duplicate()], [level], true, BalanceSim.BOSS_NEAR_TOWERS, {})


func _mean(rows: Array[Dictionary], f: int) -> String:
	var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == f)
	return "%.0f" % (of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r["win_rate"]), 0.0) / of.size() * 100.0)

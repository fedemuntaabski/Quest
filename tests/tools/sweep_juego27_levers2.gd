extends SceneTree

## juego-27 sweep (not a test): floor-5 levers, overrides in memory only.
##   godot --headless --path . --script res://tests/tools/sweep_juego27_levers2.gd -- [runs]
## Per config and difficulty: floors 3 / 4 / 5 (mean of the six pairs), floor 5 of those who
## reach it, the four heroes' floor 5.

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]
## name -> {f5_hp, f5_dmg, f5_threat (FloorTheme floor 5), boss_hp (Señor Demonio base_hp), food, food_from}
const CONFIGS := {
	"base": {},
	"Comida +40 (4 y 5)": {"food": 40, "food_from": 4},
	"Comida +30 (4 y 5) + jefe 150": {"food": 30, "food_from": 4, "boss_hp": 150},
	"Comida +30 (4 y 5) + jefe 110": {"food": 30, "food_from": 4, "boss_hp": 110},
	"Comida +20 (4 y 5) + jefe 110": {"food": 20, "food_from": 4, "boss_hp": 110},
	"Comida +40 (4 y 5) + jefe 150": {"food": 40, "food_from": 4, "boss_hp": 150},
	"Comida +20 (4 y 5) + jefe 150 + piso 5 como el 4": {"food": 20, "food_from": 4, "boss_hp": 150, "f5_hp": 1.45, "f5_dmg": 1.3},
	"Comida +30 (4 y 5) + jefe 150 + piso 5 como el 4": {"food": 30, "food_from": 4, "boss_hp": 150, "f5_hp": 1.45, "f5_dmg": 1.3},
}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0]) if a.size() > 0 else 200
	var cfg := BalanceSim.floor_config()
	var theme := cfg.theme(5)
	var boss := theme.boss
	var keep := [theme.hp_mult, theme.damage_mult, theme.threat_mult, boss.base_hp, cfg.food_bonus_on_descend, cfg.food_bonus_from_floor]
	var parties: Array = PAIRS.duplicate()
	parties.append(BalanceSim.HERO_IDS.duplicate())
	print("| Cambio | Dificultad | Pisos 3 / 4 / 5 (pares) | Piso 5 entre los que llegan | Los 4: piso 5 |")
	print("|---|---|---|---|---|")
	for name: String in CONFIGS:
		var c: Dictionary = CONFIGS[name]
		theme.hp_mult = c.get("f5_hp", keep[0])
		theme.damage_mult = c.get("f5_dmg", keep[1])
		theme.threat_mult = c.get("f5_threat", keep[2])
		boss.base_hp = c.get("boss_hp", keep[3])
		cfg.food_bonus_on_descend = c.get("food", keep[4])
		cfg.food_bonus_from_floor = c.get("food_from", keep[5])
		for level in DifficultyConfig.get_default().levels:
			var rows := BalanceSim.run_rows(runs, parties, [level], true, BalanceSim.BOSS_NEAR_TOWERS, {})
			var won := [0.0, 0.0, 0.0, 0.0, 0.0]
			var four := 0.0
			for r in rows:
				if r["size"] == 4:
					if int(r["floor"]) == 5:
						four = r["win_rate"]
				else:
					won[int(r["floor"]) - 1] += float(r["win_rate"]) / PAIRS.size()
			print("| %s | %s | %.0f / %.0f / %.0f | %.0f %% | %.0f %% |" % [name, level.id, won[2] * 100, won[3] * 100, won[4] * 100, won[4] / maxf(won[3], 0.001) * 100, four * 100])
	quit(0)

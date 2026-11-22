extends SceneTree

## juego-30 sweep (not a test): the Saber spent like a player (BalanceSim "research"), floor 5 by cause.
##   godot --headless --path . --script res://tests/tools/sweep_juego30.gd -- [runs] [section]
## section 1: research orders, Normal and Hard: pairs, co-op trios, co-op four, offline pairs recruiting
##            up to 2 (floors 3 / 4 / 5), Saber left and entries bought at the end of floors 3 / 4 / 5 (pairs).
## section 2: the juego-29 "rescue also for 15 Saber" lever, without and with research.
## section 3: floor 5 by cause (pairs and co-op 4, Normal and Hard, research on) + floor-5 what-ifs.
## section 4: levers in memory (args: runs 4 [0|1 research off/on]); one row per lever, floors 3 / 4 / 5.
## No section = 1-3.

const PAIRS := [["warrior", "mage"], ["warrior", "rogue"], ["warrior", "tank"], ["mage", "rogue"], ["mage", "tank"], ["rogue", "tank"]]
const CAUSE_COLS := ["win_rate", "heroes", "lvl_gap", "food_short", "food", "iron", "lore", "research", "towers", "hp_start", "door_fights", "dmg_door_pct", "die_door", "boss_hp_in", "boss_win", "die_boss", "dmg_boss_pct", "die_extr", "dmg_extr_pct", "items"]
const ORDERS := {
	"solo Ballesta (publicado)": {},
	"economía primero": {"research": ["cartography", "dry_tinder", "workshop_tuning", "defense_rifling", "workshop_bellows"]},
	"economía primero, la Ballesta antes que el Scriptorium": {"research": ["cartography", "dry_tinder", "workshop_tuning", "defense_rifling", "workshop_bellows"], "lab_first": false},
	"Virotes primero (RESEARCH_ORDER, el modelo)": {"research": BalanceSim.RESEARCH_ORDER},
	"solo economía": {"research": ["cartography", "dry_tinder", "workshop_tuning", "workshop_bellows"]},
	"solo Virotes": {"research": ["defense_rifling"]},
}
const WHATIFS_5 := {
	"ninguno": {},
	"Comida infinita": {"free_food": true},
	"niveles gratis": {"free_levels": true},
	"vida completa al empezar el 5": {"full_hp": 5},
	"sin oleadas de puerta en el 5": {"no_doors": 5},
	"sin extracción en el 5": {"no_extr": 5},
	"sin jefe en el 5": {"no_boss": 5},
}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var runs := int(a[0]) if a.size() > 0 else 200
	var section := int(a[1]) if a.size() > 1 else 0
	var levels := DifficultyConfig.get_default().levels
	var four: Array = [BalanceSim.HERO_IDS.duplicate()]
	var trios: Array = []
	for i in 4:
		var t: Array = BalanceSim.HERO_IDS.duplicate()
		t.remove_at(i)
		trios.append(t)
	var research := {"research": BalanceSim.RESEARCH_ORDER}
	if section in [0, 1]:
		print("\n## Research orders (%d runs): floors 3 / 4 / 5" % runs)
		print("| orden | dificultad | pares | tríos (co-op 3) | los 4 (co-op 4) | pares que rescatan hasta 2 | Saber al final del 3 / 4 / 5 (pares) | investigaciones (pares) |")
		print("|---|---|---|---|---|---|---|---|")
		for name: String in ORDERS:
			for level: DifficultyLevel in levels:
				var play: Dictionary = ORDERS[name]
				var cells: Array[String] = []
				var pairs_rows: Array[Dictionary] = []
				for parties: Array in [PAIRS, trios, four, PAIRS]:
					var p := play.duplicate()
					if cells.size() == 3:
						p["recruit"] = 2
					var rows := BalanceSim.run_rows(runs, parties, [level], true, BalanceSim.BOSS_NEAR_TOWERS, p)
					if cells.is_empty():
						pairs_rows = rows
					cells.append("%s / %s / %s" % [_mean(rows, 3), _mean(rows, 4), _mean(rows, 5)])
				cells.append("%s / %s / %s" % [_col(pairs_rows, 3, "lore"), _col(pairs_rows, 4, "lore"), _col(pairs_rows, 5, "lore")])
				cells.append("%s / %s / %s" % [_col(pairs_rows, 3, "research"), _col(pairs_rows, 4, "research"), _col(pairs_rows, 5, "research")])
				print("| %s | %s | %s |" % [name, level.display_name, " | ".join(cells)])
	if section in [0, 2]:
		var rule := BalanceSim.floor_config().get_room_type_rule(RoomData.RoomType.PRISONER)
		var keep := rule.recruit_costs.duplicate()
		print("\n## Rescue also for 15 Saber (+5 per floor), offline pairs up to 2 (%d runs): floors 3 / 4 / 5, heroes on 3 / 4 / 5" % runs)
		print("| caso | dificultad | sin Investigación | héroes | con Investigación | héroes |")
		print("|---|---|---|---|---|---|")
		for name: String in ["precio publicado", "también 15 Saber", "también 15 Saber, entra con el nivel del grupo"]:
			rule.recruit_costs = keep.merged({"lore": 15}) if name != "precio publicado" else keep
			for level: DifficultyLevel in levels:
				var cells: Array[String] = []
				for p: Dictionary in [{}, research]:
					var play := p.merged({"recruit": 2, "recruit_levels": name.ends_with("grupo")})
					var rows := BalanceSim.run_rows(runs, PAIRS, [level], true, BalanceSim.BOSS_NEAR_TOWERS, play)
					cells.append("%s / %s / %s" % [_mean(rows, 3), _mean(rows, 4), _mean(rows, 5)])
					cells.append("%s / %s / %s" % [_col(rows, 3, "heroes"), _col(rows, 4, "heroes"), _col(rows, 5, "heroes")])
				print("| %s | %s | %s |" % [name, level.display_name, " | ".join(cells)])
		rule.recruit_costs = keep
	if section == 4:
		_levers(runs, levels, trios, four, int(a[2]) == 1 if a.size() > 2 else false)
	if section in [0, 3]:
		print("\n## Floor 5 by cause, research on (%d runs)" % runs)
		_print(BalanceSim.run_rows(runs, PAIRS + four, levels, true, BalanceSim.BOSS_NEAR_TOWERS, research), [4, 5])
		print("\n## Floor-5 what-ifs, research on: floors 4 / 5 and floor 5 of those who reach it")
		print("| qué pasaría si | dificultad | pares 4 / 5 | 5 entre los que llegan | los 4 (co-op) 4 / 5 | 5 entre los que llegan |")
		print("|---|---|---|---|---|---|")
		for name: String in WHATIFS_5:
			for level: DifficultyLevel in levels:
				var play: Dictionary = research.merged(WHATIFS_5[name])
				var p := BalanceSim.run_rows(runs, PAIRS, [level], true, BalanceSim.BOSS_NEAR_TOWERS, play)
				var q := BalanceSim.run_rows(runs, four, [level], true, BalanceSim.BOSS_NEAR_TOWERS, play)
				print("| %s | %s | %s / %s | %s | %s / %s | %s |" % [name, level.display_name, _mean(p, 4), _mean(p, 5), _reach(p, 5), _mean(q, 4), _mean(q, 5), _reach(q, 5)])
	quit(0)


const LEVERS := {
	"ninguno": {},
	"rescate también por 15 Saber (+5 por piso)": {"rescue_lore": 15},
	"Virotes 25 -> 15 Saber": {"rifling": [15, 10.0]},
	"Virotes +10 -> +20": {"rifling": [25, 20.0]},
	"Virotes 15 Saber, +20": {"rifling": [15, 20.0]},
	"niveles también con Saber (1 por Comida)": {"play": {"level_lore": 1.0}},
	"niveles también con Saber (2 por Comida)": {"play": {"level_lore": 2.0}},
	"niveles con Saber (2) + rescate por 15 Saber": {"play": {"level_lore": 2.0}, "rescue_lore": 15},
	"+10 Comida al bajar al 5": {"play": {"extra_food": 10, "extra_food_from": 5}},
	"amenaza del piso 5 x0,85": {"f5_threat": 0.85},
}


func _levers(runs: int, levels: Array, trios: Array, four: Array, research: bool) -> void:
	var cfg := BalanceSim.floor_config()  # held: the edits below live on these instances
	var rc: ResearchConfig = load(BalanceSim.RESEARCH_PATH)
	var rifling := rc.get_entry("defense_rifling")
	var rule := cfg.get_room_type_rule(RoomData.RoomType.PRISONER)
	var theme := cfg.theme(5)
	var keep := {"costs": rule.recruit_costs.duplicate(), "rc": rifling.cost, "rv": rifling.value, "t5": theme.threat_mult}
	print("\n## Levers (%d runs, research %s; theme 5 threat %.2f): floors 3 / 4 / 5" % [runs, "on" if research else "off", keep["t5"]])
	print("| palanca | Normal pares | Difícil pares | Normal tríos | Difícil tríos | Normal los 4 | Difícil los 4 | Normal pares que rescatan | Difícil pares que rescatan |")
	print("|---|---|---|---|---|---|---|---|---|")
	for name: String in LEVERS:
		var l: Dictionary = LEVERS[name]
		rule.recruit_costs = keep["costs"].merged({"lore": l["rescue_lore"]}) if l.has("rescue_lore") else keep["costs"]
		var r: Array = l.get("rifling", [keep["rc"], keep["rv"]])
		rifling.cost = r[0]
		rifling.value = r[1]
		theme.threat_mult = keep["t5"] * float(l.get("f5_threat", 1.0))
		var play: Dictionary = (l.get("play", {}) as Dictionary).duplicate()
		if research:
			play["research"] = BalanceSim.RESEARCH_ORDER
		var cells := {}
		for level: DifficultyLevel in levels:
			var gi := 0
			for parties: Array in [PAIRS, trios, four, PAIRS]:
				var p := play.duplicate()
				if gi == 3:
					p["recruit"] = 2
				var rows := BalanceSim.run_rows(runs, parties, [level], true, BalanceSim.BOSS_NEAR_TOWERS, p)
				cells["%d%d" % [gi, levels.find(level)]] = "%s / %s / %s" % [_mean(rows, 3), _mean(rows, 4), _mean(rows, 5)]
				gi += 1
		var out: Array[String] = []
		for gi in 4:
			for li in 2:
				out.append(cells["%d%d" % [gi, li]])
		print("| %s | %s |" % [name, " | ".join(out)])
	rule.recruit_costs = keep["costs"]
	rifling.cost = keep["rc"]
	rifling.value = keep["rv"]
	theme.threat_mult = keep["t5"]


func _print(rows: Array[Dictionary], floors: Array) -> void:
	print("| difficulty | party | floor | " + " | ".join(CAUSE_COLS) + " |")
	print("|---|---|---|" + "---|".repeat(CAUSE_COLS.size()))
	for row in rows:
		if int(row["floor"]) in floors:
			print("| %s | %s | %d | %s |" % [row["difficulty"], row["party"], row["floor"], " | ".join(CAUSE_COLS.map(func(c: String) -> String: return str(row[c])))])


func _mean(rows: Array[Dictionary], f: int) -> String:
	var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == f)
	return "%.0f" % (of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r["win_rate"]), 0.0) / of.size() * 100.0)


func _col(rows: Array[Dictionary], f: int, key: String) -> String:
	var of := rows.filter(func(r: Dictionary) -> bool: return int(r["floor"]) == f)
	return "%.1f" % (of.reduce(func(acc: float, r: Dictionary) -> float: return acc + float(r[key]), 0.0) / of.size())


func _reach(rows: Array[Dictionary], f: int) -> String:
	var won := 0.0
	var reached := 0.0
	for r in rows:
		if int(r["floor"]) == f:
			won += float(r["win_rate"])
		elif int(r["floor"]) == f - 1:
			reached += float(r["win_rate"])
	return "%.0f %%" % (won / maxf(reached, 0.001) * 100.0)

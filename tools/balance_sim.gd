extends SceneTree

## Runs BalanceSim over the current .tres data and writes docs/balance/<tag>_*.csv.
##   godot --headless --path . --script res://tools/balance_sim.gd -- before
## Tag = first user arg (default "after"). Markdown tables go to stdout.

const OUT_DIR := "res://docs/balance"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := args[0] if not args.is_empty() else "after"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var tables := {
		"heroes": BalanceSim.hero_rows(),
		"duels": BalanceSim.duel_rows(),
		"encounters": BalanceSim.encounter_rows(),
		"nexo": BalanceSim.nexo_rows(),
		"towers": BalanceSim.tower_rows(),
	}
	for name in tables:
		var rows: Array[Dictionary] = tables[name]
		var file := FileAccess.open("%s/%s_%s.csv" % [OUT_DIR, tag, name], FileAccess.WRITE)
		file.store_string(BalanceSim.to_csv(rows))
		file.close()
		print("## ", name)
		print(BalanceSim.to_markdown(rows))
	quit(0)

extends RefCounted
class_name MovementRangeCalculator

# Buckets BFS-reachable cells into "blue" (reachable with the actor's next
# 1 AP) and "yellow" (reachable only by spending an additional AP, i.e. a
# dash), driven by CharacterStats.current_ap / move_range_per_ap.

static func compute_move_buckets(map_manager: MapManager, actor: Node) -> Dictionary:
	var result := {"blue": [] as Array[Vector2i], "yellow": [] as Array[Vector2i]}
	if map_manager == null or actor == null or not ("stats" in actor) or actor.stats == null:
		return result

	var stats: CharacterStats = actor.stats
	var current_ap: int = stats.current_ap
	var range_per_ap: int = maxi(stats.move_range_per_ap, 1)
	if current_ap <= 0:
		return result

	var max_steps: int = current_ap * range_per_ap
	var reachable: Dictionary = map_manager.get_reachable_cells_for_actor(actor, max_steps)

	for cell in reachable.keys():
		var steps: int = reachable[cell]
		if steps <= 0:
			continue
		var ap_needed: int = MovementCostUtil.steps_to_ap(steps, range_per_ap)
		if ap_needed <= 1:
			result["blue"].append(cell)
		elif ap_needed == 2 and current_ap >= 2:
			result["yellow"].append(cell)

	return result

extends RefCounted
class_name MovementCostUtil

# Single source of truth for the steps -> AP formula, shared by MoveAction
# (real charge) and the tactical range UI (preview label + blue/yellow buckets)
# so they can never drift apart.

static func steps_to_ap(steps: int, range_per_ap: int) -> int:
	if steps <= 0:
		return 0
	return int(ceil(float(steps) / float(maxi(range_per_ap, 1))))

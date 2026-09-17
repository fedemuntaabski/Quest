extends BaseAction
class_name MoveAction

# Queued move action that validates a full path and executes it atomically:
# the whole path is walked in one turn action, AP cost scaled by distance.

var map_manager: MapManager = null
var path: Array[Vector2i] = []
var validation_reason: String = ""
var validation_snapshot: Dictionary = {}


func _init(
	p_owner: Node = null,
	p_map_manager: MapManager = null,
	p_path: Array[Vector2i] = [],
	p_snapshot: Dictionary = {}
) -> void:
	var final_cell: Vector2i = p_path.back() if p_path.size() > 0 else Vector2i.ZERO
	super._init(p_owner, final_cell)
	consume_turn = false

	map_manager = p_map_manager
	path = p_path.duplicate()
	validation_snapshot = p_snapshot.duplicate(true) if p_snapshot else {}
	ap_cost = _compute_ap_cost()

func _compute_ap_cost() -> int:
	var steps: int = maxi(path.size() - 1, 0)
	var range_per_ap: int = 3
	if owner and "stats" in owner and owner.stats:
		range_per_ap = maxi(owner.stats.move_range_per_ap, 1)
	return MovementCostUtil.steps_to_ap(steps, range_per_ap)

func can_execute() -> bool:
	if owner == null or map_manager == null:
		validation_reason = "missing_owner_or_map"
		return false
	if path.size() < 2:
		validation_reason = "empty_path"
		return false
	if "grid_pos" in owner and path[0] != owner.grid_pos:
		validation_reason = "stale_path"
		return false
	if validation_snapshot.size() > 0 and map_manager.occupancy_manager:
		var current_ver := map_manager.occupancy_manager.get_version()
		var snap_ver := int(validation_snapshot.get("occ_version", -1))
		if snap_ver != -1 and snap_ver != current_ver:
			validation_reason = "stale_snapshot"
			return false
	if "stats" in owner and owner.stats and not owner.stats.has_ap(ap_cost):
		validation_reason = "insufficient_ap"
		return false
	for i in range(1, path.size()):
		if not map_manager.is_walkable_cell_for_actor(path[i], owner):
			validation_reason = "path_blocked"
			return false
	validation_reason = ""
	return true

func execute() -> void:
	if not can_execute():
		finish()
		return

	var final_cell: Vector2i = path.back()

	# Atomic reservation: release the origin cell and reserve the final
	# destination cell in one OccupancyManager call (one version bump),
	# before the visual animation begins.
	if map_manager.occupancy_manager:
		map_manager.occupancy_manager.update_actor_cell(owner, final_cell)

	if "stats" in owner and owner.stats:
		owner.stats.spend_ap(ap_cost)

	if not await MovementStepService.animate_actor_through_path(owner, path, map_manager):
		finish()
		return
	finish()

func get_execution_state_token() -> Dictionary:
	var token: Dictionary = {}
	if owner and "grid_pos" in owner:
		token["owner_cell"] = owner.grid_pos
	if path.size() > 0:
		token["target_cell"] = path.back()
	if map_manager and map_manager.occupancy_manager:
		token["occ_version"] = map_manager.occupancy_manager.get_version()
	if validation_snapshot.size() > 0:
		token["snapshot"] = validation_snapshot.duplicate(true)
	return token

func get_failure_reason() -> String:
	return validation_reason

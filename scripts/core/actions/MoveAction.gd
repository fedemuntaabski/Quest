extends BaseAction
class_name MoveAction

# Queued move action that validates a target cell and executes the shared step contract.

var map_manager: MapManager = null
var target_cell: Vector2i = Vector2i.ZERO
var use_pathfinding: bool = true
var tween_pause_mode: bool = true
var validation_reason: String = ""
var validation_snapshot: Dictionary = {}


func _init(
	p_owner: Node = null,
	p_map_manager: MapManager = null,
	p_target_cell: Vector2i = Vector2i.ZERO,
	p_use_pathfinding: bool = true,
	p_snapshot: Dictionary = {}
) -> void:
	super._init(p_owner, p_target_cell)
	consume_turn = true

	map_manager = p_map_manager
	target_cell = p_target_cell
	use_pathfinding = p_use_pathfinding
	validation_snapshot = p_snapshot.duplicate(true) if p_snapshot else {}

func can_execute() -> bool:
	if owner == null or map_manager == null:
		validation_reason = "missing_owner_or_map"
		return false
	if validation_snapshot.size() > 0 and map_manager.occupancy_manager:
		var current_ver := map_manager.occupancy_manager.get_version()
		var snap_ver := int(validation_snapshot.get("occ_version", -1))
		if snap_ver != -1 and snap_ver != current_ver:
			validation_reason = "stale_snapshot"
			return false
	validation_reason = ""
	return true

func execute() -> void:
	# Preserve the current move semantics: validate the path, then execute one step.
	if not can_execute():
		finish()
		return

	var next_cell := target_cell
	if use_pathfinding:
		var path: Array[Vector2i] = map_manager.find_path(owner.grid_pos, target_cell, owner)
		if path.is_empty():
			finish()
			return
		next_cell = path[1] if path.size() > 1 else path[0]

	if not map_manager.is_walkable_cell_for_actor(next_cell, owner):
		validation_reason = "target_not_walkable_for_actor"
		if OS.is_debug_build() and map_manager.core:
			var state := map_manager.core.describe_cell_state_for_actor(next_cell, owner)
			print("MoveAction: rejected next=%s reason=%s nav_walkable=%s blocked=%s allowed=%s room_id=%d active_room=%d room_locked=%s" % [
				str(state.get("cell", next_cell)),
				String(state.get("reason", validation_reason)),
				str(state.get("nav_walkable", false)),
				str(state.get("blocked", false)),
				str(state.get("allowed_for_actor", false)),
				int(state.get("room_id", -1)),
				int(state.get("active_room", -1)),
				str(state.get("room_locked", false))
			])
		finish()
		return

	if not await MovementStepService.move_actor_one_step(owner, next_cell, map_manager):
		finish()
		return
	finish()

func get_execution_state_token() -> Dictionary:
	var token: Dictionary = {}
	if owner and "grid_pos" in owner:
		token["owner_cell"] = owner.grid_pos
	token["target_cell"] = target_cell
	if map_manager and map_manager.occupancy_manager:
		token["occ_version"] = map_manager.occupancy_manager.get_version()
	if validation_snapshot.size() > 0:
		token["snapshot"] = validation_snapshot.duplicate(true)
	return token

func get_failure_reason() -> String:
	return validation_reason

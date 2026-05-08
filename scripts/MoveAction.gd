extends BaseAction
class_name MoveAction

var map_manager: MapManager = null
var target_cell: Vector2i = Vector2i.ZERO
var use_pathfinding: bool = true

func _init(
	p_owner: Node = null,
	p_map_manager: MapManager = null,
	p_target_cell: Vector2i = Vector2i.ZERO,
	p_use_pathfinding: bool = true
) -> void:
	super(p_owner, p_target_cell)
	map_manager = p_map_manager
	target_cell = p_target_cell
	use_pathfinding = p_use_pathfinding

func can_execute() -> bool:
	return owner != null and map_manager != null

func execute() -> void:
	if not can_execute():
		finish()
		return

	if owner.has_method("sync_to_grid"):
		owner.sync_to_grid()

	var next_cell := target_cell
	if use_pathfinding:
		var path: Array[Vector2i] = map_manager.find_path(owner.grid_pos, target_cell)
		if path.is_empty():
			finish()
			return
		next_cell = path[1] if path.size() > 1 else path[0]

	if not map_manager.is_walkable_cell(next_cell):
		finish()
		return

	if not owner.has_method("begin_step_move") or not owner.has_method("wait_for_step"):
		finish()
		return

	owner.begin_step_move(next_cell)
	await owner.wait_for_step()
	if map_manager:
		map_manager.update_actor_cell(owner, next_cell)
	finish()

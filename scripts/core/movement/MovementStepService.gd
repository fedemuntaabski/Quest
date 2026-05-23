extends RefCounted
class_name MovementStepService

# Shared step executor for movement effects and queued move actions.
# It keeps the actor-step contract in one place without changing step behavior.

# Movement execution
static func move_actor_one_step(actor: Node, next_cell: Vector2i, map_manager: MapManager) -> bool:
	if actor == null:
		return false
	if not actor.has_method("begin_step_move") or not actor.has_method("wait_for_step"):
		return false
	if map_manager == null:
		return false

	actor.begin_step_move(next_cell)
	await actor.wait_for_step()

	if map_manager.has_method("update_actor_cell"):
		map_manager.update_actor_cell(actor, next_cell)
	if actor.has_method("update_room_state_from_grid"):
		actor.update_room_state_from_grid()
	return true

extends Node
class_name EffectApplier

# Applies runtime effects (movement, status) using a provided EffectContext.
# This class centralizes MapManager/StatusRuntime usage so CombatCardSystem
# no longer directly manipulates map or status metadata.



func apply(result: Dictionary, target_component: CombatComponent, context: EffectContext) -> void:
	print("[EffectApplier] apply: START result=%s, target=%s" % [result, target_component.actor_owner.name if target_component and target_component.actor_owner else "NULL"])
	if result == null:
		print("[EffectApplier] apply: result is NULL")
		return
	if target_component == null:
		print("[EffectApplier] apply: target_component is NULL")
		return
	if context == null:
		push_warning("EffectApplier.apply called with null context")
		print("[EffectApplier] apply: context is NULL")
		return

	var map_manager := context.map_manager
	var owner_actor := context.owner_actor

	if map_manager == null:
		push_warning("EffectApplier: missing map_manager in context")
		print("[EffectApplier] apply: reject reason=missing_map_manager")
		return
	if target_component.actor_owner == null or not is_instance_valid(target_component.actor_owner):
		push_warning("EffectApplier: target actor is invalid or freed")
		print("[EffectApplier] apply: reject reason=invalid_target_actor")
		return

	# Begin effect transaction
	if context:
		context.begin()

	var success: bool = true

	# Movement
	var movement_count: int = result.get("movement", []).size()
	print("[EffectApplier] apply: processing %d movement effects" % movement_count)
	for move_data in result.get("movement", []):
		if not (move_data is Dictionary):
			continue
		var ok := await _apply_movement_effect(move_data, target_component, owner_actor, map_manager, context)
		if not ok:
			push_error("EffectApplier.apply: movement effect failed")
			success = false
			break

	# Statuses
	if success:
		var status_count: int = result.get("statuses", []).size()
		print("[EffectApplier] apply: processing %d status effects" % status_count)
		for status_data in result.get("statuses", []):
			if not (status_data is Dictionary):
				continue
			var ok2 := _apply_status_effect(status_data, target_component, context)
			if not ok2:
				push_error("EffectApplier.apply: status effect failed")
				success = false
				break

	print("[EffectApplier] apply: effects complete success=%s movement_count=%d status_count=%d" % [success, movement_count, result.get("statuses", []).size()])
	if context:
		if success:
			context.commit()
		else:
			context.rollback()
	print("[EffectApplier] apply: COMPLETE")

func _apply_movement_effect(move_data: Dictionary, target_component: CombatComponent, owner_actor: Node, map_manager: Node, context: EffectContext) -> bool:
	# Movement effects share the same one-step actor contract as queued move actions.
	if map_manager == null:
		return false

	var target_actor := target_component.actor_owner
	var receiver := owner_actor if str(move_data.get("target", "source")) == "source" else target_actor
	if receiver == null:
		return false
	if not receiver.has_method("begin_step_move") or not receiver.has_method("wait_for_step"):
		return false

	var move_cells: int = max(1, int(move_data.get("move_cells", 1)))
	var movement_mode: String = str(move_data.get("movement_mode", "dash"))
	var reference := target_actor if receiver == owner_actor else owner_actor
	var direction := CombatEffectHelper.resolve_movement_direction(receiver, reference, movement_mode, map_manager)
	if direction == Vector2i.ZERO:
		return false

	for _i in range(move_cells):
		var from_cell : Vector2i = CardTargeting.get_actor_cell(receiver, map_manager)
		if from_cell == null:
			return false

		var next_cell: Vector2i = from_cell + direction
		if not map_manager.is_walkable_cell_for_actor(next_cell, receiver):
			return false
		# Register rollback to restore actor position/cell if transaction fails
		if context != null:
			context.register_rollback(Callable(self, "_rb_set_actor_pos"), [receiver, from_cell, map_manager])

		if not await MovementStepService.move_actor_one_step(receiver, next_cell, map_manager):
			return false

	return true

func _apply_status_effect(status_data: Dictionary, target_component: CombatComponent, context: EffectContext) -> bool:
	var receiver_component: CombatComponent = context.combat_component if str(status_data.get("target", "target")) == "source" else target_component
	if receiver_component == null:
		return false

	var receiver_actor := receiver_component.actor_owner
	if receiver_actor == null:
		return false

	# Save previous status state for rollback
	var status_component := receiver_actor.get_node_or_null("StatusComponent") as StatusComponent
	if status_component != null:
		var prev_comp := status_component.statuses.duplicate(true)
		context.register_rollback(Callable(self, "_rb_restore_status_component"), [status_component, prev_comp])
	else:
		var prev_meta := StatusRuntime.get_statuses(receiver_actor).duplicate(true)
		context.register_rollback(Callable(self, "_rb_restore_status_meta"), [receiver_actor, prev_meta])

	StatusRuntime.apply_status(receiver_actor, receiver_component.stats, status_data)

	return true
func _rb_set_actor_pos(actor: Node, grid_pos: Vector2i, map_manager: Node) -> void:
	if actor == null or map_manager == null:
		return
	if not is_instance_valid(actor):
		return
	if map_manager and map_manager.has_method("grid_to_world_coords"):
		var world: Vector2 = map_manager.grid_to_world_coords(grid_pos)
		actor.global_position = world
	if map_manager and map_manager.has_method("update_actor_cell"):
		map_manager.update_actor_cell(actor, grid_pos)

func _rb_restore_status_meta(actor: Node, prev_meta: Dictionary) -> void:
	if actor == null:
		return
	if prev_meta == null:
		actor.set_meta(StatusRuntime.META_KEY, {})
	else:
		actor.set_meta(StatusRuntime.META_KEY, prev_meta)
	if is_instance_valid(actor) and actor.has_method("on_status_changed"):
		actor.call_deferred("on_status_changed")

func _rb_restore_status_component(status_component: StatusComponent, prev_statuses: Dictionary) -> void:
	if status_component == null:
		return
	status_component.statuses = prev_statuses
	if status_component.has_method("_on_status_changed"):
		status_component._on_status_changed()

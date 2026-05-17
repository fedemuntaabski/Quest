extends Node
class_name EffectApplier

# Applies runtime effects (movement, status) using a provided EffectContext.
# This class centralizes MapManager/StatusRuntime usage so CombatCardSystem
# no longer directly manipulates map or status metadata.

func apply(result: Dictionary, target_component: CombatComponent, context: EffectContext) -> void:
	if result == null:
		return
	if target_component == null:
		return

	var map_manager := context.map_manager
	var owner_actor := context.owner_actor

	# Movement
	for move_data in result.get("movement", []):
		if not (move_data is Dictionary):
			continue
		await _apply_movement_effect(move_data, target_component, owner_actor, map_manager)

	# Statuses
	for status_data in result.get("statuses", []):
		if not (status_data is Dictionary):
			continue
		_apply_status_effect(status_data, target_component, context)

func _apply_movement_effect(move_data: Dictionary, target_component: CombatComponent, owner_actor: Node, map_manager: Node) -> void:
	if map_manager == null:
		return

	var target_actor := target_component.actor_owner
	var receiver := owner_actor if str(move_data.get("target", "source")) == "source" else target_actor
	if receiver == null:
		return
	if not receiver.has_method("begin_step_move") or not receiver.has_method("wait_for_step"):
		return

	var move_cells: int = max(1, int(move_data.get("move_cells", 1)))
	var movement_mode: String = str(move_data.get("movement_mode", "dash"))
	var reference := target_actor if receiver == owner_actor else owner_actor
	var direction := _resolve_movement_direction(receiver, reference, movement_mode, map_manager)
	if direction == Vector2i.ZERO:
		return

	for _i in range(move_cells):
		var from_cell : Vector2i = CardTargeting.get_actor_cell(receiver, map_manager)
		if from_cell == null:
			break

		var next_cell: Vector2i = from_cell + direction
		if not map_manager.is_walkable_cell_for_actor(next_cell, receiver):
			break

		receiver.begin_step_move(next_cell)
		await receiver.wait_for_step()
		map_manager.update_actor_cell(receiver, next_cell)

func _apply_status_effect(status_data: Dictionary, target_component: CombatComponent, context: EffectContext) -> void:
	var receiver_component: CombatComponent = context.combat_component if str(status_data.get("target", "target")) == "source" else target_component
	if receiver_component == null:
		return
	StatusRuntime.apply_status(receiver_component.actor_owner, receiver_component.stats, status_data)

func _resolve_movement_direction(receiver: Node, reference: Node, movement_mode: String, map_manager: Node) -> Vector2i:
	var receiver_cell: Vector2i = CardTargeting.get_actor_cell(receiver, map_manager)
	if receiver_cell == null:
		return Vector2i.ZERO

	var destination: Vector2i = _get_hover_or_reference_cell(reference, map_manager)
	if destination == null:
		return Vector2i.ZERO

	var delta: Vector2i = destination - receiver_cell
	var direction := Vector2i(signi(delta.x), signi(delta.y))

	match movement_mode:
		"pull":
			return -direction
		"knockback":
			return -direction
		_:
			return direction

func _get_hover_or_reference_cell(reference: Node, map_manager: Node) -> Variant:
	if map_manager and map_manager.hovered_cell != Vector2i(-999, -999):
		return map_manager.hovered_cell
	if reference:
		return CardTargeting.get_actor_cell(reference, map_manager)
	return null

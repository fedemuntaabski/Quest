extends RefCounted
class_name CombatEffectHelper

static func resolve_movement_direction(receiver: Node, reference: Node, movement_mode: String, map_manager: Node) -> Vector2i:
	var receiver_cell: Vector2i = CardTargeting.get_actor_cell(receiver, map_manager)
	if receiver_cell == null:
		return Vector2i.ZERO

	var destination: Vector2i = get_reference_cell(reference, map_manager)
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

static func get_reference_cell(reference: Node, map_manager: Node) -> Variant:
	if map_manager and map_manager.hovered_cell != Vector2i(-999, -999):
		return map_manager.hovered_cell
	if reference:
		return CardTargeting.get_actor_cell(reference, map_manager)
	return null

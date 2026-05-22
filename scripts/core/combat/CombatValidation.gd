extends RefCounted
class_name CombatValidation

static func validate_target(source_component: CombatComponent, target: Node, map_manager: MapManager, range_limit: int = -1, check_range: bool = true, check_engagement: bool = true) -> Dictionary:
	var result := {
		"valid": false,
		"reason": "invalid"
	}

	if source_component == null:
		result["reason"] = "missing_combat_component"
		return result
	if source_component.stats == null:
		result["reason"] = "missing_stats"
		return result

	var target_component := resolve_target_component(target)
	if target_component == null:
		result["reason"] = "no_target"
		return result
	if target_component.stats == null:
		result["reason"] = "missing_target_stats"
		return result

	if not source_component.stats.is_alive():
		result["reason"] = "source_dead"
		return result
	if not target_component.stats.is_alive():
		result["reason"] = "target_dead"
		return result

	if source_component.actor_owner and source_component.actor_owner.has_method("sync_to_grid"):
		source_component.actor_owner.sync_to_grid()
	if target_component.actor_owner and target_component.actor_owner.has_method("sync_to_grid"):
		target_component.actor_owner.sync_to_grid()

	if check_engagement and map_manager and not map_manager.can_actors_engage(source_component.actor_owner, target_component.actor_owner):
		result["reason"] = "not_in_same_room"
		return result

	if check_range and range_limit >= 0:
		if not is_in_range(source_component.actor_owner, target_component.actor_owner, range_limit, map_manager):
			result["reason"] = "out_of_range"
			result["distance"] = get_distance(source_component.actor_owner, target_component.actor_owner, map_manager)
			result["max_range"] = range_limit
			return result

	result["valid"] = true
	result["reason"] = "ok"
	result["target_component"] = target_component
	result["distance"] = get_distance(source_component.actor_owner, target_component.actor_owner, map_manager)
	return result

static func resolve_target_component(target: Node) -> CombatComponent:
	if target == null:
		return null

	if target is CombatComponent:
		return target

	if target.has_method("get_combat_component"):
		return target.get_combat_component() as CombatComponent

	return target.get_node_or_null("CombatComponent") as CombatComponent

static func get_distance(source: Node, target: Node, map_manager: MapManager) -> int:
	var source_cell: Variant = CardTargeting.get_actor_cell(source, map_manager)
	var target_cell: Variant = CardTargeting.get_actor_cell(target, map_manager)
	if source_cell == null or target_cell == null:
		return -1
	return CardTargeting.get_chebyshev_distance(source_cell, target_cell)

static func get_actor_cell(actor: Node, map_manager: MapManager) -> Variant:
	return CardTargeting.get_actor_cell(actor, map_manager)

static func get_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return CardTargeting.get_chebyshev_distance(a, b)

static func is_in_range(source: Node, target: Node, range_value: int, map_manager: MapManager) -> bool:
	var source_cell: Variant = CardTargeting.get_actor_cell(source, map_manager)
	var target_cell: Variant = CardTargeting.get_actor_cell(target, map_manager)
	if source_cell == null or target_cell == null:
		return false
	return CardTargeting.get_chebyshev_distance(source_cell, target_cell) <= range_value

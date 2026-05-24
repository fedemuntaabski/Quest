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
		var source_cell: Variant = CardTargeting.get_actor_cell(source_component.actor_owner, map_manager)
		var target_cell: Variant = CardTargeting.get_actor_cell(target_component.actor_owner, map_manager)
		if source_cell == null or target_cell == null:
			result["reason"] = "out_of_range"
			result["distance"] = -1
			result["max_range"] = range_limit
			return result
		if CardTargeting.get_chebyshev_distance(source_cell, target_cell) > range_limit:
			result["reason"] = "out_of_range"
			result["distance"] = CardTargeting.get_chebyshev_distance(source_cell, target_cell)
			result["max_range"] = range_limit
			return result

	result["valid"] = true
	result["reason"] = "ok"
	result["target_component"] = target_component
	result["distance"] = CardTargeting.get_chebyshev_distance(
		CardTargeting.get_actor_cell(source_component.actor_owner, map_manager),
		CardTargeting.get_actor_cell(target_component.actor_owner, map_manager)

	)
	return result

static func resolve_target_component(target: Node) -> CombatComponent:
	if target == null:
		return null

	if target is CombatComponent:
		return target

	if target.has_method("get_combat_component"):
		return target.get_combat_component() as CombatComponent

	return target.get_node_or_null("CombatComponent") as CombatComponent

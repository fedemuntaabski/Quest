extends RefCounted
class_name EnemyTurnPolicy

enum Decision {
	WAIT,
	ATTACK,
	MOVE,
	SKIP,
}

static func decide(enemy: Enemy) -> Dictionary:
	if enemy == null:
		return {"decision": Decision.WAIT}

	if enemy.map_manager and enemy.map_manager.core:
		enemy.map_manager.core.repair_actor_room(enemy)

	if enemy.stats and enemy.stats.is_alive():
		var status_component := enemy.get_node_or_null("StatusComponent") as StatusComponent
		if status_component != null:
			var status_result := status_component.process_turn_start(enemy, enemy.stats)
			if status_result.get("can_act", true) != true:
				return {
					"decision": Decision.SKIP,
					"reason": str(status_result.get("events", []).front().get("status_id", "status_control")) if status_result.get("events", []).size() > 0 else "status_control"
				}

	if enemy.map_manager == null or enemy.player == null:
		return {"decision": Decision.WAIT}

	if enemy.combat_component == null or enemy.combat_component.stats == null:
		return {"decision": Decision.WAIT}

	if enemy.dungeon_generator and enemy.dungeon_generator.active_room_id != enemy.my_room_id:
		return {
			"decision": Decision.SKIP,
			"reason": "off_room",
		}

	enemy.sync_to_grid()

	if enemy.combat_component and bool(CombatValidation.validate_target(enemy.combat_component, enemy.player as Node, enemy.map_manager, enemy.combat_component.attack_range, true).get("valid", false)):
		if enemy.map_manager and not enemy.map_manager.can_actors_engage(enemy, enemy.player as Node):
			return {"decision": Decision.WAIT}
		return {
			"decision": Decision.ATTACK,
			"target": enemy.player,
		}

	var path: Array[Vector2i] = enemy.map_manager.find_path_to_adjacent(enemy.grid_pos, enemy.player.grid_pos, enemy)
	if path.size() > 1:
		return {
			"decision": Decision.MOVE,
			"next_cell": path[1],
		}

	return {"decision": Decision.WAIT}

extends RefCounted
class_name StatusRuntime

# Centralized runtime handler for status effects.
# Uses StatusComponent only (legacy metadata fallback removed).

static func apply_status(
	target_actor: Node,
	target_stats: CharacterStats,
	payload: Dictionary
) -> Dictionary:

	if target_actor == null or target_stats == null:
		return {
			"applied": false,
			"reason": "missing_target"
		}

	var status_component := _get_status_component(target_actor)

	if status_component == null:
		return {
			"applied": false,
			"reason": "missing_status_component"
		}

	var status_id := str(payload.get("status_id", "")).to_lower()

	if status_id.is_empty():
		return {
			"applied": false,
			"reason": "missing_status_id"
		}

	var duration: int = max(1, int(payload.get("duration", 1)))
	var stacks: int = max(1, int(payload.get("stacks", 1)))
	var magnitude: int = max(1, int(payload.get("magnitude", 1)))

	var damage_on_tick: int = 0

	match status_id:
		"poison", "burn":
			damage_on_tick = stacks * magnitude

	status_component.apply_status(
		status_id,
		stacks,
		duration,
		damage_on_tick
	)

	return {
		"applied": true,
		"status_id": status_id,
		"duration": duration,
		"stacks": stacks,
		"magnitude": magnitude
	}


static func process_turn_start(
	actor: Node,
	stats: CharacterStats
) -> Dictionary:

	var result := {
		"can_act": true,
		"events": []
	}

	if actor == null or stats == null:
		return result

	var status_component := _get_status_component(actor)

	if status_component == null:
		return result

	return status_component.process_turn_start(actor, stats)


static func get_statuses(actor: Node) -> Dictionary:
	if actor == null:
		return {}

	var status_component := _get_status_component(actor)

	if status_component == null:
		return {}

	return status_component.get_active_statuses()


static func has_status(actor: Node, status_id: String) -> bool:
	return get_statuses(actor).has(status_id.to_lower())


static func get_status_stacks(actor: Node, status_id: String) -> int:
	var statuses := get_statuses(actor)
	var normalized := status_id.to_lower()

	if not statuses.has(normalized):
		return 0

	return int(statuses[normalized].get("stacks", 0))


static func remove_status(actor: Node, status_id: String) -> void:
	if actor == null:
		return

	var status_component := _get_status_component(actor)

	if status_component == null:
		return

	status_component.remove_status(status_id.to_lower())


static func _get_status_component(actor: Node) -> StatusComponent:
	if actor == null:
		return null

	return actor.get_node_or_null("StatusComponent") as StatusComponent
extends RefCounted
class_name StatusRuntime

const META_KEY := "runtime_statuses"

static func apply_status(target_actor: Node, target_stats: CharacterStats, payload: Dictionary) -> Dictionary:
	if target_actor == null or target_stats == null:
		return {"applied": false, "reason": "missing_target"}

	var status_id := str(payload.get("status_id", "")).to_lower()
	if status_id == "":
		return {"applied": false, "reason": "missing_status_id"}

	var duration: int = max(1, int(payload.get("duration", 1)))
	var stacks: int = max(1, int(payload.get("stacks", 1)))
	var magnitude: int = max(1, int(payload.get("magnitude", 1)))

	# Try to use StatusComponent first (new pattern)
	var status_component := target_actor.get_node_or_null("StatusComponent") as StatusComponent
	if status_component != null:
		# Calculate damage_on_tick for status effects that tick
		var damage_on_tick: int = 0
		if status_id in ["poison", "burn"]:
			damage_on_tick = stacks * magnitude
		
		status_component.apply_status(status_id, stacks, duration, damage_on_tick)
		return {
			"applied": true,
			"status_id": status_id,
			"duration": duration,
			"stacks": stacks,
			"magnitude": magnitude
		}
	
	# Fallback to metadata system (legacy)
	var statuses := _get_statuses(target_actor)
	var existing: Dictionary = statuses.get(status_id, {})
	existing["status_id"] = status_id
	existing["duration"] = max(int(existing.get("duration", 0)), duration)
	existing["stacks"] = int(existing.get("stacks", 0)) + stacks
	existing["magnitude"] = magnitude
	statuses[status_id] = existing
	target_actor.set_meta(META_KEY, statuses)
	# Notify actor to refresh status visuals (if implemented)
	if is_instance_valid(target_actor):
		target_actor.call_deferred("on_status_changed")

	return {
		"applied": true,
		"status_id": status_id,
		"duration": int(existing["duration"]),
		"stacks": int(existing["stacks"]),
		"magnitude": int(existing["magnitude"])
	}

static func process_turn_start(actor: Node, stats: CharacterStats) -> Dictionary:
	var result := {
		"can_act": true,
		"events": []
	}

	if actor == null or stats == null:
		return result

	# Try to use StatusComponent first (new pattern)
	var status_component := actor.get_node_or_null("StatusComponent") as StatusComponent
	if status_component != null:
		return status_component.process_turn_start(actor, stats)
	
	# Fallback to metadata system (legacy)
	var statuses := _get_statuses(actor)
	if statuses.is_empty():
		return result

	var updated := statuses.duplicate(true)
	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]
		var event := _apply_status_tick(actor, stats, status_id, status)
		if not event.is_empty():
			result["events"].append(event)
			if event.get("skip_turn", false) == true:
				result["can_act"] = false

		var next_duration := int(status.get("duration", 0)) - 1
		if next_duration <= 0:
			updated.erase(status_id)
		else:
			status["duration"] = next_duration
			updated[status_id] = status

	actor.set_meta(META_KEY, updated)
	# Notify actor so visuals can update after tick
	if is_instance_valid(actor):
		actor.call_deferred("on_status_changed")

	return result

static func get_statuses(actor: Node) -> Dictionary:
	if actor == null:
		return {}
	var status_component := actor.get_node_or_null("StatusComponent") as StatusComponent
	if status_component != null:
		return status_component.get_active_statuses()
	return _get_statuses(actor)

static func has_status(actor: Node, status_id: String) -> bool:
	var statuses := get_statuses(actor)
	return statuses.has(status_id)

static func get_status_stacks(actor: Node, status_id: String) -> int:
	var statuses := get_statuses(actor)

	if not statuses.has(status_id):
		return 0

	return int(statuses[status_id].get("stacks", 0))

static func remove_status(actor: Node, status_id: String) -> void:
	if actor == null:
		return

	var status_component := actor.get_node_or_null("StatusComponent") as StatusComponent

	if status_component != null:
		status_component.remove_status(status_id)
		return

	var statuses := _get_statuses(actor)

	if statuses.has(status_id):
		statuses.erase(status_id)
		actor.set_meta(META_KEY, statuses)

		if actor.has_method("on_status_changed"):
			actor.call_deferred("on_status_changed")

static func _apply_status_tick(actor: Node, stats: CharacterStats, status_id: String, status: Dictionary) -> Dictionary:
	var stacks: int = max(1, int(status.get("stacks", 1)))
	var magnitude: int = max(1, int(status.get("magnitude", 1)))

	match status_id:
		"poison":
			var poison_damage: int = stacks * magnitude
			stats.take_damage(poison_damage)
			if actor.has_method("show_damage"):
				actor.show_damage(poison_damage, false)
			return {
				"status_id": "poison",
				"damage": poison_damage
			}
		"burn":
			var burn_damage: int = stacks * magnitude
			stats.take_damage(burn_damage)
			if actor.has_method("show_damage"):
				actor.show_damage(burn_damage, false)
			return {
				"status_id": "burn",
				"damage": burn_damage
			}
		"freeze":
			return {
				"status_id": "freeze",
				"skip_turn": true
			}
		_:
			return {
				"status_id": status_id,
				"applied": false
			}

static func _get_statuses(actor: Node) -> Dictionary:
	if actor == null:
		return {}
	if not actor.has_meta(META_KEY):
		return {}
	var statuses: Variant = actor.get_meta(META_KEY)
	if statuses is Dictionary:
		return statuses
	return {}

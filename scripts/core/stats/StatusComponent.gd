extends Node
class_name StatusComponent

## Centralized runtime status handler.
## Owns active statuses, ticking, duration decay and UI refresh.

signal statuses_changed(statuses: Dictionary)

var statuses: Dictionary = {} # status_id -> {stacks, turns_remaining, damage_on_tick}

func apply_status(
	status_id: String,
	stacks: int = 1,
	turns_remaining: int = 1,
	damage_on_tick: int = 0
) -> void:

	if status_id.is_empty():
		return

	status_id = status_id.to_lower()

	if statuses.has(status_id):
		statuses[status_id]["stacks"] += stacks

		statuses[status_id]["turns_remaining"] = max(
			int(statuses[status_id]["turns_remaining"]),
			turns_remaining
		)
		statuses[status_id]["damage_on_tick"] += damage_on_tick
	else:
		statuses[status_id] = {
			"stacks": stacks,
			"turns_remaining": turns_remaining,
			"damage_on_tick": damage_on_tick
		}

	_on_status_changed()

func tick_turn_start() -> Dictionary:
	var effects: Dictionary = {}
	var expired_statuses: Array[String] = []

	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]

		# Tick damage
		if int(status.get("damage_on_tick", 0)) > 0:
			effects["damage_events"] = int(effects.get("damage", 0)) + int(status["damage_on_tick"])

		# Duration decay
		status["turns_remaining"] -= 1

		if int(status["turns_remaining"]) <= 0:
			expired_statuses.append(status_id)

	# Cleanup expired statuses
	for status_id in expired_statuses:
		statuses.erase(status_id)

	if not expired_statuses.is_empty():
		_on_status_changed()

	return effects

func process_turn_start(actor: Node, stats: CharacterStats) -> Dictionary:
	var result := {
		"can_act": true,
		"events": []
	}

	if actor == null or stats == null:
		return result

	var tick_effects := tick_turn_start()

	# Apply status damage
	if int(tick_effects.get("damage", 0)) > 0:
		var damage := int(tick_effects["damage"])

		stats.take_damage(damage)

		if actor.has_method("show_damage"):
			actor.show_damage(damage, false)

		result["events"].append({
			"status_id": "status_damage",
			"damage": damage
		})

	# Freeze skip turn
	if is_frozen():
		result["can_act"] = false

		result["events"].append({
			"status_id": "freeze",
			"skip_turn": true
		})

	return result

func remove_status(status_id: String) -> void:
	status_id = status_id.to_lower()

	if not statuses.has(status_id):
		return

	statuses.erase(status_id)
	_on_status_changed()

func clear_all() -> void:
	if statuses.is_empty():
		return

	statuses.clear()
	_on_status_changed()

func get_active_statuses() -> Dictionary:
	var result: Dictionary = {}

	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]

		result[status_id] = {
			"stacks": int(status.get("stacks", 1)),
			"duration": int(status.get("turns_remaining", 0)),
			"damage_on_tick": int(status.get("damage_on_tick", 0))
		}

	return result

func has_status(status_id: String) -> bool:
	return statuses.has(status_id.to_lower())


func get_status_stacks(status_id: String) -> int:
	status_id = status_id.to_lower()

	if not statuses.has(status_id):
		return 0

	return int(statuses[status_id].get("stacks", 0))

func is_frozen() -> bool:
	return has_status("freeze") and get_status_stacks("freeze") > 0

func _on_status_changed() -> void:
	var active_statuses := get_active_statuses()

	# Broadcast state change
	statuses_changed.emit(active_statuses)

	# Optional owner callback
	var parent_node := get_parent()

	# Auto-refresh indicator
	if parent_node != null:
		var indicator := parent_node.get_node_or_null("StatusIndicator")

		if indicator != null and indicator.has_method("refresh_statuses"):
			indicator.refresh_statuses(active_statuses)
extends Node
class_name StatusComponent

## Centralized runtime status handler.
## Owns active statuses, ticking, duration decay and UI refresh.

# StatusComponent: stores and ticks per-actor statuses (poison, freeze, etc.).
# Responsibilities:
# - Maintain `statuses` map with stacks, duration and damage_on_tick.
# - Expose `process_turn_start`/`tick_turn_start` to be called by turn flow.
# - Emit `statuses_changed` and call owner `StatusIndicator` refresh where present.

signal statuses_changed(statuses: Dictionary)

var statuses: Dictionary = {} # status_id -> {stacks, turns_remaining, damage_on_tick}

static func normalize_status_id(status_id: String) -> String:
	var normalized := status_id.to_lower()
	if normalized == "stagger":
		return "stun"
	return normalized

static func status_skips_turn(status_id: String) -> bool:
	match normalize_status_id(status_id):
		"stun", "freeze":
			return true
		_:
			return false

static func status_deals_turn_damage(status_id: String) -> bool:
	match normalize_status_id(status_id):
		"poison", "burn", "bleed":
			return true
		_:
			return false

func apply_status(
	status_id: String,
	stacks: int = 1,
	turns_remaining: int = 1,
	damage_on_tick: int = 0
) -> void:

	if status_id.is_empty():
		return

	status_id = normalize_status_id(status_id)

	if statuses.has(status_id):
		statuses[status_id]["stacks"] += stacks

		statuses[status_id]["turns_remaining"] = max(
			int(statuses[status_id]["turns_remaining"]),
			turns_remaining
		)
		statuses[status_id]["damage_on_tick"] += damage_on_tick
		statuses[status_id]["fresh"] = true
	else:
		statuses[status_id] = {
			"stacks": stacks,
			"turns_remaining": turns_remaining,
			"damage_on_tick": damage_on_tick,
			"fresh": true
		}

	_on_status_changed()


func tick_turn_start() -> Dictionary:
	var effects: Dictionary = {}

	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]

		# Tick damage
		if int(status.get("damage_on_tick", 0)) > 0:
			effects["damage"] = int(effects.get("damage", 0)) + int(status["damage_on_tick"])

	return effects

func tick_turn_end() -> Dictionary:
	var result: Dictionary = {
		"changed": false,
		"expired": []
	}

	if statuses.is_empty():
		return result

	var expired_statuses: Array[String] = []

	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]
		if bool(status.get("fresh", false)):
			status["fresh"] = false
			statuses[status_id] = status
			continue
		status["turns_remaining"] = int(status.get("turns_remaining", 0)) - 1

		if int(status["turns_remaining"]) <= 0:
			expired_statuses.append(status_id)
		else:
			statuses[status_id] = status

	for status_id in expired_statuses:
		statuses.erase(status_id)
		result["expired"].append(status_id)

	result["changed"] = true
	_on_status_changed()
	return result

func process_turn_start(actor: Node, stats: CharacterStats) -> Dictionary:
	# Called at the start of an actor's turn by turn-processing logic.
	# Returns a dictionary `{'can_act': bool, 'events': [...]}` to allow
	# the caller to handle damage ticks or skip-turn semantics.
	var result := {
		"can_act": true,
		"events": []
	}

	if actor == null or stats == null:
		return result

	var skip_status_id := _get_turn_skip_status_id()
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

	# Control statuses can consume the next turn before their duration expires.
	if not skip_status_id.is_empty():
		result["can_act"] = false

		result["events"].append({
			"status_id": skip_status_id,
			"skip_turn": true
		})

	return result

func process_turn_end() -> Dictionary:
	return tick_turn_end()

func remove_status(status_id: String) -> void:
	status_id = normalize_status_id(status_id)

	if not statuses.has(status_id):
		return

	statuses.erase(status_id)
	_on_status_changed()

func consume_status_stack(status_id: String, amount: int = 1) -> bool:
	status_id = normalize_status_id(status_id)
	if amount <= 0 or not statuses.has(status_id):
		return false

	var status: Dictionary = statuses[status_id]
	var stacks := int(status.get("stacks", 0)) - amount
	if stacks <= 0:
		statuses.erase(status_id)
	else:
		status["stacks"] = stacks
		statuses[status_id] = status

	_on_status_changed()
	return true

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
	return statuses.has(normalize_status_id(status_id))


func get_status_stacks(status_id: String) -> int:
	status_id = normalize_status_id(status_id)

	if not statuses.has(status_id):
		return 0

	return int(statuses[status_id].get("stacks", 0))

func is_frozen() -> bool:
	return has_status("freeze") and get_status_stacks("freeze") > 0

func is_turn_controlled() -> bool:
	return _get_turn_skip_status_id() != ""

func _get_turn_skip_status_id() -> String:
	for status_id in statuses.keys():
		if status_skips_turn(str(status_id)):
			return str(status_id)

	return ""

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
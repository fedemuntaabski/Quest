extends Node
class_name StatusComponent

## Manages active status effects (poison, burn, freeze, etc.) with turn-based duration tracking

var statuses: Dictionary = {}  # status_id → {stacks, turns_remaining, damage_on_tick}
var owner_stats: CharacterStats


func _ready() -> void:
	# Try to get stats from parent
	var parent_node := get_parent()
	if parent_node:
		owner_stats = parent_node.get_node_or_null("Stats") as CharacterStats
		if owner_stats == null and parent_node is CharacterBody2D:
			owner_stats = parent_node.get_node_or_null("Stats")


func setup(stats: CharacterStats) -> void:
	owner_stats = stats


## Apply a status effect to this component
func apply_status(status_id: String, stacks: int = 1, turns_remaining: int = 1, damage_on_tick: int = 0) -> void:
	if status_id.is_empty():
		return
	
	if status_id in statuses:
		# Stack effect
		statuses[status_id]["stacks"] += stacks
		statuses[status_id]["turns_remaining"] = max(statuses[status_id]["turns_remaining"], turns_remaining)
	else:
		# New effect
		statuses[status_id] = {
			"stacks": stacks,
			"turns_remaining": turns_remaining,
			"damage_on_tick": damage_on_tick
		}
	
	_on_status_changed()


## Process status effects at turn start (damage, duration decay, effect checks)
## Returns dict with effects that should be applied (e.g., {"damage": 5} for poison)
func tick_turn_start() -> Dictionary:
	var effects: Dictionary = {}
	var expired_statuses: Array[String] = []
	
	for status_id in statuses.keys():
		var status = statuses[status_id]
		
		# Tick damage effects
		if status.get("damage_on_tick", 0) > 0:
			effects["damage"] = effects.get("damage", 0) + status["damage_on_tick"]
		
		# Decrement duration
		status["turns_remaining"] -= 1
		
		# Mark expired
		if status["turns_remaining"] <= 0:
			expired_statuses.append(status_id)
	
	# Remove expired
	for status_id in expired_statuses:
		statuses.erase(status_id)
	
	if not expired_statuses.is_empty():
		_on_status_changed()
	
	return effects


## Remove a specific status
func remove_status(status_id: String) -> void:
	if status_id in statuses:
		statuses.erase(status_id)
		_on_status_changed()


## Remove all statuses
func clear_all() -> void:
	if not statuses.is_empty():
		statuses.clear()
		_on_status_changed()


## Get all active statuses as array
func get_active_statuses() -> Array:
	var result: Array = []
	for status_id in statuses.keys():
		var status = statuses[status_id]
		result.append({
			"id": status_id,
			"stacks": status["stacks"],
			"turns_remaining": status["turns_remaining"]
		})
	return result


## Check if a specific status is active
func has_status(status_id: String) -> bool:
	return status_id in statuses


## Get current stack count for a status
func get_status_stacks(status_id: String) -> int:
	if status_id in statuses:
		return statuses[status_id]["stacks"]
	return 0


## Check if frozen (skip turn)
func is_frozen() -> bool:
	return has_status("freeze") and get_status_stacks("freeze") > 0


## Internal callback when status changes
func _on_status_changed() -> void:
	var parent_node := get_parent()
	if parent_node:
		# Notify owner if it has a status indicator
		if parent_node.has_method("on_status_changed"):
			parent_node.on_status_changed()
		# Update visual indicators
		var indicator = parent_node.get_node_or_null("StatusIndicator")
		if indicator and indicator.has_method("refresh_statuses"):
			indicator.refresh_statuses(get_active_statuses())

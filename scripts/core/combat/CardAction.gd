extends BaseAction
class_name CardAction

var card_system: CombatCardSystem
var card_data: CardData
var validation_reason: String = ""

# CardAction: wraps a card play into the `ActionQueue` contract.
# - Stores a snapshot or target reference and defers execution to
#   `CombatCardSystem.execute_card_snapshot` so card effects run within
#   the queued action lifecycle.

func _init(p_system: CombatCardSystem, p_card: CardData, p_target: Variant) -> void:
	card_system = p_system
	card_data = p_card
	var actor_owner_local := card_system.owner_actor if card_system else null
	super._init(actor_owner_local, p_target)
	consume_turn = true

func can_execute() -> bool:
	var real_target: Node = null
	var snapshot: Dictionary = {}
	if typeof(target) == TYPE_DICTIONARY and target.has("target") and target["target"] is Node:
		real_target = target["target"] as Node
		snapshot = target as Dictionary
	elif target is Node:
		real_target = target as Node

	if card_system == null:
		validation_reason = "no_card_system"
		return false
	if card_data == null:
		validation_reason = "no_card_data"
		return false
	if real_target == null:
		validation_reason = "no_target"
		return false
	var validation := card_system.get_card_validation(card_data, real_target) if snapshot.is_empty() else card_system.validate_card_snapshot(card_data, snapshot)
	var ok: bool = bool(validation.get("valid", false))
	if not ok:
		validation_reason = str(validation.get("reason", "invalid"))
	else:
		validation_reason = ""
	return ok

func execute() -> void:
	var res: Dictionary = {}
	var real_target: Node = null
	if typeof(target) == TYPE_DICTIONARY and target.has("target") and target["target"] is Node:
		real_target = target["target"] as Node
	elif target is Node:
		real_target = target as Node

	if card_system:
		print("[CardAction] execute: awaiting card_system.execute_card_snapshot()")
		res = await card_system.execute_card_snapshot(card_data, target)
	else:
		print("[CardAction] execute: card_system is NULL")
	
	finish(res if res else {"status":"unknown"})
	

func get_execution_state_token() -> Dictionary:
	var token: Dictionary = {}
	if card_system and card_system.map_manager and card_system.map_manager.occupancy_manager:
		token["occ_version"] = card_system.map_manager.occupancy_manager.get_version()
	if typeof(target) == TYPE_DICTIONARY:
		token["snapshot"] = target.duplicate(true)
	return token

func get_failure_reason() -> String:
	return validation_reason

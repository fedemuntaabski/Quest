extends RefCounted
class_name BaseAction

signal completed(action: BaseAction, result: Dictionary)

var owner: Node = null
var target: Variant = null
var is_complete: bool = false
# consume_turn: forces the turn to end unconditionally, regardless of
# remaining AP. Only for skip/incapacitation/explicit end-turn actions
# (e.g. WaitAction). AP-costing actions (Move/Attack/Card) leave this
# false — TurnManager ends the turn once current_ap reaches 0 instead.
var consume_turn: bool = true
var ap_cost: int = 1
var duration: float = 0.0
var result: Dictionary = {}

# BaseAction: action execution contract used by `ActionQueue`.
# - Subclasses should override `can_execute`, `execute`, and optionally
#   `get_execution_state_token` to report state for optimistic checks.
# - Use `finish()` to mark completion and emit `completed`.

func _init(p_owner: Node = null, p_target: Variant = null) -> void:
	owner = p_owner
	target = p_target

func can_execute() -> bool:
	return true

func get_execution_state_token() -> Dictionary:
	return {}

func execute() -> void:
	finish()

func finish(res: Dictionary = {}) -> void:
	if is_complete:
		return

	is_complete = true
	result = res
	completed.emit(self, result)

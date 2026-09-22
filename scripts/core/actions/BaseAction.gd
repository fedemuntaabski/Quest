extends RefCounted
class_name BaseAction

signal completed(action: BaseAction, result: Dictionary)

var owner: Node = null
var target: Variant = null
var is_complete: bool = false
var duration: float = 0.0
var result: Dictionary = {}

# BaseAction: action execution contract.
# - Subclasses should override `can_execute` and `execute`.
# - Use `finish()` to mark completion and emit `completed`.

func _init(p_owner: Node = null, p_target: Variant = null) -> void:
	owner = p_owner
	target = p_target

func can_execute() -> bool:
	return true

func execute() -> void:
	finish()

func finish(res: Dictionary = {}) -> void:
	if is_complete:
		return

	is_complete = true
	result = res
	completed.emit(self, result)

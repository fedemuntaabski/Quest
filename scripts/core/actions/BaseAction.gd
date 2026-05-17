extends RefCounted
class_name BaseAction

signal completed(action: BaseAction)

var owner: Node = null
var target: Variant = null
var is_complete: bool = false
var consume_turn: bool = true
var duration: float = 0.0

func _init(p_owner: Node = null, p_target: Variant = null) -> void:
	owner = p_owner
	target = p_target

func can_execute() -> bool:
	return true

func execute() -> void:
	finish()

func finish() -> void:
	if is_complete:
		return

	is_complete = true
	completed.emit(self)

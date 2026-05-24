extends Node
class_name ActionQueue

signal action_finished(action: BaseAction, result: Dictionary)

var _queue: Array[BaseAction] = []
var _is_busy: bool = false

# ActionQueue: serial executor for `BaseAction` instances.
# - Ensures only one action executes at a time and emits `action_finished`.
# - Tracks execution state tokens to detect state changes during action execution
#   and includes this information in the emitted result for callers like TurnManager.

func _describe_action(action: BaseAction) -> String:
	if action == null:
		return "NULL"
	var script := action.get_script() as Script
	var owner_name := "NULL"
	if action.owner:
		owner_name = action.owner.name
	if script:
		return "%s (%s) owner=%s" % [action.get_class(), script.resource_path, owner_name]
	return "%s owner=%s" % [action.get_class(), owner_name]

func queue_action(action: BaseAction) -> void:
	if action == null:
		return

	print("[ActionQueue] queue_action: queuing action=%s _is_busy=%s queue_size_before=%d" % [_describe_action(action), _is_busy, _queue.size()])
	_queue.append(action)
	print("[ActionQueue] queue_action: queued action=%s queue_size_after=%d" % [_describe_action(action), _queue.size()])

	if not _is_busy:
		print("[ActionQueue] queue_action: queue not busy, calling process_next()")
		process_next()
	else:
		print("[ActionQueue] queue_action: queue is busy, action will wait in queue")

func process_next() -> void:
	if _is_busy:
		return

	if _queue.is_empty():
		return

	var action: BaseAction = _queue.pop_front()
	# Pop and execute the next queued action; await its `completed` signal
	# if it is asynchronous.
	if action == null:
		print("[ActionQueue] process_next: popped NULL action, recursing")
		process_next()
		return

	print("[ActionQueue] process_next: executing action, type=%s" % _describe_action(action))
	_is_busy = true
	var start_token: Dictionary = action.get_execution_state_token() if action else {}

	if not action.can_execute():
		print("[ActionQueue] process_next: action cannot execute, finishing action=%s" % _describe_action(action))
		var failure_reason : Variant = action.get_failure_reason() if action and action.has_method("get_failure_reason") else ""
		var res : Dictionary = {"status":"cannot_execute", "consumes_turn": false, "reason": failure_reason if failure_reason != "" else "can_execute_false"}
		action.finish(res)
		_is_busy = false
		action_finished.emit(action, res)
		process_next()
		return

	action.execute()
	var completed_args = []
	if not action.is_complete:
		completed_args = await action.completed
	# completed_args expected [action, result]
	var res: Dictionary = action.result if action.result else (completed_args[1] if completed_args.size() >= 2 else {})
	var end_token: Dictionary = action.get_execution_state_token() if action else {}
	var state_changed: bool = start_token != end_token
	if state_changed:
		res["state_changed_during_execution"] = true
		res["execution_state_token_start"] = start_token
		res["execution_state_token_end"] = end_token

	if not action.is_complete:
		# if action didn't call finish, finish it now with default success
		action.finish(res)

	print("[ActionQueue] process_next: action finished, type=%s queue_size_remaining=%d" % [_describe_action(action), _queue.size()])
	_is_busy = false
	action_finished.emit(action, res)
	process_next()

func clear() -> void:
	_queue.clear()
	_is_busy = false

func is_busy() -> bool:
	return _is_busy

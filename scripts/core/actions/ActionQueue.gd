extends Node
class_name ActionQueue

const PRELOAD_BASE_ACTION = preload("res://scripts/core/actions/BaseAction.gd")

signal action_finished(action: BaseAction)

var _queue: Array[BaseAction] = []
var _is_busy: bool = false

func queue_action(action: BaseAction) -> void:
	if action == null:
		return

	_queue.append(action)

	if not _is_busy:
		process_next()

func process_next() -> void:
	if _is_busy:
		return

	if _queue.is_empty():
		return

	var action: BaseAction = _queue.pop_front()
	if action == null:
		process_next()
		return

	_is_busy = true

	if not action.can_execute():
		action.finish()
		_is_busy = false
		action_finished.emit(action)
		process_next()
		return

	action.execute()
	if not action.is_complete:
		await action.completed

	action.finish()
	_is_busy = false
	action_finished.emit(action)
	process_next()

func clear() -> void:
	_queue.clear()
	_is_busy = false

func is_busy() -> bool:
	return _is_busy

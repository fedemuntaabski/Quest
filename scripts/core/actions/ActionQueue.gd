extends Node
class_name ActionQueue

const PRELOAD_BASE_ACTION = preload("res://scripts/core/actions/BaseAction.gd")

signal action_finished(action: BaseAction)

var _queue: Array[BaseAction] = []
var _is_busy: bool = false

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
	if action == null:
		print("[ActionQueue] process_next: popped NULL action, recursing")
		process_next()
		return

	print("[ActionQueue] process_next: executing action, type=%s" % _describe_action(action))
	_is_busy = true

	if not action.can_execute():
		print("[ActionQueue] process_next: action cannot execute, finishing action=%s" % _describe_action(action))
		action.finish()
		_is_busy = false
		action_finished.emit(action)
		process_next()
		return

	action.execute()
	if not action.is_complete:
		await action.completed

	action.finish()
	print("[ActionQueue] process_next: action finished, type=%s queue_size_remaining=%d" % [_describe_action(action), _queue.size()])
	_is_busy = false
	action_finished.emit(action)
	process_next()

func clear() -> void:
	_queue.clear()
	_is_busy = false

func is_busy() -> bool:
	return _is_busy

func get_queue_size() -> int:
	return _queue.size()

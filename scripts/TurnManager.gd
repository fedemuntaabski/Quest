extends Node
class_name TurnManager

const ActionQueue = preload("res://scripts/ActionQueue.gd")
const BaseAction = preload("res://scripts/BaseAction.gd")

var actors: Array = []
var pending_actors: int = 0
var current_actor_index: int = 0
var current_actor: Node = null
var action_queue: ActionQueue

func _ready() -> void:
	if action_queue != null:
		return

	action_queue = ActionQueue.new()
	action_queue.name = "ActionQueue"
	add_child(action_queue)
	action_queue.action_finished.connect(_on_action_finished)

# ─────────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────────
func register_actor(actor: Node) -> void:
	if not actors.has(actor):
		actors.append(actor)

func unregister_actor(actor: Node) -> void:
	actors.erase(actor)

# ─────────────────────────────────────────────
# LOOP
# ─────────────────────────────────────────────
func start() -> void:
	if actors.is_empty():
		push_warning("TurnManager: No actors registered")
		return

	_start_turn()

func _start_turn() -> void:
	pending_actors = actors.size()
	current_actor_index = 0
	current_actor = null

	_begin_actor_turn()

func _begin_actor_turn() -> void:
	if actors.is_empty():
		return

	if pending_actors <= 0:
		_start_turn()
		return

	if current_actor_index >= actors.size():
		_start_turn()
		return

	current_actor = actors[current_actor_index]
	if current_actor == null:
		_actor_finished()
		return

	if current_actor.has_method("begin_turn"):
		current_actor.begin_turn(self)
	else:
		_actor_finished()
		return

	action_queue.process_next()

# ─────────────────────────────────────────────
# CONTROL DE TURNO
# ─────────────────────────────────────────────
func end_turn() -> void:
	_actor_finished()

func _actor_finished() -> void:
	pending_actors -= 1
	current_actor_index += 1

	if pending_actors <= 0:
		_start_turn()
		return

	_begin_actor_turn()

func _on_action_finished(action: BaseAction) -> void:
	if action == null:
		return

	if action.consume_turn:
		end_turn()
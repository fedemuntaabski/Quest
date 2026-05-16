extends Node
class_name TurnManager

const PRELOAD_ACTION_QUEUE = preload("res://scripts/ActionQueue.gd")
const PRELOAD_BASE_ACTION = preload("res://scripts/BaseAction.gd")

var actors: Array = []
var pending_actors: int = 0
var current_actor_index: int = 0
var current_actor: Node = null
var action_queue: ActionQueue
var _active: bool = true
var _waiting_for_state: bool = false

func _ready() -> void:
	_ensure_action_queue()
	_bind_game_state()

func _bind_game_state() -> void:
	var tree := get_tree()
	if tree == null:
		call_deferred("_bind_game_state")
		return
	var gsm := tree.get_first_node_in_group("game_state_manager") as GameStateManager
	if gsm == null:
		call_deferred("_bind_game_state")
		return
	if not gsm.state_changed.is_connected(_on_game_state_changed):
		gsm.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: int, _old_state: int) -> void:
	if new_state != GameStateManager.State.ACTIVE:
		return
	if not _waiting_for_state:
		return
	_waiting_for_state = false
	_resume_if_possible()

func _resume_if_possible() -> void:
	if not _active:
		return
	if action_queue and action_queue.is_busy():
		return
	_begin_actor_turn()

func _ensure_action_queue() -> void:
	if action_queue != null:
		return

	action_queue = PRELOAD_ACTION_QUEUE.new()
	action_queue.name = "ActionQueue"
	add_child(action_queue)
	if not action_queue.action_finished.is_connected(_on_action_finished):
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
	_ensure_action_queue()
	_active = true
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
	if not _active:
		return
	if not _can_process_turns():
		_waiting_for_state = true
		return
	_waiting_for_state = false
	if actors.is_empty():
		return

	_ensure_action_queue()

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

func stop() -> void:
	_active = false
	if action_queue:
		action_queue.clear()
	
	# Clear current actor reference to prevent stale access
	if current_actor != null:
		# Notify actor their turn was interrupted (if they care)
		if current_actor.has_method("turn_interrupted"):
			current_actor.turn_interrupted()
		current_actor = null
	
	pending_actors = 0
	current_actor_index = 0

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
	if not _active:
		return

	if action.consume_turn:
		end_turn()

func _can_process_turns() -> bool:
	var tree := get_tree()
	if tree == null:
		return true
	var game_state_manager := tree.get_first_node_in_group("game_state_manager") as GameStateManager
	if game_state_manager:
		return game_state_manager.can_process_turns()
	return true

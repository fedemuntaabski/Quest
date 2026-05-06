extends Node
class_name TurnManager

var actors: Array = []
var pending_actors: int = 0

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

	# 🔥 TODOS ACTÚAN AL MISMO TIEMPO
	for actor in actors:
		if actor != null and actor.has_method("take_turn"):
			actor.take_turn(self)
		else:
			_actor_finished()

# ─────────────────────────────────────────────
# CONTROL DE TURNO
# ─────────────────────────────────────────────
func end_turn() -> void:
	_actor_finished()

func _actor_finished() -> void:
	pending_actors -= 1

	if pending_actors <= 0:
		_start_turn()
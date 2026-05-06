extends Node
class_name TurnManager

var actors: Array = []
var current_index: int = 0
var is_processing_turn: bool = false

# ─────────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────────
func register_actor(actor: Node) -> void:
	if not actors.has(actor):
		actors.append(actor)

func unregister_actor(actor: Node) -> void:
	if actors.has(actor):
		var idx := actors.find(actor)
		actors.erase(actor)

		# ajustar índice si hace falta
		if idx <= current_index and current_index > 0:
			current_index -= 1


# ─────────────────────────────────────────────
# LOOP
# ─────────────────────────────────────────────
func start() -> void:
	if actors.is_empty():
		push_warning("TurnManager: No actors registered")
		return

	current_index = 0
	_process_next_turn()


func _process_next_turn() -> void:
	if actors.is_empty():
		return

	is_processing_turn = true

	var actor = actors[current_index]

	if actor == null:
		_end_turn()
		return

	if not actor.has_method("take_turn"):
		push_warning("Actor sin take_turn(): %s" % actor.name)
		_end_turn()
		return

	actor.take_turn(self)


# ─────────────────────────────────────────────
# CONTROL DE TURNO
# ─────────────────────────────────────────────
func end_turn() -> void:
	_end_turn()


func _end_turn() -> void:
	is_processing_turn = false

	current_index += 1
	if current_index >= actors.size():
		current_index = 0

	_process_next_turn()


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────
func is_player_turn(player: Node) -> bool:
	if actors.is_empty():
		return false

	return actors[current_index] == player
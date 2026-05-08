extends Node
class_name OccupancyManager

signal occupancy_changed(cell: Vector2i, actor: Node)

var _cell_to_actor: Dictionary = {}
var _actor_to_cell: Dictionary = {}
var _blocking_actors: Dictionary = {}

func register_actor(actor: Node, grid_pos: Vector2i, blocks: bool = true) -> void:
	if actor == null:
		return

	_blocking_actors[actor] = blocks
	_update_actor_cell(actor, grid_pos)

func unregister_actor(actor: Node) -> void:
	if actor == null:
		return

	var old_cell: Variant = _actor_to_cell.get(actor, null)
	if old_cell != null and _cell_to_actor.get(old_cell) == actor:
		_cell_to_actor.erase(old_cell)

	_actor_to_cell.erase(actor)
	_blocking_actors.erase(actor)

func update_actor_cell(actor: Node, grid_pos: Vector2i) -> void:
	if actor == null:
		return

	_update_actor_cell(actor, grid_pos)

func get_actor_at_cell(grid_pos: Vector2i) -> Node:
	return _cell_to_actor.get(grid_pos, null)

func get_actor_cell(actor: Node) -> Variant:
	return _actor_to_cell.get(actor, null)

func is_cell_occupied(grid_pos: Vector2i) -> bool:
	return _cell_to_actor.has(grid_pos)

func is_cell_blocked(grid_pos: Vector2i, requester: Node = null) -> bool:
	if not _cell_to_actor.has(grid_pos):
		return false

	var actor: Node = _cell_to_actor[grid_pos]
	if requester != null and actor == requester:
		return false

	return _blocking_actors.get(actor, true)

func _update_actor_cell(actor: Node, grid_pos: Vector2i) -> void:
	var old_cell: Variant = _actor_to_cell.get(actor, null)
	if old_cell != null and _cell_to_actor.get(old_cell) == actor:
		_cell_to_actor.erase(old_cell)

	_actor_to_cell[actor] = grid_pos
	_cell_to_actor[grid_pos] = actor
	occupancy_changed.emit(grid_pos, actor)

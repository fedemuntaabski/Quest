extends Node
class_name OccupancyManager

signal occupancy_changed(cell: Vector2i, actor: Node)

var _cell_to_actor: Dictionary = {} # cell(Vector2i) -> Array of actors
var _actor_to_cell: Dictionary = {}
var _blocking_actors: Dictionary = {}
var _default_multi_mode: bool = false
var _version: int = 0

# Enable or disable default multi-occupancy mode for new registrations.
func set_default_multi_mode(enabled: bool) -> void:
	_default_multi_mode = enabled

func register_actor(actor: Node, grid_pos: Vector2i, blocks: bool = true, allow_multi: bool = false) -> void:
	if actor == null:
		return

	_blocking_actors[actor] = blocks
	# allow_multi explicit OR global default
	var multi: bool = allow_multi or _default_multi_mode
	_update_actor_cell(actor, grid_pos, multi)

func unregister_actor(actor: Node) -> void:
	if actor == null:
		return

	var old_cell: Variant = _actor_to_cell.get(actor, null)
	if old_cell != null:
		var arr: Variant = _cell_to_actor.get(old_cell, null)
		if arr != null:
			if arr is Array:
				arr.erase(actor)
				if arr.empty():
					_cell_to_actor.erase(old_cell)
				else:
					_cell_to_actor[old_cell] = arr
			elif arr == actor:
				_cell_to_actor.erase(old_cell)

	_actor_to_cell.erase(actor)
	_blocking_actors.erase(actor)

func update_actor_cell(actor: Node, grid_pos: Vector2i) -> void:
	if actor == null:
		return

	# preserve previous multi-mode for this actor if present
	var old_cell: Variant = _actor_to_cell.get(actor, null)
	var multi: bool = false
	if old_cell != null:
		var existing: Variant = _cell_to_actor.get(old_cell, null)
		multi = existing is Array

	_update_actor_cell(actor, grid_pos, multi)

func get_actor_at_cell(grid_pos: Vector2i) -> Node:
	var entry: Variant = _cell_to_actor.get(grid_pos, null)
	if entry == null:
		return null
	if entry is Array:
		# prefer a blocking actor if present
		for a in entry:
			if _blocking_actors.get(a, true):
				return a
		return entry[0] if entry.size() > 0 else null
	return entry

func get_actor_cell(actor: Node) -> Variant:
	return _actor_to_cell.get(actor, null)

func is_cell_occupied(grid_pos: Vector2i) -> bool:
	return _cell_to_actor.has(grid_pos)

func is_cell_blocked(grid_pos: Vector2i, requester: Node = null) -> bool:
	if not _cell_to_actor.has(grid_pos):
		return false

	var entry: Variant = _cell_to_actor[grid_pos]
	if entry is Array:
		for actor in entry:
			if requester != null and actor == requester:
				continue
			if _blocking_actors.get(actor, true):
				return true
		return false
	else:
		var actor: Node = entry
		if requester != null and actor == requester:
			return false
		return _blocking_actors.get(actor, true)

func _update_actor_cell(actor: Node, grid_pos: Vector2i, allow_multi: bool = false) -> void:
	var old_cell: Variant = _actor_to_cell.get(actor, null)
	if old_cell != null:
		var prev: Variant = _cell_to_actor.get(old_cell, null)
		if prev != null:
			if prev is Array:
				prev.erase(actor)
				if prev.empty():
					_cell_to_actor.erase(old_cell)
				else:
					_cell_to_actor[old_cell] = prev
			elif prev == actor:
				_cell_to_actor.erase(old_cell)

	# If multi allowed, maintain array; otherwise replace existing occupant with warning
	var existing: Variant = _cell_to_actor.get(grid_pos, null)
	if allow_multi:
		var arr: Array = []
		if existing is Array:
			arr = existing
		elif existing != null:
			arr = [existing]
		if not arr.has(actor):
			arr.append(actor)
		_cell_to_actor[grid_pos] = arr
	else:
		if existing != null and existing != actor:
			push_warning("OccupancyManager: registering %s at %s but cell already occupied by %s (replacing)" % [str(actor), str(grid_pos), str(existing)])
		_cell_to_actor[grid_pos] = actor

	_actor_to_cell[actor] = grid_pos
	# Ensure actor's local grid_pos reflects canonical occupancy state
	if actor != null and "grid_pos" in actor:
		actor.grid_pos = grid_pos

	# Bump internal occupancy version and emit change
	_version += 1
	occupancy_changed.emit(grid_pos, actor)


func get_version() -> int:
	return _version

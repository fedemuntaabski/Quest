extends RefCounted
class_name MapNavigationHelper

## MapNavigationHelper: 4-directional BFS movement-range calculator.
## Produces both the 1-AP ("blue") and 2-AP dash ("yellow") zones in a
## single pass. A move never costs more than 2 AP regardless of a
## character's base_ap/move_range_per_ap — leftover AP just lets the
## player queue a second move afterward (TurnManager handles that for free).

const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


## Returns { "cells": {Vector2i: int(ap_cost)}, "came_from": {Vector2i: Vector2i} }
## `cells` excludes origin. `is_walkable` is a Callable(Vector2i) -> bool.
static func compute_movement_range(
	origin: Vector2i,
	current_ap: int,
	move_range_per_ap: int,
	is_walkable: Callable
) -> Dictionary:
	var cells: Dictionary = {}
	var came_from: Dictionary = {}

	if current_ap <= 0 or move_range_per_ap <= 0:
		return {"cells": cells, "came_from": came_from}

	var max_steps := move_range_per_ap * mini(current_ap, 2)
	var dist: Dictionary = {origin: 0}
	var queue: Array[Vector2i] = [origin]
	var head := 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_dist: int = dist[current]
		if current_dist >= max_steps:
			continue

		for offset in NEIGHBOR_OFFSETS:
			var neighbor := current + offset
			if dist.has(neighbor):
				continue
			if not is_walkable.call(neighbor):
				continue

			var neighbor_dist := current_dist + 1
			dist[neighbor] = neighbor_dist
			came_from[neighbor] = current
			queue.append(neighbor)

			var ap_cost := 1 if neighbor_dist <= move_range_per_ap else 2
			if ap_cost <= current_ap:
				cells[neighbor] = ap_cost

	return {"cells": cells, "came_from": came_from}


## Reconstructs the path from origin to target (inclusive of both ends)
## using the `came_from` map returned by compute_movement_range().
## Returns an empty array if target is unreachable.
static func build_path(came_from: Dictionary, origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if target == origin:
		path.append(origin)
		return path

	var current := target
	while current != origin:
		path.append(current)
		if not came_from.has(current):
			return []
		current = came_from[current]
	path.append(origin)
	path.reverse()
	return path

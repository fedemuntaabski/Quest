extends RefCounted
class_name CardTargeting

static func get_actor_cell(actor: Node, map_manager: MapManager) -> Variant:
	if actor == null:
		return null
	if actor.get("grid_pos") != null:
		return actor.get("grid_pos")
	if map_manager:
		return map_manager.get_actor_cell(actor)
	return null

static func get_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return max(absi(a.x - b.x), absi(a.y - b.y))

static func is_in_range(source: Node, target: Node, range_value: int, map_manager: MapManager) -> bool:
	var source_cell: Variant = get_actor_cell(source, map_manager)
	var target_cell: Variant = get_actor_cell(target, map_manager)
	if source_cell == null or target_cell == null:
		return false
	return get_chebyshev_distance(source_cell, target_cell) <= range_value

static func get_range_cells(center: Vector2i, range_value: int, map_manager: MapManager) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in range(-range_value, range_value + 1):
		for dy in range(-range_value, range_value + 1):
			var cell := center + Vector2i(dx, dy)
			if get_chebyshev_distance(center, cell) <= range_value:
				if map_manager == null or map_manager.is_within_bounds(cell):
					cells.append(cell)
	return cells

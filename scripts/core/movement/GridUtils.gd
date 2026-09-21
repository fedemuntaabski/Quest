extends RefCounted
class_name GridUtils

## GridUtils: cell <-> world position conversion against a TileMapLayer.
## Thin wrapper so callers never hardcode tile size / transform math directly.

static func cell_to_world(tilemap: TileMapLayer, cell: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell))


static func world_to_cell(tilemap: TileMapLayer, world_pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(world_pos))

extends TileMapLayer
class_name FloorGenerator

## FloorGenerator: fills floor tiles on demand, room by room, so unrevealed
## rooms stay both invisible and non-walkable (basic fog-of-war). Also
## supports the old "fill everything up front" mode for standalone/debug use.

@export var floor_atlas_coords: Vector2i = Vector2i(0, 0)
@export var floor_source_id: int = 0
@export var auto_fill_full_map: bool = false
@export var map_size: Vector2i = Vector2i(15, 15)


func _ready() -> void:
	if auto_fill_full_map:
		_generate_full_floor()


func _generate_full_floor() -> void:
	for x in range(map_size.x):
		for y in range(map_size.y):
			set_cell(Vector2i(x, y), floor_source_id, floor_atlas_coords)


## Reveals the given cells, painting the floor tile onto each.
func fill_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		set_cell(cell, floor_source_id, floor_atlas_coords)


func is_cell_filled(cell: Vector2i) -> bool:
	return get_cell_source_id(cell) != -1

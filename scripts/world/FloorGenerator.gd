extends TileMapLayer
class_name FloorGenerator

## FloorGenerator: fills a rectangular floor of the given size with the
## placeholder floor tile at _ready(). Replaces the old TestGrid._draw()
## reference grid with a real TileMapLayer usable by BFS/movement code.

@export var map_size: Vector2i = Vector2i(15, 15)
@export var floor_atlas_coords: Vector2i = Vector2i(0, 0)
@export var floor_source_id: int = 0


func _ready() -> void:
	_generate_floor()


func _generate_floor() -> void:
	for x in range(map_size.x):
		for y in range(map_size.y):
			set_cell(Vector2i(x, y), floor_source_id, floor_atlas_coords)

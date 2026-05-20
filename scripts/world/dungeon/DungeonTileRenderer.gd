extends DungeonMapRenderer
class_name DungeonTileRenderer

var floor_layer: TileMapLayer
var tile_set: TileSet

var floor_cells: Dictionary
var wall_cells: Dictionary
var grid_origin: Vector2

# --- TILE CONFIG (movido desde DungeonGenerator) ---
const TILE_MAIN_FLOOR := Vector2i(5, 10)
const TILE_VARIATIONS := [Vector2i(3,10), Vector2i(10, 8), Vector2i(7, 10), Vector2i(1, 10), Vector2i(2, 10)]

const TILE_EDGE_TOP := Vector2i(5, 9)
const TILE_EDGE_TOP_RIGHT := Vector2i(6, 9)
const TILE_EDGE_TOP_LEFT := Vector2i(4, 9)
const TILE_EDGE_BOTTOM := Vector2i(5, 11)
const TILE_EDGE_BOTTOM_RIGHT := Vector2i(6, 11)
const TILE_EDGE_BOTTOM_LEFT := Vector2i(4, 11)
const TILE_EDGE_LEFT := Vector2i(4, 10)
const TILE_EDGE_RIGHT := Vector2i(6, 10)

# ----------------------------

func setup(parent: Node, _tile_set: TileSet, _grid_origin: Vector2) -> void:
	tile_set = _tile_set
	grid_origin = _grid_origin

	floor_layer = TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.tile_set = tile_set
	floor_layer.position = grid_origin
	parent.add_child(floor_layer)


func set_data(_floor_cells: Dictionary, _wall_cells: Dictionary) -> void:
	floor_cells = _floor_cells
	wall_cells = _wall_cells


func build() -> void:
	floor_layer.clear()

	for cell in floor_cells.keys():
		_paint_cell(cell)


# ----------------------------
# CORE RENDER LOGIC
# ----------------------------

func _paint_cell(cell: Vector2i) -> void:
	var atlas_coords := TILE_MAIN_FLOOR

	# corners
	if wall_cells.has(cell + Vector2i.UP) and wall_cells.has(cell + Vector2i.LEFT):
		atlas_coords = TILE_EDGE_TOP_LEFT
	elif wall_cells.has(cell + Vector2i.UP) and wall_cells.has(cell + Vector2i.RIGHT):
		atlas_coords = TILE_EDGE_TOP_RIGHT
	elif wall_cells.has(cell + Vector2i.DOWN) and wall_cells.has(cell + Vector2i.LEFT):
		atlas_coords = TILE_EDGE_BOTTOM_LEFT
	elif wall_cells.has(cell + Vector2i.DOWN) and wall_cells.has(cell + Vector2i.RIGHT):
		atlas_coords = TILE_EDGE_BOTTOM_RIGHT

	# edges
	elif wall_cells.has(cell + Vector2i.UP):
		atlas_coords = TILE_EDGE_TOP
	elif wall_cells.has(cell + Vector2i.DOWN):
		atlas_coords = TILE_EDGE_BOTTOM
	elif wall_cells.has(cell + Vector2i.LEFT):
		atlas_coords = TILE_EDGE_LEFT
	elif wall_cells.has(cell + Vector2i.RIGHT):
		atlas_coords = TILE_EDGE_RIGHT

	# random floor variation
	else:
		if randf() < 0.3:
			atlas_coords = TILE_VARIATIONS.pick_random()

	# draw
	floor_layer.set_cell(cell, 0, atlas_coords)
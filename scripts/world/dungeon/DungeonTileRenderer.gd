extends DungeonMapRenderer
class_name DungeonTileRenderer

var floor_layer: TileMapLayer
var tile_set: TileSet

var floor_cells: Dictionary
var wall_cells: Dictionary
var grid_origin: Vector2

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
	# Legacy procedural tile painting is intentionally disabled here.
	# Floor and wall visuals are expected to come from prefab room scenes during
	# the migration away from the rectangle-based dungeon renderer.
	floor_layer.clear()
	return
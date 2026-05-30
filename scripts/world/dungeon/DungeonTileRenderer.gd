extends DungeonMapRenderer
class_name DungeonTileRenderer

var floor_layer: TileMapLayer
var tile_set: TileSet

var floor_cells: Dictionary
var wall_cells: Dictionary
var grid_origin: Vector2

var tile_main_floor: Vector2i = Vector2i(5, 10)
var tile_variations: Array[Vector2i] = [
	Vector2i(3, 10),
	Vector2i(10, 8),
	Vector2i(7, 10),
	Vector2i(1, 10),
	Vector2i(2, 10)
]
var tile_edge_top: Vector2i = Vector2i(5, 9)
var tile_edge_top_right: Vector2i = Vector2i(6, 9)
var tile_edge_top_left: Vector2i = Vector2i(4, 9)
var tile_edge_bottom: Vector2i = Vector2i(5, 11)
var tile_edge_bottom_right: Vector2i = Vector2i(6, 11)
var tile_edge_bottom_left: Vector2i = Vector2i(4, 11)
var tile_edge_left: Vector2i = Vector2i(4, 10)
var tile_edge_right: Vector2i = Vector2i(6, 10)
var tile_variation_chance: float = 0.3

# ----------------------------

func setup(parent: Node, _tile_set: TileSet, _grid_origin: Vector2) -> void:
	tile_set = _tile_set
	grid_origin = _grid_origin
	_apply_profile_from_parent(parent)

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
	var atlas_coords := tile_main_floor

	# corners
	if wall_cells.has(cell + Vector2i.UP) and wall_cells.has(cell + Vector2i.LEFT):
		atlas_coords = tile_edge_top_left
	elif wall_cells.has(cell + Vector2i.UP) and wall_cells.has(cell + Vector2i.RIGHT):
		atlas_coords = tile_edge_top_right
	elif wall_cells.has(cell + Vector2i.DOWN) and wall_cells.has(cell + Vector2i.LEFT):
		atlas_coords = tile_edge_bottom_left
	elif wall_cells.has(cell + Vector2i.DOWN) and wall_cells.has(cell + Vector2i.RIGHT):
		atlas_coords = tile_edge_bottom_right

	# edges
	elif wall_cells.has(cell + Vector2i.UP):
		atlas_coords = tile_edge_top
	elif wall_cells.has(cell + Vector2i.DOWN):
		atlas_coords = tile_edge_bottom
	elif wall_cells.has(cell + Vector2i.LEFT):
		atlas_coords = tile_edge_left
	elif wall_cells.has(cell + Vector2i.RIGHT):
		atlas_coords = tile_edge_right

	# random floor variation
	else:
		if randf() < tile_variation_chance and not tile_variations.is_empty():
			atlas_coords = tile_variations.pick_random()

	# draw
	floor_layer.set_cell(cell, 0, atlas_coords)


func _apply_profile_from_parent(parent: Node) -> void:
	if parent == null or not parent.has_method("get_floor_tile_profile"):
		return

	var profile_raw: Variant = parent.call("get_floor_tile_profile")
	if not (profile_raw is Dictionary):
		return

	var profile: Dictionary = profile_raw
	tile_main_floor = profile.get("main", tile_main_floor)
	tile_variations = profile.get("variations", tile_variations)
	tile_edge_top = profile.get("edge_top", tile_edge_top)
	tile_edge_top_right = profile.get("edge_top_right", tile_edge_top_right)
	tile_edge_top_left = profile.get("edge_top_left", tile_edge_top_left)
	tile_edge_bottom = profile.get("edge_bottom", tile_edge_bottom)
	tile_edge_bottom_right = profile.get("edge_bottom_right", tile_edge_bottom_right)
	tile_edge_bottom_left = profile.get("edge_bottom_left", tile_edge_bottom_left)
	tile_edge_left = profile.get("edge_left", tile_edge_left)
	tile_edge_right = profile.get("edge_right", tile_edge_right)
	tile_variation_chance = float(profile.get("variation_chance", tile_variation_chance))
extends Node2D
class_name FogOfWarManager

var fog_of_war: TileMapLayer
var visited_fog: TileMapLayer

var floor_cells: Dictionary
var grid_origin: Vector2
var tile_size: float
var wall_texture: Texture2D

# ─────────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────────
func setup(generator: Node2D, _floor_cells: Dictionary, _grid_origin: Vector2, _tile_size: float, _wall_texture: Texture2D) -> void:
	floor_cells = _floor_cells
	grid_origin = _grid_origin
	tile_size = _tile_size
	wall_texture = _wall_texture

	_ensure_layers(generator)

# ─────────────────────────────────────────────
# CREATE LAYERS
# ─────────────────────────────────────────────
func _ensure_layers(parent: Node) -> void:
	fog_of_war = _ensure_tile_map_layer(parent, "FogOfWar")
	visited_fog = _ensure_tile_map_layer(parent, "VisitedFog")

func _ensure_tile_map_layer(parent: Node, name: String) -> TileMapLayer:
	var existing := parent.get_node_or_null(name) as TileMapLayer
	if existing:
		return existing

	var layer := TileMapLayer.new()
	layer.name = name
	parent.add_child(layer)
	return layer

# ─────────────────────────────────────────────
# BUILD FOG
# ─────────────────────────────────────────────
func build() -> void:
	if fog_of_war == null or visited_fog == null:
		push_error("FogOfWarManager: layers not initialized. Did you call setup() before build()?")
		return
	_configure_fog_layer(fog_of_war, Color(0, 0, 0, 0.9))
	_configure_fog_layer(visited_fog, Color(0, 0, 0, 0.45))

	fog_of_war.clear()
	visited_fog.clear()

	fog_of_war.position = grid_origin
	visited_fog.position = grid_origin

	for cell in floor_cells.keys():
		fog_of_war.set_cell(cell, 0, Vector2i.ZERO, 0)

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────
func _configure_fog_layer(layer: TileMapLayer, tint: Color) -> void:
	layer.modulate = tint
	layer.z_index = 50

	if layer.tile_set:
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(int(tile_size), int(tile_size))

	var source := TileSetAtlasSource.new()
	source.texture = wall_texture
	source.texture_region_size = Vector2i(2, 2)
	source.create_tile(Vector2i.ZERO)

	tile_set.add_source(source, 0)
	layer.tile_set = tile_set

# ─────────────────────────────────────────────
# UPDATE VISIBILITY
# ─────────────────────────────────────────────
func update_room_state(room_infos: Array, active_room_id: int) -> void:
	if fog_of_war == null or visited_fog == null:
		push_error("FogOfWarManager no inicializado (fog_of_war null). Llamá setup() + build() primero.")
		return

	for room_info in room_infos:
		var room_id: int = room_info["id"]
		var room_cells: Array = room_info["floor_cells"]
		var is_active: bool = room_id == active_room_id
		var is_visited: bool = room_info.get("visited", false)

		for cell in room_cells:
			if is_active:
				fog_of_war.erase_cell(cell)
				visited_fog.erase_cell(cell)
			elif is_visited:
				fog_of_war.erase_cell(cell)
				visited_fog.set_cell(cell, 0, Vector2i.ZERO, 0)
			else:
				fog_of_war.set_cell(cell, 0, Vector2i.ZERO, 0)
				visited_fog.erase_cell(cell)

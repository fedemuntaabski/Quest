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
func update_room_state(room_layout_infos: Array, room_runtime_states: Array, active_room_id: int) -> void:
	if fog_of_war == null or visited_fog == null:
		push_error("FogOfWarManager no inicializado (fog_of_war null). Llamá setup() + build() primero.")
		return

	var preload_visible_set := _compute_preload_visible_set(room_layout_infos, active_room_id)

	for index in range(room_layout_infos.size()):
		var room_info: Dictionary = room_layout_infos[index]
		var runtime_state: DungeonRoomRuntimeState = null
		if index < room_runtime_states.size():
			runtime_state = room_runtime_states[index]

		var room_id: int = int(room_info.get("id", -1))
		var room_cells: Array = room_info.get("floor_cells", [])
		var is_active: bool = room_id == active_room_id
		var is_preload_visible: bool = preload_visible_set.has(room_id)
		var is_visited: bool = runtime_state != null and runtime_state.visited
		if room_cells.is_empty():
			continue

		for cell in room_cells:
			if is_active:
				fog_of_war.erase_cell(cell)
				visited_fog.erase_cell(cell)
			elif is_preload_visible:
				fog_of_war.erase_cell(cell)
				visited_fog.erase_cell(cell)
			elif is_visited:
				fog_of_war.erase_cell(cell)
				visited_fog.set_cell(cell, 0, Vector2i.ZERO, 0)
			else:
				fog_of_war.set_cell(cell, 0, Vector2i.ZERO, 0)
				visited_fog.erase_cell(cell)


func _compute_preload_visible_set(room_layout_infos: Array, active_room_id: int) -> Dictionary:
	var result: Dictionary = {}
	if active_room_id < 0:
		return result

	var room_by_id: Dictionary = {}
	for room_info in room_layout_infos:
		room_by_id[int(room_info.get("id", -1))] = room_info

	result[active_room_id] = true
	var active_info: Dictionary = room_by_id.get(active_room_id, {})
	for connected_id in active_info.get("connected_room_ids", []):
		var neighbor_id := int(connected_id)
		result[neighbor_id] = true
		var neighbor_info: Dictionary = room_by_id.get(neighbor_id, {})
		if not _is_corridor_room_info(neighbor_info):
			continue
		for corridor_neighbor_id in neighbor_info.get("connected_room_ids", []):
			result[int(corridor_neighbor_id)] = true

	return result


func _is_corridor_room_info(room_info: Dictionary) -> bool:
	if room_info.is_empty():
		return false
	var role := String(room_info.get("room_role", "")).to_lower()
	var room_type := String(room_info.get("room_type", "")).to_lower()
	var template := String(room_info.get("template", "")).to_lower()
	var scene_path := String(room_info.get("prefab_scene_path", "")).to_lower()
	return role == "corridor" or room_type == "corridor" or template.contains("corridor") or template.contains("pasillo") or scene_path.contains("/pasillo_")

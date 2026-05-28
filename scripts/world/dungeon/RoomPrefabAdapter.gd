extends RefCounted
class_name RoomPrefabAdapter

## RoomPrefabAdapter is the first safe bridge between authored room scenes and
## the live procedural dungeon. It is intentionally read-only from the point of
## view of generation: it can inspect and cache prefab metadata, but it does not
## replace the rectangle-based layout compiler or the generic runtime room path.
##
## The adapter exists so future modular rooms can be introduced without forcing
## the current runtime to rescan scenes every frame or to depend on live prefab
## instancing before the rest of the dungeon stack is ready.

const MARKER_ROOT_NAME := &"Puertas"

var dungeon: DungeonGenerator = null
var _scene_cache: Dictionary = {}


func setup(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon


func inspect_template(template: RoomTemplateData) -> Dictionary:
	if template == null or template.room_scene == null:
		return {}

	var cache_key := _template_cache_key(template)
	if _scene_cache.has(cache_key):
		return _scene_cache[cache_key].duplicate(true)

	var snapshot := inspect_scene(template.room_scene)
	snapshot["template"] = template.to_dictionary()
	_scene_cache[cache_key] = snapshot.duplicate(true)
	return snapshot.duplicate(true)


func inspect_scene(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}

	var cache_key := _scene_cache_key(scene)
	if _scene_cache.has(cache_key):
		return _scene_cache[cache_key].duplicate(true)

	var instance := instantiate_scene(scene)
	if instance == null:
		return {}

	var snapshot := _inspect_scene_root(instance, scene.resource_path)
	_free_scene_instance(instance)
	_scene_cache[cache_key] = snapshot.duplicate(true)
	return snapshot.duplicate(true)


func inspect_room_root(room_root: Node, scene_path: String = "") -> Dictionary:
	if room_root == null:
		return {}

	return _inspect_scene_root(room_root, scene_path)


func instantiate_scene(scene: PackedScene, parent: Node = null, room_origin_world: Vector2 = Vector2.ZERO, rotation_degrees: int = 0) -> Node:
	if scene == null:
		return null

	var instance := scene.instantiate()
	if instance == null:
		return null

	if instance is Node2D:
		var node_2d := instance as Node2D
		node_2d.position = room_origin_world
		node_2d.rotation_degrees = float(_normalize_rotation(rotation_degrees))

	if parent != null:
		parent.add_child(instance)

	return instance


func create_prefab_room_instance(template: RoomTemplateData, parent: Node = null, room_origin_world: Vector2 = Vector2.ZERO, rotation_degrees: int = 0) -> Node:
	if template == null or template.room_scene == null:
		return null

	# The instance is created safely, but the live path should only use this when
	# a future prefab-backed room pipeline is explicitly enabled.
	return instantiate_scene(template.room_scene, parent, room_origin_world, rotation_degrees)


func build_rotation_ready_transform(room_origin_world: Vector2, rotation_degrees: int, room_size: Vector2i, tile_size: float = 16.0) -> Dictionary:
	return {
		"origin_world": room_origin_world,
		"rotation_degrees": _normalize_rotation(rotation_degrees),
		"room_size": room_size,
		"tile_size": tile_size
	}


func extract_connectors_from_scene_root(room_root: Node, tile_size: float = 16.0) -> Array[RoomConnectorData]:
	return RoomConnectorAdapter.extract_connectors_from_scene(room_root, tile_size)


func extract_spawn_markers_from_scene_root(room_root: Node, tile_size: float = 16.0) -> Array[RoomConnectorData]:
	var connectors: Array[RoomConnectorData] = []
	if room_root == null:
		return connectors

	var marker_nodes: Array[Marker2D] = []
	_collect_spawn_markers(room_root, marker_nodes)
	for index in range(marker_nodes.size()):
		var connector := RoomConnectorAdapter.connector_from_marker(marker_nodes[index], room_root, tile_size, index)
		if connector == null:
			continue
		connector.connector_type = RoomConnectorData.ConnectorType.SPAWN
		connector.tags.append(&"spawn_marker")
		connector.metadata["kind"] = "spawn_marker"
		connectors.append(connector)

	return connectors


func get_entrada_marker(room_root: Node) -> Node2D:
	return _find_marker_by_names(room_root, ["Entrada", "entrada", "puerta_entrada", "door_entry"])


func get_salida_marker(room_root: Node) -> Node2D:
	return _find_marker_by_names(room_root, ["Salida", "salida", "puerta_salida", "door_exit"])


func get_spawn_jugador_marker(room_root: Node) -> Node2D:
	return _find_marker_by_names(room_root, ["Spawn_Jugador", "Spawn_jugador", "spawn_jugador", "spawn_jugador"])


func get_spawn_tutorial_marker(room_root: Node) -> Node2D:
	return _find_marker_by_names(room_root, ["Spawn_Tutorial", "Spawn_tutorial", "spawn_tutorial", "spawntutorial"])


func get_spawn_enemigos_marker(room_root: Node) -> Node2D:
	return _find_marker_by_names(room_root, ["SpawnEnemigos", "Spawn_Enemigos", "spawn_enemigos", "spawnenemigos"])


func resolve_marker_references(room_root: Node) -> Dictionary:
	return {
		"Entrada": get_entrada_marker(room_root),
		"Salida": get_salida_marker(room_root),
		"Spawn_Jugador": get_spawn_jugador_marker(room_root),
		"Spawn_Tutorial": get_spawn_tutorial_marker(room_root),
		"SpawnEnemigos": get_spawn_enemigos_marker(room_root)
	}


func extract_room_bounds_from_scene_root(room_root: Node) -> Rect2i:
	var floor_cell_map := extract_local_floor_cell_map(room_root)
	if floor_cell_map.is_empty():
		return Rect2i()

	var cells: Array[Vector2i] = []
	for raw_cell in floor_cell_map.keys():
		cells.append(raw_cell)

	var min_cell := cells[0]
	var max_cell := cells[0]
	for cell in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)

	return Rect2i(min_cell, (max_cell - min_cell) + Vector2i.ONE)


func extract_local_floor_cells_from_scene_root(room_root: Node, tile_size: float = 16.0) -> Array[Vector2i]:
	var floor_cell_map := extract_local_floor_cell_map(room_root)
	var floor_cells: Array[Vector2i] = []
	for raw_cell in floor_cell_map.keys():
		floor_cells.append(raw_cell)
	return floor_cells


func extract_world_floor_cells_with_tilemap_transforms(room_root: Node, world_to_grid: Callable) -> Array[Vector2i]:
	var result_map: Dictionary = {}
	if room_root == null:
		return []

	var tile_layers: Array[TileMapLayer] = []
	_collect_tile_layers(room_root, tile_layers)
	for layer in tile_layers:
		if layer == null:
			continue

		var included_local_cells: Dictionary = {}
		var found_custom_data := false
		var used_cell_count := 0
		for raw_cell in layer.get_used_cells():
			used_cell_count += 1
			var cell := Vector2i(raw_cell)
			var tile_data := layer.get_cell_tile_data(cell)
			if tile_data == null:
				continue
			found_custom_data = true
			if tile_data.get_custom_data("caminable") == true:
				included_local_cells[cell] = true

		if not found_custom_data:
			for raw_cell in layer.get_used_cells():
				included_local_cells[Vector2i(raw_cell)] = true

		for local_cell_variant in included_local_cells.keys():
			var local_cell := Vector2i(local_cell_variant)
			# TileMapLayer transform is authoritative; map_to_local returns tile-space
			# center in layer-local coordinates, then to_global applies full transform.
			var world_position := layer.to_global(layer.map_to_local(local_cell))
			var grid_cell := Vector2i(local_cell)
			if world_to_grid.is_valid():
				grid_cell = Vector2i(world_to_grid.call(world_position))
			result_map[grid_cell] = true

		if OS.is_debug_build():
			var local_cells: Array[Vector2i] = []
			for raw_local_cell in included_local_cells.keys():
				local_cells.append(Vector2i(raw_local_cell))
			local_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				if a.y == b.y:
					return a.x < b.x
				return a.y < b.y
			)
			var world_cells: Array[Vector2i] = []
			for raw_world_cell in result_map.keys():
				world_cells.append(Vector2i(raw_world_cell))
			world_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				if a.y == b.y:
					return a.x < b.x
				return a.y < b.y
			)
			var sample_local := local_cells.slice(0, mini(8, local_cells.size()))
			var sample_world := world_cells.slice(0, mini(8, world_cells.size()))
			print("RoomPrefabAdapter: tile layer extract room=%s layer=%s used=%d included=%d custom_data=%s sample_local=%s sample_world=%s" % [room_root.name if room_root else "NULL", layer.name, used_cell_count, included_local_cells.size(), str(found_custom_data), str(sample_local), str(sample_world)])

	var floor_cells: Array[Vector2i] = []
	for raw_cell in result_map.keys():
		floor_cells.append(Vector2i(raw_cell))
	if OS.is_debug_build():
		var extracted_bounds := Rect2i()
		if not floor_cells.is_empty():
			var min_cell := floor_cells[0]
			var max_cell := floor_cells[0]
			for cell in floor_cells:
				min_cell.x = mini(min_cell.x, cell.x)
				min_cell.y = mini(min_cell.y, cell.y)
				max_cell.x = maxi(max_cell.x, cell.x)
				max_cell.y = maxi(max_cell.y, cell.y)
			extracted_bounds = Rect2i(min_cell, (max_cell - min_cell) + Vector2i.ONE)
		print("RoomPrefabAdapter: world floor extract room=%s count=%d bounds=%s sample=%s" % [room_root.name if room_root else "NULL", floor_cells.size(), str(extracted_bounds), str(floor_cells.slice(0, mini(8, floor_cells.size())))])
	return floor_cells


func build_world_floor_cells_from_local_cells(local_floor_cells: Array, room_origin_cell: Vector2i, room_size: Vector2i, rotation_degrees: int = 0) -> Array[Vector2i]:
	var world_floor_cells: Array[Vector2i] = []
	for raw_cell in local_floor_cells:
		var local_cell := Vector2i(raw_cell)
		world_floor_cells.append(local_cell_to_world_cell(local_cell, room_origin_cell, room_size, rotation_degrees))
	return world_floor_cells


func extract_world_floor_cells_from_scene_root(room_root: Node, room_origin_cell: Vector2i, room_size: Vector2i, rotation_degrees: int = 0) -> Array[Vector2i]:
	var local_floor_cells := extract_local_floor_cells_from_scene_root(room_root)
	return build_world_floor_cells_from_local_cells(local_floor_cells, room_origin_cell, room_size, rotation_degrees)


func extract_local_floor_cell_map(room_root: Node) -> Dictionary:
	var floor_cell_map: Dictionary = {}
	if room_root == null:
		return floor_cell_map

	var tile_layers: Array[TileMapLayer] = []
	_collect_tile_layers(room_root, tile_layers)
	for layer in tile_layers:
		if layer == null:
			continue
		var found_custom_data := false
		var used_cell_count := 0
		for raw_cell in layer.get_used_cells():
			used_cell_count += 1
			var cell := Vector2i(raw_cell)
			var tile_data := layer.get_cell_tile_data(cell)
			if tile_data == null:
				continue

			found_custom_data = true
			if tile_data.get_custom_data("caminable") == true:
				floor_cell_map[cell] = true

		if not found_custom_data:
			for raw_cell in layer.get_used_cells():
				floor_cell_map[Vector2i(raw_cell)] = true

		if OS.is_debug_build():
			var local_cells: Array[Vector2i] = []
			for raw_local_cell in floor_cell_map.keys():
				local_cells.append(Vector2i(raw_local_cell))
			local_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				if a.y == b.y:
					return a.x < b.x
				return a.y < b.y
			)
			var sample_local := local_cells.slice(0, mini(8, local_cells.size()))
			print("RoomPrefabAdapter: local floor extract room=%s layer=%s used=%d floor=%d custom_data=%s sample=%s" % [room_root.name if room_root else "NULL", layer.name, used_cell_count, floor_cell_map.size(), str(found_custom_data), str(sample_local)])

	if floor_cell_map.is_empty():
		# Compatibility fallback: if a room has no tile cells yet, treat known
		# marker cells as a minimal geometry hint so the adapter can still report
		# a stable local footprint for inspection and future migration work.
		_collect_marker_cells(room_root, floor_cell_map)
		if OS.is_debug_build():
			print("RoomPrefabAdapter: marker fallback room=%s floor=%d" % [room_root.name if room_root else "NULL", floor_cell_map.size()])

	return floor_cell_map


func extract_transformed_local_cell(local_cell: Vector2i, room_size: Vector2i, rotation_degrees: int) -> Vector2i:
	var normalized_rotation := _normalize_rotation(rotation_degrees)
	match normalized_rotation:
		90:
			return Vector2i(room_size.y - 1 - local_cell.y, local_cell.x)
		180:
			return Vector2i(room_size.x - 1 - local_cell.x, room_size.y - 1 - local_cell.y)
		270:
			return Vector2i(local_cell.y, room_size.x - 1 - local_cell.x)
		_:
			return local_cell


func local_cell_to_world_cell(local_cell: Vector2i, room_origin_cell: Vector2i, room_size: Vector2i, rotation_degrees: int) -> Vector2i:
	return room_origin_cell + extract_transformed_local_cell(local_cell, room_size, rotation_degrees)


func local_cell_to_world_position(local_cell: Vector2i, room_origin_world: Vector2, room_size: Vector2i, tile_size: float, rotation_degrees: int) -> Vector2:
	var world_cell := extract_transformed_local_cell(local_cell, room_size, rotation_degrees)
	return room_origin_world + (Vector2(world_cell) + Vector2(0.5, 0.5)) * tile_size


func local_position_to_world_position(local_position: Vector2, room_origin_world: Vector2, room_size: Vector2i, tile_size: float, rotation_degrees: int) -> Vector2:
	var local_cell := Vector2i(floori(local_position.x / tile_size), floori(local_position.y / tile_size))
	return local_cell_to_world_position(local_cell, room_origin_world, room_size, tile_size, rotation_degrees)


func clear_cache() -> void:
	_scene_cache.clear()


func _inspect_scene_root(room_root: Node, scene_path: String) -> Dictionary:
	var floor_cell_map := extract_local_floor_cell_map(room_root)
	var local_bounds := extract_room_bounds_from_scene_root(room_root)
	var floor_cells: Array[Vector2i] = []
	for raw_cell in floor_cell_map.keys():
		floor_cells.append(raw_cell)
	floor_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)

	return {
		"scene_path": scene_path,
		"scene_name": room_root.name if room_root else "",
		"local_bounds": local_bounds,
		"local_floor_cells": floor_cells.duplicate(true),
		"local_floor_cell_map": floor_cell_map.duplicate(true),
		"connectors": extract_connectors_from_scene_root(room_root),
		"spawn_markers": extract_spawn_markers_from_scene_root(room_root),
		"rotation_ready": true,
		"supports_rotation": true,
		"marker_root_name": String(MARKER_ROOT_NAME)
	}


func _collect_marker_cells(room_root: Node, floor_cell_map: Dictionary) -> void:
	var connectors := RoomConnectorAdapter.extract_connectors_from_scene(room_root)
	for connector in connectors:
		if connector == null:
			continue
		floor_cell_map[connector.local_cell] = true

	for spawn_marker in extract_spawn_markers_from_scene_root(room_root):
		if spawn_marker == null:
			continue
		floor_cell_map[spawn_marker.local_cell] = true


func _collect_spawn_markers(node: Node, result: Array[Marker2D]) -> void:
	if node == null:
		return

	if node is Marker2D and _looks_like_spawn_marker(node as Marker2D):
		result.append(node as Marker2D)

	for child in node.get_children():
		if child is Node:
			_collect_spawn_markers(child, result)


func _collect_tile_layers(node: Node, result: Array[TileMapLayer]) -> void:
	if node == null:
		return

	if node is TileMapLayer:
		result.append(node as TileMapLayer)

	for child in node.get_children():
		if child is Node:
			_collect_tile_layers(child, result)


func _looks_like_spawn_marker(marker: Marker2D) -> bool:
	if marker == null:
		return false

	var normalized := marker.name.to_lower()
	return normalized.contains("spawn") or normalized.contains("spawnenemigos") or normalized.contains("spawn_jugador") or normalized.contains("spawn_tutorial")


func _find_marker_by_names(room_root: Node, candidate_names: Array[String]) -> Node2D:
	if room_root == null:
		return null

	var wanted: Array[String] = []
	for candidate in candidate_names:
		wanted.append(candidate.to_lower())

	var marker_nodes: Array[Node] = []
	_collect_markers_by_name(room_root, marker_nodes, wanted)
	if marker_nodes.is_empty():
		return null

	return marker_nodes[0] as Node2D


func _collect_markers_by_name(node: Node, result: Array[Node], wanted_names: Array[String]) -> void:
	if node == null:
		return

	if node is Node2D:
		var normalized := node.name.to_lower()
		for wanted_name in wanted_names:
			if normalized == wanted_name or normalized.contains(wanted_name):
				result.append(node)
				break

	for child in node.get_children():
		if child is Node:
			_collect_markers_by_name(child, result, wanted_names)


func _scene_cache_key(scene: PackedScene) -> String:
	if scene == null:
		return ""
	if scene.resource_path != "":
		return scene.resource_path
	return "%s:%s" % [scene.get_class(), scene.resource_name]


func _template_cache_key(template: RoomTemplateData) -> String:
	if template == null:
		return ""
	if template.room_scene != null and template.room_scene.resource_path != "":
		return template.room_scene.resource_path
	return "%s:%s" % [String(template.room_type), String(template.spawn_profile)]


func _normalize_rotation(rotation_degrees: int) -> int:
	var normalized_rotation := int(rotation_degrees) % 360
	if normalized_rotation < 0:
		normalized_rotation += 360
	return normalized_rotation


func _free_scene_instance(instance: Node) -> void:
	if instance == null:
		return
	instance.free()
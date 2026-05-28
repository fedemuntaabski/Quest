extends RefCounted
class_name DungeonAssembler

const TUTORIAL_ROOM_SCENE := preload("res://scenes/sala_tutorial.tscn")
const CORRIDOR_SCENE := preload("res://scenes/pasillo_1.tscn")
const ROOM_1_SCENE := preload("res://scenes/sala_1.tscn")

var dungeon: DungeonGenerator = null
var room_prefab_adapter: RoomPrefabAdapter = null

var _assembled_rooms: Dictionary = {}
var _assembled_corridors: Dictionary = {}
var _assembled_marker_refs: Dictionary = {}
var _assembled_layout_data: DungeonLayoutData = null


func setup(p_dungeon: DungeonGenerator, p_room_prefab_adapter: RoomPrefabAdapter) -> void:
	dungeon = p_dungeon
	room_prefab_adapter = p_room_prefab_adapter


func clear() -> void:
	_assembled_rooms.clear()
	_assembled_corridors.clear()
	_assembled_marker_refs.clear()
	_assembled_layout_data = null


func assemble_hardcoded_slice(rooms_root: Node2D = null, corridors_root: Node2D = null) -> DungeonLayoutData:
	clear()

	if dungeon == null or room_prefab_adapter == null:
		return null

	var layout := DungeonLayoutData.new()
	var graph := DungeonGraph.new()

	var tutorial_room := _assemble_room(
		0,
		TUTORIAL_ROOM_SCENE,
		&"tutorial_room",
		&"tutorial",
		true,
		rooms_root,
		dungeon.grid_to_world_coords(Vector2i(10, 10))
	)
	if tutorial_room.is_empty():
		return null

	var corridor := _assemble_corridor(
		0,
		1,
		CORRIDOR_SCENE,
		corridors_root,
		tutorial_room
	)
	if corridor.is_empty():
		return null

	var room_1 := _assemble_room_against_marker(
		1,
		ROOM_1_SCENE,
		&"normal_room",
		&"normal",
		false,
		rooms_root,
		corridor,
		"Salida",
		"Entrada"
	)
	if room_1.is_empty():
		return null

	var room_records: Array[Dictionary] = [tutorial_room, room_1]
	for room_record in room_records:
		graph.add_room(int(room_record.get("id", -1)), room_record)

	graph.add_edge(0, 1, corridor.get("corridor_cells", []))
	graph.set_edge_runtime_node(0, 1, corridor.get("visual_root", null))

	tutorial_room["connected_room_ids"] = [1]
	tutorial_room["corridor_connections"] = [{"room_id": 1, "corridor_cells": corridor.get("corridor_cells", []).duplicate(true)}]
	room_1["connected_room_ids"] = [0]
	room_1["corridor_connections"] = [{"room_id": 0, "corridor_cells": corridor.get("corridor_cells", []).duplicate(true)}]

	var room_layouts: Array[DungeonRoomLayoutState] = []
	for room_record in room_records:
		room_layouts.append(_build_room_layout_state(room_record))

	var floor_cells: Dictionary = {}
	for room_record in room_records:
		for cell in room_record.get("floor_cells", []):
			floor_cells[Vector2i(cell)] = true
	for cell in corridor.get("floor_cells", []):
		floor_cells[Vector2i(cell)] = true

	var corridor_cells: Dictionary = {}
	for cell in corridor.get("corridor_cells", []):
		corridor_cells[Vector2i(cell)] = true

	layout.room_layouts = room_layouts
	layout.floor_cells = floor_cells
	layout.corridor_cells = corridor_cells
	layout.room_infos = room_records
	layout.graph = graph
	layout.metadata = {
		"assembly_mode": "prefab_native_hardcoded",
		"path": [0, 1],
		"room_count": room_records.size()
	}

	_assembled_layout_data = layout
	return layout


func get_assembled_layout_data() -> DungeonLayoutData:
	return _assembled_layout_data


func get_assembled_room_reference(room_id: int) -> Node2D:
	var room_record: Dictionary = _assembled_rooms.get(room_id, {})
	return room_record.get("visual_root", null)


func get_assembled_room_references() -> Dictionary:
	var references: Dictionary = {}
	for room_id_variant in _assembled_rooms.keys():
		references[int(room_id_variant)] = _assembled_rooms[room_id_variant].get("visual_root", null)
	return references


func get_assembled_corridor_reference(room_a: int, room_b: int) -> Node2D:
	return _assembled_corridors.get(_edge_key(room_a, room_b), null)


func get_assembled_marker_refs(room_id: int) -> Dictionary:
	var room_record: Dictionary = _assembled_rooms.get(room_id, {})
	return room_record.get("marker_refs", {}).duplicate(true)


func get_assembled_room_record(room_id: int) -> Dictionary:
	return _assembled_rooms.get(room_id, {}).duplicate(true)


func _assemble_room(
	room_id: int,
	scene: PackedScene,
	template_name: StringName,
	spawn_profile: StringName,
	is_tutorial: bool,
	parent: Node2D,
	initial_world_position: Vector2
) -> Dictionary:
	if scene == null:
		return {}

	var instance := room_prefab_adapter.instantiate_scene(scene, parent, initial_world_position)
	if instance == null or not (instance is Node2D):
		return {}

	return _build_room_record_from_instance(room_id, instance as Node2D, scene, template_name, spawn_profile, is_tutorial)


func _assemble_room_against_marker(
	room_id: int,
	scene: PackedScene,
	template_name: StringName,
	spawn_profile: StringName,
	is_tutorial: bool,
	parent: Node2D,
	anchor_room: Dictionary,
	anchor_marker_name: String,
	own_marker_name: String
) -> Dictionary:
	if scene == null:
		return {}

	var instance := room_prefab_adapter.instantiate_scene(scene, parent, Vector2.ZERO)
	if instance == null or not (instance is Node2D):
		return {}

	var room_root := instance as Node2D
	var target_marker := _get_marker_from_record(anchor_room, anchor_marker_name)
	var own_marker := _get_marker_for_room(room_root, own_marker_name)
	if target_marker != null and own_marker != null:
		room_root.global_position += target_marker.global_position - own_marker.global_position

	return _build_room_record_from_instance(room_id, room_root, scene, template_name, spawn_profile, is_tutorial)


func _assemble_corridor(
	room_a: int,
	room_b: int,
	scene: PackedScene,
	parent: Node2D,
	anchor_room: Dictionary
) -> Dictionary:
	if scene == null:
		return {}

	var instance := room_prefab_adapter.instantiate_scene(scene, parent, Vector2.ZERO)
	if instance == null or not (instance is Node2D):
		return {}

	var corridor_root := instance as Node2D
	var entry_marker := _get_marker_for_room(corridor_root, "Entrada")
	var exit_marker := _get_marker_for_room(corridor_root, "Salida")
	var anchor_exit := _get_marker_from_record(anchor_room, "Salida")
	if anchor_exit != null and entry_marker != null:
		corridor_root.global_position += anchor_exit.global_position - entry_marker.global_position

	var corridor_floor_cells := _extract_world_floor_cells(corridor_root)
	var room_rect := _rect_from_cells(corridor_floor_cells)
	var center_cell := _center_cell_from_rect(room_rect)
	var corridor_cells := corridor_floor_cells.duplicate(true)
	var snapshot := room_prefab_adapter.inspect_scene(scene)

	var corridor_record := {
		"room_a": room_a,
		"room_b": room_b,
		"visual_root": corridor_root,
		"snapshot": snapshot,
		"marker_refs": room_prefab_adapter.resolve_marker_references(corridor_root),
		"corridor_cells": corridor_cells,
		"floor_cells": corridor_floor_cells,
		"rect": room_rect,
		"center_cell": center_cell,
		"entry_marker": entry_marker,
		"exit_marker": exit_marker,
		"template": DungeonGraph.TEMPLATE_CORRIDOR,
		"prefab_scene_path": scene.resource_path,
		"prefab_rotation_degrees": int(corridor_root.rotation_degrees)
	}

	_assembled_corridors[_edge_key(room_a, room_b)] = corridor_root
	return corridor_record


func _build_room_record_from_instance(
	room_id: int,
	room_root: Node2D,
	scene: PackedScene,
	template_name: StringName,
	spawn_profile: StringName,
	is_tutorial: bool
) -> Dictionary:
	if room_root == null or scene == null:
		return {}

	var snapshot := room_prefab_adapter.inspect_scene(scene)
	var marker_refs := room_prefab_adapter.resolve_marker_references(room_root)
	var spawn_markers := room_prefab_adapter.extract_spawn_markers_from_scene_root(room_root)
	var local_floor_cells: Array = snapshot.get("local_floor_cells", [])
	# Use prefab-adapter-extracted world floor cells (caminable-first). This
	# ensures the authored TileMap data drives gameplay walkability.
	var floor_cells := _extract_world_floor_cells(room_root)
	var room_rect := _rect_from_cells(floor_cells)
	var center_cell := _center_cell_from_rect(room_rect)

	var room_record := {
		"id": room_id,
		"rect": room_rect,
		"local_bounds": snapshot.get("local_bounds", Rect2i(Vector2i.ZERO, room_rect.size)),
		"center_cell": center_cell,
		"floor_cells": floor_cells,
		"local_floor_cells": local_floor_cells,
		"connectors": snapshot.get("connectors", []),
		"spawn_markers": spawn_markers,
		"corridor_connections": [],
		"connected_room_ids": [],
		"template": String(template_name),
		"room_role": "tutorial" if is_tutorial else "normal",
		"visual_root": room_root,
		"marker_refs": marker_refs,
		"prefab_scene_path": scene.resource_path,
		"prefab_rotation_degrees": int(room_root.rotation_degrees),
		"room_prefab_snapshot": snapshot,
		"spawn_profile": String(spawn_profile),
		"topology_metadata": {
			"assembly_mode": "prefab_native_hardcoded",
			"is_main_path": true if room_id in [0, 1] else false
		}
	}

	_assembled_rooms[room_id] = room_record.duplicate(true)
	_assembled_marker_refs[room_id] = marker_refs.duplicate(true)
	return room_record


func _build_room_layout_state(room_record: Dictionary) -> DungeonRoomLayoutState:
	return DungeonRoomLayoutState.new(
		int(room_record.get("id", -1)),
		room_record.get("rect", Rect2i()),
		room_record.get("floor_cells", []),
		room_record.get("local_floor_cells", []),
		room_record.get("connectors", []),
		room_record.get("corridor_connections", []),
		room_record.get("connected_room_ids", []),
		String(room_record.get("template", "")),
		room_record.get("topology_metadata", {})
	)


func _extract_world_floor_cells(room_root: Node2D) -> Array[Vector2i]:
	var floor_cells: Array[Vector2i] = []
	if room_root == null or dungeon == null:
		return floor_cells

	# Prefab-authored TileMap geometry is authoritative here. Use the
	# RoomPrefabAdapter extraction which prioritizes the `caminable` custom
	# data layer and falls back to used-cell detection only when necessary.
	var local_floor_cells := room_prefab_adapter.extract_local_floor_cells_from_scene_root(room_root, dungeon.tile_size)
	for raw_cell in local_floor_cells:
		var local_cell := Vector2i(raw_cell)
		var world_position := room_root.to_global(Vector2(local_cell) * dungeon.tile_size)
		floor_cells.append(dungeon.world_to_grid_coords(world_position))

	return floor_cells


func _collect_tile_layers(node: Node, result: Array[TileMapLayer]) -> void:
	if node == null:
		return

	if node is TileMapLayer:
		result.append(node as TileMapLayer)

	for child in node.get_children():
		if child is Node:
			_collect_tile_layers(child, result)


func _rect_from_cells(cells: Array[Vector2i]) -> Rect2i:
	if cells.is_empty():
		return Rect2i()

	var min_cell := cells[0]
	var max_cell := cells[0]
	for cell in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	return Rect2i(min_cell, (max_cell - min_cell) + Vector2i.ONE)


func _center_cell_from_rect(room_rect: Rect2i) -> Vector2i:
	if room_rect.size == Vector2i.ZERO:
		return Vector2i.ZERO
	return Vector2i(
		room_rect.position.x + int(room_rect.size.x * 0.5),
		room_rect.position.y + int(room_rect.size.y * 0.5)
	)


func _get_marker_from_record(room_record: Dictionary, marker_name: String) -> Node2D:
	var marker_refs: Dictionary = room_record.get("marker_refs", {})
	return marker_refs.get(marker_name, null)


func _get_marker_for_room(room_root: Node2D, marker_name: String) -> Node2D:
	if room_prefab_adapter == null or room_root == null:
		return null

	match marker_name:
		"Entrada":
			return room_prefab_adapter.get_entrada_marker(room_root)
		"Salida":
			return room_prefab_adapter.get_salida_marker(room_root)
		"Spawn_Jugador":
			return room_prefab_adapter.get_spawn_jugador_marker(room_root)
		"Spawn_Tutorial":
			return room_prefab_adapter.get_spawn_tutorial_marker(room_root)
		"SpawnEnemigos":
			return room_prefab_adapter.get_spawn_enemigos_marker(room_root)
		_:
			return null


func _edge_key(room_a: int, room_b: int) -> String:
	var low := mini(room_a, room_b)
	var high := maxi(room_a, room_b)
	return "%d_%d" % [low, high]
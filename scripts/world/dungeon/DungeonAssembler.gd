extends RefCounted
class_name DungeonAssembler

const TUTORIAL_ROOM_SCENE := preload("res://scenes/sala_tutorial.tscn")
const CORRIDOR_SCENE := preload("res://scenes/pasillo_1.tscn")
const ROOM_1_SCENE := preload("res://scenes/sala_1.tscn")
const TUTORIAL_CORRIDOR_DOWN_OFFSET_TILES := 5

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
	if OS.is_debug_build():
		print("DungeonAssembler: room %d %s origin=%s markers=%s scene=%s" % [int(tutorial_room.get("id", -1)), String(tutorial_room.get("template", "")), str((tutorial_room.get("visual_root", null) as Node2D).global_position if tutorial_room.get("visual_root", null) else Vector2.ZERO), tutorial_room.get("marker_refs", {}).keys(), tutorial_room.get("prefab_scene_path", "")])

	var corridor := _assemble_corridor(
		0,
		1,
		CORRIDOR_SCENE,
		corridors_root,
		tutorial_room
	)
	if corridor.is_empty():
		return null
	if OS.is_debug_build():
		print("DungeonAssembler: corridor %d->%d origin=%s markers=%s scene=%s" % [int(corridor.get("room_a", -1)), int(corridor.get("room_b", -1)), str((corridor.get("visual_root", null) as Node2D).global_position if corridor.get("visual_root", null) else Vector2.ZERO), [corridor.get("entry_marker", null).name if corridor.get("entry_marker", null) else "", corridor.get("exit_marker", null).name if corridor.get("exit_marker", null) else ""], corridor.get("snapshot", {}).get("scene_path", "")])

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

	_reconcile_corridor_room_overlap(corridor, tutorial_room, ["Entrada", "Salida"])
	_reconcile_corridor_room_overlap(corridor, room_1, ["Salida", "Entrada"])
	var corridor_room := _build_corridor_room_record(2, corridor)
	if corridor_room.is_empty():
		return null
	if OS.is_debug_build():
		var c_before := int(corridor.get("floor_cells", []).size())
		var c_cells := _cells_to_set(corridor.get("corridor_cells", []))
		print("DungeonAssembler: corridor-room seam resolved corridor_cells=%d floor_cells=%d" % [c_cells.size(), c_before])
	if OS.is_debug_build():
		print("DungeonAssembler: room %d %s origin=%s markers=%s scene=%s" % [int(room_1.get("id", -1)), String(room_1.get("template", "")), str((room_1.get("visual_root", null) as Node2D).global_position if room_1.get("visual_root", null) else Vector2.ZERO), room_1.get("marker_refs", {}).keys(), room_1.get("prefab_scene_path", "")])
		_debug_trace_tutorial_connectivity(tutorial_room, corridor, room_1)

	var room_records: Array[Dictionary] = [tutorial_room, room_1, corridor_room]
	for room_record in room_records:
		graph.add_room(int(room_record.get("id", -1)), room_record)

	graph.add_edge(0, 2, corridor.get("corridor_cells", []))
	graph.add_edge(2, 1, corridor.get("corridor_cells", []))
	graph.set_edge_runtime_node(0, 2, corridor.get("visual_root", null))
	graph.set_edge_runtime_node(2, 1, corridor.get("visual_root", null))

	tutorial_room["connected_room_ids"] = [2]
	tutorial_room["corridor_connections"] = [{"room_id": 2, "corridor_cells": corridor.get("corridor_cells", []).duplicate(true)}]
	room_1["connected_room_ids"] = [2]
	room_1["corridor_connections"] = [{"room_id": 2, "corridor_cells": corridor.get("corridor_cells", []).duplicate(true)}]
	corridor_room["connected_room_ids"] = [0, 1]
	corridor_room["corridor_connections"] = [
		{"room_id": 0, "corridor_cells": corridor.get("corridor_cells", []).duplicate(true)},
		{"room_id": 1, "corridor_cells": corridor.get("corridor_cells", []).duplicate(true)}
	]

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
		"path": [0, 2, 1],
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
	var own_marker_before_snap := own_marker.global_position if own_marker != null else Vector2.ZERO
	if target_marker != null and own_marker != null:
		room_root.global_position += target_marker.global_position - own_marker.global_position
		room_root.set_meta("debug_own_marker_before_snap", own_marker_before_snap)
		room_root.set_meta("debug_anchor_marker_before_snap", target_marker.global_position)
		if OS.is_debug_build():
			print("DungeonAssembler: room snap resolved room=%d scene=%s anchor_marker=%s own_marker_before=%s own_marker_after=%s final_origin=%s" % [room_id, scene.resource_path, str(target_marker.global_position), str(own_marker_before_snap), str(own_marker.global_position), str(room_root.global_position)])

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
	var corridor_origin_before_snap := corridor_root.global_position
	var entry_marker_before_snap := entry_marker.global_position if entry_marker != null else Vector2.ZERO
	var exit_marker_before_snap := exit_marker.global_position if exit_marker != null else Vector2.ZERO
	var marker_rotation_delta := 0.0
	if anchor_exit != null and entry_marker != null:
		marker_rotation_delta = wrapf(anchor_exit.global_rotation_degrees - entry_marker.global_rotation_degrees, -180.0, 180.0)
	if anchor_exit != null and entry_marker != null:
		corridor_root.global_position += anchor_exit.global_position - entry_marker.global_position
		if int(anchor_room.get("id", -1)) == 0:
			corridor_root.global_position += Vector2(0, float(dungeon.tile_size) * float(TUTORIAL_CORRIDOR_DOWN_OFFSET_TILES))
			if OS.is_debug_build():
				print("DungeonAssembler: tutorial corridor seam nudge applied room=%d offset_tiles=%d new_origin=%s" % [int(anchor_room.get("id", -1)), TUTORIAL_CORRIDOR_DOWN_OFFSET_TILES, str(corridor_root.global_position)])
		# Keep marker snap as absolute seam authority in prefab-native mode.
		# Overlap is resolved via cell ownership reconciliation instead of post-snap
		# translation that can desync connector seams by one tile.
		if OS.is_debug_build():
			print("DungeonAssembler: seam lock preserved; corridor post-snap nudge skipped for connector stability")

	var seam_cells: Dictionary = {}
	if entry_marker != null:
		seam_cells[dungeon.world_to_grid_coords(entry_marker.global_position)] = true
	if exit_marker != null:
		seam_cells[dungeon.world_to_grid_coords(exit_marker.global_position)] = true

	var corridor_floor_cells := _extract_world_floor_cells(corridor_root)
	var corridor_transformed_floor_count := corridor_floor_cells.size()
	var corridor_floor_set := _cells_to_set(corridor_floor_cells)
	var anchor_floor_set := _cells_to_set(anchor_room.get("floor_cells", []))
	var protected_seam_cells := _expand_seam_cells_with_transition_support(seam_cells, corridor_floor_set, anchor_floor_set)
	corridor_floor_cells = _remove_overlap_cells_except_seams(corridor_floor_cells, anchor_room.get("floor_cells", []), protected_seam_cells)
	var room_rect := _rect_from_cells(corridor_floor_cells)
	var center_cell := _center_cell_from_rect(room_rect)
	var corridor_cells := corridor_floor_cells.duplicate(true)
	var snapshot := room_prefab_adapter.inspect_scene(scene)

	var corridor_record := {
		"id": room_b,
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
		"seam_cells": protected_seam_cells.duplicate(true),
		"transformed_floor_cell_count": corridor_transformed_floor_count,
		"origin_before_snap": corridor_origin_before_snap,
		"origin_after_snap": corridor_root.global_position,
		"entry_marker_before_snap": entry_marker_before_snap,
		"exit_marker_before_snap": exit_marker_before_snap,
		"room_role": "corridor",
		"room_type": "corridor",
		"template": DungeonGraph.TEMPLATE_CORRIDOR,
		"prefab_scene_path": scene.resource_path,
		"prefab_rotation_degrees": int(corridor_root.rotation_degrees)
	}
	if OS.is_debug_build():
		print("DungeonAssembler: connector resolved room=%d marker=Salida -> corridor=Entrada anchor=%s entry=%s rot_delta=%.1f seam=%s" % [int(anchor_room.get("id", -1)), str(anchor_exit.global_position if anchor_exit else Vector2.ZERO), str(entry_marker.global_position if entry_marker else Vector2.ZERO), marker_rotation_delta, str(seam_cells.keys())])
		print("DungeonAssembler: corridor placement pre_snap_origin=%s post_snap_origin=%s entry_before=%s entry_after=%s exit_before=%s exit_after=%s transformed_floor=%d registered_floor=%d rect=%s scene=%s" % [str(corridor_origin_before_snap), str(corridor_root.global_position), str(entry_marker_before_snap), str(entry_marker.global_position if entry_marker else Vector2.ZERO), str(exit_marker_before_snap), str(exit_marker.global_position if exit_marker else Vector2.ZERO), corridor_transformed_floor_count, corridor_floor_cells.size(), str(room_rect), String(scene.resource_path)])

	_assembled_corridors[_edge_key(room_a, room_b)] = corridor_root
	return corridor_record


func _build_corridor_room_record(room_id: int, corridor_record: Dictionary) -> Dictionary:
	if corridor_record.is_empty():
		return {}

	var floor_cells: Array = corridor_record.get("floor_cells", [])
	var room_rect: Rect2i = corridor_record.get("rect", Rect2i())
	var local_floor_cells := RoomConnectorAdapter.local_floor_cells_from_world_cells(floor_cells, room_rect.position)
	return {
		"id": room_id,
		"rect": room_rect,
		"local_bounds": corridor_record.get("snapshot", {}).get("local_bounds", Rect2i(Vector2i.ZERO, room_rect.size)),
		"center_cell": corridor_record.get("center_cell", _center_cell_from_rect(room_rect)),
		"floor_cells": floor_cells.duplicate(true),
		"local_floor_cells": local_floor_cells,
		"connectors": corridor_record.get("snapshot", {}).get("connectors", []),
		"spawn_markers": corridor_record.get("snapshot", {}).get("spawn_markers", []),
		"corridor_connections": corridor_record.get("corridor_connections", []).duplicate(true),
		"connected_room_ids": corridor_record.get("connected_room_ids", []).duplicate(true),
		"template": String(corridor_record.get("template", DungeonGraph.TEMPLATE_CORRIDOR)),
		"room_role": "corridor",
		"room_type": "corridor",
		"visual_root": corridor_record.get("visual_root", null),
		"marker_refs": corridor_record.get("marker_refs", {}).duplicate(true),
		"prefab_scene_path": String(corridor_record.get("prefab_scene_path", "")),
		"prefab_rotation_degrees": int(corridor_record.get("prefab_rotation_degrees", 0)),
		"room_prefab_snapshot": corridor_record.get("snapshot", {}).duplicate(true),
		"spawn_profile": "corridor",
		"seam_cells": corridor_record.get("seam_cells", {}).duplicate(true),
		"topology_metadata": {
			"assembly_mode": "prefab_native_hardcoded",
			"is_main_path": true
		}
	}


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
	if OS.is_debug_build():
		var marker_log: Array = []
		for marker_name in ["Entrada", "Salida", "Spawn_Jugador", "Spawn_Tutorial", "SpawnEnemigos"]:
			var marker = marker_refs.get(marker_name, null)
			marker_log.append("%s=%s" % [marker_name, str(marker.global_position if marker else Vector2.ZERO)])
		print("DungeonAssembler: prefab floor extract room=%d template=%s scene=%s origin=%s local_floor=%d world_floor=%d bounds=%s markers=%s" % [room_id, String(template_name), scene.resource_path, str(room_root.global_position), local_floor_cells.size(), floor_cells.size(), str(room_rect), marker_log])

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

	if OS.is_debug_build():
		print("DungeonAssembler: assembled room %d template=%s origin=%s markers=%s scene=%s" % [room_id, String(template_name), room_root.global_position, marker_refs.keys(), scene.resource_path])

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
	if room_prefab_adapter != null:
		var extracted := room_prefab_adapter.extract_world_floor_cells_with_tilemap_transforms(
			room_root,
			Callable(dungeon, "world_to_grid_coords")
		)
		if OS.is_debug_build():
			print("DungeonAssembler: world floor extract room=%s scene=%s origin=%s count=%d sample=%s" % [room_root.name if room_root else "NULL", str(room_root.get_path() if room_root else NodePath()), str(room_root.global_position if room_root else Vector2.ZERO), extracted.size(), str(extracted.slice(0, mini(10, extracted.size())))])
		return extracted

	# Prefab-authored TileMap geometry is authoritative here. Use the
	# RoomPrefabAdapter extraction which prioritizes the `caminable` custom
	# data layer and falls back to used-cell detection only when necessary.
	var local_floor_cells := room_prefab_adapter.extract_local_floor_cells_from_scene_root(room_root, dungeon.tile_size)
	for raw_cell in local_floor_cells:
		var local_cell := Vector2i(raw_cell)
		var world_position := room_root.to_global(Vector2(local_cell) * dungeon.tile_size)
		floor_cells.append(dungeon.world_to_grid_coords(world_position))
	if OS.is_debug_build():
		print("DungeonAssembler: fallback world floor extract room=%s scene=%s local_floor=%d world_floor=%d sample=%s" % [room_root.name if room_root else "NULL", str(room_root.get_path() if room_root else NodePath()), local_floor_cells.size(), floor_cells.size(), str(floor_cells.slice(0, mini(10, floor_cells.size())))])

	return floor_cells


func _remove_overlap_cells_except_seams(source_cells: Array[Vector2i], other_cells: Array, seam_cells: Dictionary) -> Array[Vector2i]:
	var other_set := _cells_to_set(other_cells)
	if other_set.is_empty():
		return source_cells

	var result: Array[Vector2i] = []
	for raw_cell in source_cells:
		var cell := Vector2i(raw_cell)
		if other_set.has(cell) and not seam_cells.has(cell):
			continue
		result.append(cell)
	return result


func _reconcile_corridor_room_overlap(corridor_record: Dictionary, room_record: Dictionary, seam_marker_names: Array[String]) -> void:
	if corridor_record.is_empty() or room_record.is_empty():
		return

	var corridor_cells: Array[Vector2i] = []
	for raw_cell in corridor_record.get("corridor_cells", []):
		corridor_cells.append(Vector2i(raw_cell))

	var room_floor = room_record.get("floor_cells", [])
	var seam_cells: Dictionary = corridor_record.get("seam_cells", {}).duplicate(true)
	for marker_name in seam_marker_names:
		var marker := _get_marker_from_record(room_record, marker_name)
		if marker != null and dungeon != null:
			seam_cells[dungeon.world_to_grid_coords(marker.global_position)] = true

	var before := corridor_cells.size()
	var overlap_cells: Array[Vector2i] = []
	var room_floor_set := _cells_to_set(room_floor)
	for cell in corridor_cells:
		if room_floor_set.has(cell):
			overlap_cells.append(cell)
	var corridor_floor_set := _cells_to_set(corridor_cells)
	var protected_seam_cells := _expand_seam_cells_with_transition_support(seam_cells, corridor_floor_set, room_floor_set)
	var resolved := _remove_overlap_cells_except_seams(corridor_cells, room_floor, protected_seam_cells)
	corridor_record["corridor_cells"] = resolved
	corridor_record["floor_cells"] = resolved.duplicate(true)
	corridor_record["rect"] = _rect_from_cells(resolved)
	corridor_record["center_cell"] = _center_cell_from_rect(corridor_record["rect"])
	corridor_record["seam_cells"] = protected_seam_cells

	if OS.is_debug_build():
		print("DungeonAssembler: overlap reconcile room=%d corridor=%d->%d protected_seams=%s" % [int(room_record.get("id", -1)), before, resolved.size(), str(protected_seam_cells.keys())])
		if not overlap_cells.is_empty():
			print("DungeonAssembler: overlap detail room=%d overlap_cells=%d sample=%s" % [int(room_record.get("id", -1)), overlap_cells.size(), str(overlap_cells.slice(0, mini(10, overlap_cells.size())))])


func _expand_seam_cells_with_transition_support(seam_cells: Dictionary, corridor_floor_set: Dictionary, room_floor_set: Dictionary) -> Dictionary:
	var result := seam_cells.duplicate(true)
	for raw_cell in seam_cells.keys():
		var seam_cell := Vector2i(raw_cell)
		result[seam_cell] = true
		for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var neighbor = seam_cell + direction
			if corridor_floor_set.has(neighbor) or room_floor_set.has(neighbor):
				result[neighbor] = true
	return result


func _debug_trace_tutorial_connectivity(tutorial_room: Dictionary, corridor: Dictionary, room_1: Dictionary) -> void:
	var tutorial_origin := (tutorial_room.get("visual_root", null) as Node2D).global_position if tutorial_room.get("visual_root", null) else Vector2.ZERO
	var tutorial_exit_marker := _get_marker_from_record(tutorial_room, "Salida")
	var tutorial_exit_cell := dungeon.world_to_grid_coords(tutorial_exit_marker.global_position) if tutorial_exit_marker != null and dungeon != null else Vector2i(-1, -1)

	var corridor_origin_before = corridor.get("origin_before_snap", Vector2.ZERO)
	var corridor_origin_after = corridor.get("origin_after_snap", Vector2.ZERO)
	var corridor_entry_marker := corridor.get("entry_marker", null) as Node2D
	var corridor_exit_marker := corridor.get("exit_marker", null) as Node2D
	var corridor_entry_cell := dungeon.world_to_grid_coords(corridor_entry_marker.global_position) if corridor_entry_marker != null and dungeon != null else Vector2i(-1, -1)
	var corridor_exit_cell := dungeon.world_to_grid_coords(corridor_exit_marker.global_position) if corridor_exit_marker != null and dungeon != null else Vector2i(-1, -1)

	var room_1_root := room_1.get("visual_root", null) as Node2D
	var room_1_marker_before = room_1_root.get_meta("debug_own_marker_before_snap", Vector2.ZERO) if room_1_root != null else Vector2.ZERO
	var room_1_entry_marker := _get_marker_from_record(room_1, "Entrada")
	var room_1_entry_cell := dungeon.world_to_grid_coords(room_1_entry_marker.global_position) if room_1_entry_marker != null and dungeon != null else Vector2i(-1, -1)

	print("DungeonAssembler: connectivity trace tutorial room_origin=%s salida_global=%s seam_cell=%s" % [str(tutorial_origin), str(tutorial_exit_marker.global_position if tutorial_exit_marker else Vector2.ZERO), str([tutorial_exit_cell])])
	print("DungeonAssembler: connectivity trace corridor origin_before=%s origin_after=%s entrada_global=%s salida_global=%s transformed_floor=%d registered_floor=%d seam_cells=%s" % [
		str(corridor_origin_before),
		str(corridor_origin_after),
		str(corridor_entry_marker.global_position if corridor_entry_marker else Vector2.ZERO),
		str(corridor_exit_marker.global_position if corridor_exit_marker else Vector2.ZERO),
		int(corridor.get("transformed_floor_cell_count", 0)),
		int(corridor.get("floor_cells", []).size()),
		str((corridor.get("seam_cells", {}) as Dictionary).keys())
	])
	print("DungeonAssembler: connectivity trace sala_1 entrada_before_snap=%s final_origin=%s transformed_floor=%d registered_floor=%d bounds=%s seam_cells=%s" % [
		str(room_1_marker_before),
		str(room_1_root.global_position if room_1_root else Vector2.ZERO),
		int(room_1.get("room_prefab_snapshot", {}).get("local_floor_cells", []).size()),
		int(room_1.get("floor_cells", []).size()),
		str(room_1.get("rect", Rect2i())),
		str([tutorial_exit_cell, corridor_entry_cell, corridor_exit_cell, room_1_entry_cell])
	])


func _cells_to_set(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_cell in cells:
		result[Vector2i(raw_cell)] = true
	return result


func _count_overlap(source_cells: Array[Vector2i], set_b: Dictionary) -> int:
	var overlap := 0
	for cell in source_cells:
		if set_b.has(Vector2i(cell)):
			overlap += 1
	return overlap


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
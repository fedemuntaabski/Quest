extends RefCounted
class_name DungeonRoomFactory

var dungeon: DungeonGenerator = null
var room_system: RoomSystem = null
var room_prefab_adapter: RoomPrefabAdapter = null
var modular_room_assembler: ModularRoomAssembler = null

func setup(p_dungeon: DungeonGenerator, p_room_system: RoomSystem, p_room_prefab_adapter: RoomPrefabAdapter = null, p_modular_room_assembler: ModularRoomAssembler = null) -> void:
	dungeon = p_dungeon
	room_system = p_room_system
	room_prefab_adapter = p_room_prefab_adapter
	modular_room_assembler = p_modular_room_assembler


func create_room_nodes(room_info: Dictionary, rooms_root: Node2D, room_lights_root: Node2D, room_detectors_root: Node2D) -> Dictionary:
	var room_id := int(room_info.get("id", -1))
	var room_rect: Rect2i = room_info.get("rect", Rect2i())
	var center_cell: Vector2i = room_info.get("center_cell", Vector2i.ZERO)

	var prefab_room := _create_prefab_room(room_info, rooms_root, room_rect)
	var room_root: Node2D = prefab_room.get("visual_root", null)
	var used_prefab := room_root != null
	if room_root == null:
		push_warning("DungeonRoomFactory: prefab room instancing failed for room %d; falling back to legacy placeholder." % room_id)
		room_root = _create_legacy_room_root(room_info, rooms_root, room_rect)
		used_prefab = false

	room_root.set_meta("room_rect", room_rect)
	room_root.set_meta("room_local_bounds", Rect2i(Vector2i.ZERO, room_rect.size))
	room_root.set_meta("room_world_origin_cell", room_rect.position)
	room_root.set_meta("room_connectors", prefab_room.get("connectors", room_info.get("connectors", [])))
	room_root.set_meta("room_local_floor_cells", prefab_room.get("local_floor_cells", room_info.get("local_floor_cells", [])))
	room_root.set_meta("room_spawn_markers", prefab_room.get("spawn_markers", room_info.get("spawn_markers", [])))
	room_root.set_meta("room_marker_refs", prefab_room.get("marker_refs", {}))
	room_root.set_meta("room_template", room_info.get("template", ""))
	room_root.set_meta("room_prefab_ready", used_prefab)
	if used_prefab and modular_room_assembler != null:
		room_root.set_meta("room_role", prefab_room.get("room_role", "normal"))
		room_root.set_meta("room_scene_path", prefab_room.get("prefab_scene_path", ""))
		room_root.set_meta("room_prefab_snapshot", prefab_room.get("snapshot", {}))
		if OS.is_debug_build():
			var marker_refs: Dictionary = prefab_room.get("marker_refs", {})
			print("DungeonRoomFactory: room %d prefab origin=%s markers=%s" % [room_id, room_root.global_position, marker_refs.keys()])

	var room_light := create_room_light(room_rect, center_cell, room_id)
	if room_lights_root:
		room_lights_root.add_child(room_light)

	var room_area := create_room_area(room_id, room_rect)
	if room_detectors_root:
		room_detectors_root.add_child(room_area)

	return {
		"visual_root": room_root,
		"light": room_light,
		"area": room_area
	}


func _create_prefab_room(room_info: Dictionary, rooms_root: Node2D, room_rect: Rect2i) -> Dictionary:
	if modular_room_assembler == null:
		return {}

	return modular_room_assembler.build_room_instance(room_info, rooms_root)


func _create_legacy_room_root(room_info: Dictionary, rooms_root: Node2D, room_rect: Rect2i) -> Node2D:
	var room_id := int(room_info.get("id", -1))
	var room_root := Node2D.new()
	room_root.name = "RoomVisual_%d" % room_id
	# The legacy placeholder path remains as a fallback while prefab rooms are
	# introduced incrementally.
	if rooms_root:
		rooms_root.add_child(room_root)
	return room_root


func create_corridor_entity(edge_data: Dictionary, corridors_root: Node2D) -> Node2D:
	var room_a := int(edge_data.get("room_a", -1))
	var room_b := int(edge_data.get("room_b", -1))
	var corridor := Node2D.new()
	corridor.name = "Corridor_%d_%d" % [room_a, room_b]
	corridor.set_meta("room_a", room_a)
	corridor.set_meta("room_b", room_b)
	corridor.set_meta("corridor_cells", edge_data.get("corridor_cells", []))
	if corridors_root:
		corridors_root.add_child(corridor)
	return corridor

func create_room_light(room_rect: Rect2i, center_cell: Vector2i, room_id: int = -1) -> PointLight2D:
	var room_light := PointLight2D.new()
	room_light.name = "RoomLight_%d" % room_id
	room_light.texture = dungeon.light_texture
	room_light.position = dungeon.grid_to_world_coords(center_cell)
	room_light.energy = 0.0
	# Slightly warmer, larger room lights for a torchy ambiance
	room_light.texture_scale = maxf(2.2, float(max(room_rect.size.x, room_rect.size.y)) * 0.3)
	room_light.color = Color(1.0, 0.85, 0.6, 1.0)
	return room_light

func create_room_area(room_id: int, room_rect: Rect2i) -> Area2D:
	var area := Area2D.new()
	area.name = "RoomArea_%d" % room_id
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true

	# Expand room detection by 1 tile in all directions to cover corridor connections
	# This prevents players from getting stuck at room/corridor transition points
	var expansion := 1
	var expanded_size := Vector2(
		(room_rect.size.x + expansion * 2) * dungeon.tile_size,
		(room_rect.size.y + expansion * 2) * dungeon.tile_size
	)

	var shape := RectangleShape2D.new()
	shape.size = expanded_size

	var collision := CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	area.position = dungeon.grid_to_world_coords(
		Vector2i(
			room_rect.position.x + int(room_rect.size.x * 0.5),
			room_rect.position.y + int(room_rect.size.y * 0.5)
		)
	)

	if room_system:
		room_system.register_room_area(area, room_id)

	return area

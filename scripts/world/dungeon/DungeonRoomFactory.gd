extends RefCounted
class_name DungeonRoomFactory

var dungeon: DungeonGenerator = null
var room_system: RoomSystem = null

func setup(p_dungeon: DungeonGenerator, p_room_system: RoomSystem) -> void:
	dungeon = p_dungeon
	room_system = p_room_system


func create_room_nodes(room_info: Dictionary, rooms_root: Node2D,  room_detectors_root: Node2D) -> Dictionary:
	var room_id := int(room_info.get("id", -1))
	var room_rect: Rect2i = room_info.get("rect", Rect2i())


	var room_root := Node2D.new()
	room_root.name = "RoomVisual_%d" % room_id
	room_root.visible = false
	if rooms_root:
		rooms_root.add_child(room_root)


	var room_area := create_room_area(room_id, room_rect)
	if room_detectors_root:
		room_detectors_root.add_child(room_area)

	return {
		"visual_root": room_root,
		"area": room_area
	}


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
	var expansion := 0
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

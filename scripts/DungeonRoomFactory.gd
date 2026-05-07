extends RefCounted
class_name DungeonRoomFactory

var dungeon: DungeonGenerator = null
var room_system: RoomSystem = null

func setup(p_dungeon: DungeonGenerator, p_room_system: RoomSystem) -> void:
	dungeon = p_dungeon
	room_system = p_room_system

func create_room_light(room_rect: Rect2i, center_cell: Vector2i) -> PointLight2D:
	var room_light := PointLight2D.new()
	room_light.name = "RoomLight_%d" % dungeon.room_infos.size()
	room_light.texture = dungeon.light_texture
	room_light.position = dungeon.grid_to_world_coords(center_cell)
	room_light.energy = 0.0
	room_light.texture_scale = maxf(1.8, float(max(room_rect.size.x, room_rect.size.y)) * 0.25)
	room_light.color = Color(0.9, 0.95, 1.0, 1.0)
	return room_light

func create_room_area(room_id: int, room_rect: Rect2i) -> Area2D:
	var area := Area2D.new()
	area.name = "RoomArea_%d" % room_id
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true

	var shape := RectangleShape2D.new()
	shape.size = Vector2(room_rect.size) * dungeon.tile_size

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

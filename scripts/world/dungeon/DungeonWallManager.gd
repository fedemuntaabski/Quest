extends RefCounted
class_name DungeonWallManager

var dungeon: DungeonGenerator


func setup(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon


func generate_walls_from_floor() -> void:
	if dungeon == null:
		return

	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for floor_cell in dungeon.floor_cells.keys():
		var origin: Vector2i = floor_cell
		for direction in directions:
			var candidate := origin + direction
			if not dungeon.is_within_bounds(candidate):
				continue
			if dungeon.floor_cells.has(candidate):
				continue
			if dungeon.wall_cells.has(candidate):
				continue

			dungeon.wall_cells[candidate] = true
			_spawn_wall(candidate)


func set_wall_at_world(world_position: Vector2) -> void:
	if dungeon == null:
		return

	var cell := dungeon.world_to_grid_coords(world_position)

	if not dungeon.is_within_bounds(cell):
		return

	if dungeon.wall_cells.has(cell):
		return

	dungeon.wall_cells[cell] = true
	_spawn_wall(cell)


func clear_cell_at_world(world_position: Vector2) -> void:
	if dungeon == null:
		return

	var cell := dungeon.world_to_grid_coords(world_position)

	if not dungeon.is_within_bounds(cell):
		return

	if not dungeon.wall_cells.has(cell):
		return

	dungeon.wall_cells.erase(cell)

	if dungeon.wall_nodes.has(cell):
		var wall_node := dungeon.wall_nodes[cell] as Node
		if wall_node:
			wall_node.queue_free()
		dungeon.wall_nodes.erase(cell)


func _spawn_wall(cell: Vector2i) -> void:
	if dungeon == null:
		return

	var wall := StaticBody2D.new()
	wall.name = "Wall_%d_%d" % [cell.x, cell.y]
	wall.position = dungeon.grid_to_world_coords(cell)
	wall.collision_layer = 1
	wall.collision_mask = 1

	var wall_sprite := Sprite2D.new()
	wall_sprite.texture = dungeon.wall_texture
	wall_sprite.modulate = Color(0.2, 0.18, 0.16, 1)
	wall_sprite.scale = Vector2(dungeon.tile_size / 2.0, dungeon.tile_size / 2.0)
	wall.add_child(wall_sprite)

	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(dungeon.tile_size, dungeon.tile_size)
	collision_shape.shape = rectangle
	wall.add_child(collision_shape)

	var occluder := LightOccluder2D.new()
	var occ_polygon := OccluderPolygon2D.new()
	var hs := dungeon.tile_size / 2.0
	occ_polygon.polygon = PackedVector2Array([
		Vector2(-hs, -hs), Vector2(hs, -hs),
		Vector2(hs, hs), Vector2(-hs, hs)
	])
	occluder.occluder = occ_polygon
	wall.add_child(occluder)

	dungeon.walls_root.add_child(wall)
	dungeon.wall_nodes[cell] = wall
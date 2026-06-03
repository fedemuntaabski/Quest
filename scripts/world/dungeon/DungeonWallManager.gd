extends RefCounted
class_name DungeonWallManager

var dungeon: DungeonGenerator

var _wall_shape: RectangleShape2D
var _occluder_polygon: OccluderPolygon2D


func setup(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon

	if dungeon == null:
		return

	_wall_shape = RectangleShape2D.new()
	_wall_shape.size = Vector2(
		dungeon.tile_size,
		dungeon.tile_size
	)

	var hs := dungeon.tile_size * 0.5

	_occluder_polygon = OccluderPolygon2D.new()
	_occluder_polygon.polygon = PackedVector2Array([
		Vector2(-hs, -hs),
		Vector2(hs, -hs),
		Vector2(hs, hs),
		Vector2(-hs, hs)
	])


func generate_walls_from_floor() -> void:
	if dungeon == null:
		return

	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.UP,
		Vector2i.DOWN,

		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(-1, -1)
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

	set_wall(cell)


func set_wall(cell: Vector2i) -> void:
	if dungeon == null:
		return

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

	clear_wall(cell)


func clear_wall(cell: Vector2i) -> void:
	if dungeon == null:
		return

	if not dungeon.wall_cells.has(cell):
		return

	dungeon.wall_cells.erase(cell)

	if dungeon.wall_nodes.has(cell):

		var wall := dungeon.wall_nodes[cell] as Node

		if wall:
			wall.queue_free()

		dungeon.wall_nodes.erase(cell)


func clear_all_walls() -> void:
	if dungeon == null:
		return

	for wall in dungeon.wall_nodes.values():

		if wall:
			wall.queue_free()

	dungeon.wall_nodes.clear()
	dungeon.wall_cells.clear()


func _spawn_wall(cell: Vector2i) -> void:
	if dungeon == null:
		return

	if dungeon.wall_nodes.has(cell):
		return

	var wall := StaticBody2D.new()

	wall.name = "Wall_%d_%d" % [cell.x, cell.y]
	wall.position = dungeon.grid_to_world_coords(cell)

	wall.collision_layer = 1
	wall.collision_mask = 1

	# ─────────────────────────────
	# Sprite
	# ─────────────────────────────

	var sprite := Sprite2D.new()
	sprite.texture = dungeon.wall_texture

	sprite.modulate = Color(
		0.2,
		0.18,
		0.16,
		1.0
	)

	sprite.scale = Vector2.ONE * (
		dungeon.tile_size / 2.0
	)

	wall.add_child(sprite)

	# ─────────────────────────────
	# Collision
	# ─────────────────────────────

	var collision := CollisionShape2D.new()
	collision.shape = _wall_shape

	wall.add_child(collision)

	# ─────────────────────────────
	# Light Occlusion
	# ─────────────────────────────

	var occluder := LightOccluder2D.new()
	occluder.occluder = _occluder_polygon

	wall.add_child(occluder)

	# ─────────────────────────────
	# Register
	# ─────────────────────────────

	dungeon.walls_root.add_child(wall)
	dungeon.wall_nodes[cell] = wall
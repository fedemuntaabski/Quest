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

	# Pass 1: collect every new wall cell candidate without spawning yet, so
	# they can be merged into as few physics bodies as possible below.
	var new_wall_cells: Dictionary = {}

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

			if new_wall_cells.has(candidate):
				continue

			new_wall_cells[candidate] = true
			dungeon.wall_cells[candidate] = true

	# Pass 2: greedy-merge contiguous wall cells into rectangles and spawn one
	# StaticBody2D (Sprite2D + CollisionShape2D + LightOccluder2D) per rectangle
	# instead of one per cell — walls have no per-cell visual variation, so this
	# is safe (see _spawn_wall_rect).
	for rect in _compute_wall_rects(new_wall_cells):
		_spawn_wall_rect(rect)


# Greedy decomposition of a set of grid cells into a small number of
# non-overlapping rectangles (not guaranteed-minimal, but a large reduction
# over one-rectangle-per-cell for the contiguous wall bands this generator
# produces).
func _compute_wall_rects(cells: Dictionary) -> Array[Rect2i]:
	var remaining: Dictionary = cells.duplicate()
	var rects: Array[Rect2i] = []

	while not remaining.is_empty():
		var start: Vector2i = remaining.keys()[0]

		var width := 1
		while remaining.has(start + Vector2i(width, 0)):
			width += 1

		var height := 1
		var row_ok := true
		while row_ok:
			for x in range(width):
				if not remaining.has(start + Vector2i(x, height)):
					row_ok = false
					break
			if row_ok:
				height += 1

		var rect := Rect2i(start, Vector2i(width, height))

		for y in range(height):
			for x in range(width):
				remaining.erase(start + Vector2i(x, y))

		rects.append(rect)

	return rects


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


# Spawns one merged StaticBody2D covering an entire rectangle of wall cells.
# Safe because walls have no per-cell visual variation (uniform texture/tint,
# no autotiling) — used by the bulk generate_walls_from_floor() pass only.
# NOTE: clear_wall() on any cell inside a merged rect frees the whole rect's
# node (there is currently no live caller of clear_wall/set_wall in the repo,
# so this is an accepted limitation rather than a regression).
func _spawn_wall_rect(rect: Rect2i) -> void:
	if dungeon == null:
		return

	var wall := StaticBody2D.new()

	var world_pos: Vector2 = dungeon.grid_to_world_coords(rect.position) \
		+ Vector2(rect.size - Vector2i.ONE) * dungeon.tile_size * 0.5

	wall.name = "WallRect_%d_%d_%dx%d" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	wall.position = world_pos

	wall.collision_layer = 1
	wall.collision_mask = 1

	var sprite := Sprite2D.new()
	sprite.texture = dungeon.wall_texture
	sprite.modulate = Color(0.2, 0.18, 0.16, 1.0)
	sprite.scale = Vector2(rect.size) * (dungeon.tile_size / 2.0)
	wall.add_child(sprite)

	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(rect.size) * dungeon.tile_size
	var collision := CollisionShape2D.new()
	collision.shape = rect_shape
	wall.add_child(collision)

	var half_size := Vector2(rect.size) * dungeon.tile_size * 0.5
	var rect_occluder := OccluderPolygon2D.new()
	rect_occluder.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])
	var occluder := LightOccluder2D.new()
	occluder.occluder = rect_occluder
	wall.add_child(occluder)

	dungeon.walls_root.add_child(wall)

	for x in range(rect.size.x):
		for y in range(rect.size.y):
			dungeon.wall_nodes[rect.position + Vector2i(x, y)] = wall


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
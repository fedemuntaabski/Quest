extends Node2D

class_name DungeonGenerator

signal room_changed(room_id: int)
signal room_cleared(room_id: int)

const FLOOR_TEXTURE_PATH := "res://assets/texture/enviorment/ground_texture1.png"
const WALL_TEXTURE_PATH := "res://assets/ui/white_2x2.svg"
const LIGHT_TEXTURE_PATH := "res://assets/ui/vision_scope.svg"
const ENEMY_SCENE_PATH := "res://scenes/Enemy.tscn"

@export var grid_width: int = 52
@export var grid_height: int = 36
@export var tile_size: float = 64.0
@export var room_count: int = 7
@export var room_min_size: Vector2i = Vector2i(6, 5)
@export var room_max_size: Vector2i = Vector2i(16, 12)
@export var room_padding: int = 1
@export var room_light_energy: float = 1.2
@export var room_light_transition_seconds: float = 0.45

var floor_texture: Texture2D = preload(FLOOR_TEXTURE_PATH)
var wall_texture: Texture2D = preload(WALL_TEXTURE_PATH)
var light_texture: Texture2D = preload(LIGHT_TEXTURE_PATH)

var floors_root: Node2D
var corridors_root: Node2D
var rooms_root: Node2D
var walls_root: Node2D
var room_detectors_root: Node2D
var room_lights_root: Node2D
var enemies_root: Node2D
var fog_of_war: TileMapLayer
var visited_fog: TileMapLayer

var grid_origin: Vector2 = Vector2.ZERO
var floor_cells: Dictionary = {}
var wall_cells: Dictionary = {}
var wall_nodes: Dictionary = {}
var room_infos: Array[Dictionary] = []
var active_room_id: int = -1

## Tracks how many enemies are still alive per room_id.
var _room_enemy_counts: Dictionary = {}

var _enemy_scene: PackedScene = null
var _spawned_player: CharacterBody2D = null

func _ready() -> void:
	_ensure_runtime_nodes()

func generate_dungeon(player: CharacterBody2D = null) -> void:
	randomize()
	_ensure_runtime_nodes()
	_clear_generated_content()

	floor_cells.clear()
	wall_cells.clear()
	wall_nodes.clear()
	room_infos.clear()
	_room_enemy_counts.clear()
	active_room_id = -1

	grid_origin = Vector2(
		-(float(grid_width) * 0.5 * tile_size),
		-(float(grid_height) * 0.5 * tile_size)
	)

	if not _generate_rooms():
		push_error("DungeonGenerator: Failed to generate exactly %d rooms." % room_count)
		return

	_connect_rooms_with_corridors()
	_generate_walls_from_floor()
	_build_fog_layers()

	if player:
		_spawned_player = player
		place_player_in_start_room(player)

	# Spawn enemies after layout is fully built
	_spawn_enemies()

	_set_active_room(int(room_infos[0]["id"]), false)

func place_player_in_start_room(player: CharacterBody2D) -> void:
	if room_infos.is_empty() or player == null:
		return

	var start_room := room_infos[0]
	var center_cell: Vector2i = start_room["center_cell"]
	player.position = grid_to_world_coords(center_cell)

func is_cell_walkable(world_position: Vector2) -> bool:
	var cell := world_to_grid_coords(world_position)
	if not is_within_bounds(cell):
		return false
	if wall_cells.has(cell):
		return false
	return floor_cells.has(cell)

func set_wall_at_world(world_position: Vector2) -> void:
	var cell := world_to_grid_coords(world_position)
	if wall_cells.has(cell):
		return
	wall_cells[cell] = true
	_spawn_wall(cell)

func clear_cell_at_world(world_position: Vector2) -> void:
	var cell := world_to_grid_coords(world_position)
	if not wall_cells.has(cell):
		return
	wall_cells.erase(cell)
	if wall_nodes.has(cell):
		var wall_node := wall_nodes[cell] as Node
		if wall_node:
			wall_node.queue_free()
		wall_nodes.erase(cell)

func world_to_grid_coords(world_pos: Vector2) -> Vector2i:
	var local_pos := world_pos - grid_origin
	return Vector2i(
		floori(local_pos.x / tile_size),
		floori(local_pos.y / tile_size)
	)

func grid_to_world_coords(grid_pos: Vector2i) -> Vector2:
	return grid_origin + (Vector2(grid_pos) + Vector2(0.5, 0.5)) * tile_size

func get_adjacent_walkable_cells(world_position: Vector2) -> Array:
	var walkable_cells: Array = []
	var origin_grid := world_to_grid_coords(world_position)
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for direction in directions:
		var next_grid: Vector2i = origin_grid + direction
		if is_within_bounds(next_grid) and floor_cells.has(next_grid) and not wall_cells.has(next_grid):
			walkable_cells.append(grid_to_world_coords(next_grid))

	return walkable_cells

func is_within_bounds(grid_pos: Vector2i) -> bool:
	return (
		grid_pos.x >= 0
		and grid_pos.x < grid_width
		and grid_pos.y >= 0
		and grid_pos.y < grid_height
	)

func _ensure_runtime_nodes() -> void:
	floors_root = _ensure_node2d("Floors")
	corridors_root = _ensure_node2d("Corridors")
	rooms_root = _ensure_node2d("Rooms")
	walls_root = _ensure_node2d("Walls")
	room_detectors_root = _ensure_node2d("RoomDetectors")
	room_lights_root = _ensure_node2d("RoomLights")
	enemies_root = _ensure_node2d("Enemies")
	fog_of_war = _ensure_tile_map_layer("FogOfWar")
	visited_fog = _ensure_tile_map_layer("VisitedFog")

func _ensure_node2d(node_name: String) -> Node2D:
	var existing := get_node_or_null(node_name) as Node2D
	if existing:
		return existing

	var created := Node2D.new()
	created.name = node_name
	add_child(created)
	return created

func _ensure_tile_map_layer(node_name: String) -> TileMapLayer:
	var existing := get_node_or_null(node_name) as TileMapLayer
	if existing:
		return existing

	var created := TileMapLayer.new()
	created.name = node_name
	add_child(created)
	return created

func _clear_generated_content() -> void:
	for parent in [floors_root, corridors_root, rooms_root, walls_root, room_detectors_root, room_lights_root, enemies_root]:
		for child in parent.get_children():
			child.queue_free()

	fog_of_war.clear()
	visited_fog.clear()

func _generate_rooms() -> bool:
	const LAYOUT_RETRIES := 32

	for _retry in range(LAYOUT_RETRIES):
		_clear_generated_content()
		floor_cells.clear()
		wall_cells.clear()
		wall_nodes.clear()
		room_infos.clear()

		var attempts := room_count * 90
		while room_infos.size() < room_count and attempts > 0:
			attempts -= 1

			var room_size := _roll_room_size()

			var max_x := grid_width - room_size.x - room_padding - 1
			var max_y := grid_height - room_size.y - room_padding - 1
			if max_x <= room_padding or max_y <= room_padding:
				continue

			var room_pos := Vector2i(
				randi_range(room_padding, max_x),
				randi_range(room_padding, max_y)
			)
			var room_rect := Rect2i(room_pos, room_size)

			if _room_overlaps_existing(room_rect):
				continue

			_register_room(room_rect)

		if room_infos.size() == room_count:
			return true

	return false

func _roll_room_size() -> Vector2i:
	var width := randi_range(room_min_size.x, room_max_size.x)
	var height := randi_range(room_min_size.y, room_max_size.y)

	var short_width_max := mini(room_max_size.x, room_min_size.x + 2)
	var short_height_max := mini(room_max_size.y, room_min_size.y + 2)
	var long_width_min := maxi(room_min_size.x, room_max_size.x - 4)
	var long_height_min := maxi(room_min_size.y, room_max_size.y - 4)

	var shape_roll := randf()
	if shape_roll < 0.34:
		# Wide chamber / horizontal corridor feel.
		width = randi_range(long_width_min, room_max_size.x)
		height = randi_range(room_min_size.y, short_height_max)
	elif shape_roll < 0.68:
		# Tall chamber / vertical corridor feel.
		width = randi_range(room_min_size.x, short_width_max)
		height = randi_range(long_height_min, room_max_size.y)

	return Vector2i(width, height)

func _room_overlaps_existing(candidate: Rect2i) -> bool:
	var expanded := candidate.grow(room_padding)
	for room_info in room_infos:
		var other: Rect2i = room_info["rect"]
		if expanded.intersects(other):
			return true
	return false

func _register_room(room_rect: Rect2i) -> void:
	var room_id := room_infos.size()
	var room_root := Node2D.new()
	room_root.name = "RoomVisual_%d" % room_id
	room_root.visible = false
	rooms_root.add_child(room_root)

	var room_cells: Array[Vector2i] = []
	for x in range(room_rect.position.x, room_rect.end.x):
		for y in range(room_rect.position.y, room_rect.end.y):
			var cell := Vector2i(x, y)
			floor_cells[cell] = true
			room_cells.append(cell)
			_spawn_floor_tile(cell, room_root)

	var center_cell := Vector2i(
		room_rect.position.x + int(room_rect.size.x * 0.5),
		room_rect.position.y + int(room_rect.size.y * 0.5)
	)

	var room_light := _create_room_light(room_rect, center_cell)
	room_lights_root.add_child(room_light)

	var room_area := _create_room_area(room_id, room_rect)
	room_detectors_root.add_child(room_area)

	room_infos.append({
		"id": room_id,
		"rect": room_rect,
		"center_cell": center_cell,
		"floor_cells": room_cells,
		"visited": false,
		"visual_root": room_root,
		"light": room_light,
		"area": room_area
	})

func _create_room_light(room_rect: Rect2i, center_cell: Vector2i) -> PointLight2D:
	var room_light := PointLight2D.new()
	room_light.name = "RoomLight_%d" % room_infos.size()
	room_light.texture = light_texture
	room_light.position = grid_to_world_coords(center_cell)
	room_light.energy = 0.0
	room_light.texture_scale = maxf(1.1, float(max(room_rect.size.x, room_rect.size.y)) * 0.18)
	room_light.color = Color(1.0, 0.92, 0.78, 1.0)
	return room_light

func _create_room_area(room_id: int, room_rect: Rect2i) -> Area2D:
	var area := Area2D.new()
	area.name = "RoomArea_%d" % room_id
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true

	var shape := RectangleShape2D.new()
	shape.size = Vector2(room_rect.size) * tile_size

	var collision := CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	area.position = grid_to_world_coords(
		Vector2i(
			room_rect.position.x + int(room_rect.size.x * 0.5),
			room_rect.position.y + int(room_rect.size.y * 0.5)
		)
	)
	area.body_entered.connect(_on_room_body_entered.bind(room_id))

	return area

func _spawn_floor_tile(cell: Vector2i, parent: Node2D) -> void:
	var floor_sprite := Sprite2D.new()
	floor_sprite.name = "Floor_%d_%d" % [cell.x, cell.y]
	floor_sprite.texture = floor_texture
	floor_sprite.centered = true
	floor_sprite.position = grid_to_world_coords(cell)
	floor_sprite.region_enabled = true
	floor_sprite.region_rect = Rect2(Vector2(cell) * tile_size, Vector2(tile_size, tile_size))
	floor_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_sprite.z_index = -2
	parent.add_child(floor_sprite)

func _connect_rooms_with_corridors() -> void:
	if room_infos.size() <= 1:
		return

	var sorted_rooms := room_infos.duplicate()
	sorted_rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var center_a: Vector2i = a["center_cell"]
		var center_b: Vector2i = b["center_cell"]
		if center_a.x == center_b.x:
			return center_a.y < center_b.y
		return center_a.x < center_b.x
	)

	for index in range(sorted_rooms.size() - 1):
		var from_cell: Vector2i = sorted_rooms[index]["center_cell"]
		var to_cell: Vector2i = sorted_rooms[index + 1]["center_cell"]
		_carve_corridor(from_cell, to_cell)

func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var current := from_cell
	_add_corridor_cell(current)

	if randf() < 0.5:
		while current.x != to_cell.x:
			current.x += signi(to_cell.x - current.x)
			_add_corridor_cell(current)
		while current.y != to_cell.y:
			current.y += signi(to_cell.y - current.y)
			_add_corridor_cell(current)
	else:
		while current.y != to_cell.y:
			current.y += signi(to_cell.y - current.y)
			_add_corridor_cell(current)
		while current.x != to_cell.x:
			current.x += signi(to_cell.x - current.x)
			_add_corridor_cell(current)

func _add_corridor_cell(cell: Vector2i) -> void:
	if not is_within_bounds(cell):
		return
	if floor_cells.has(cell):
		return

	floor_cells[cell] = true
	_spawn_floor_tile(cell, corridors_root)

func _generate_walls_from_floor() -> void:
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for floor_cell in floor_cells.keys():
		var origin: Vector2i = floor_cell
		for direction in directions:
			var candidate := origin + direction
			if not is_within_bounds(candidate):
				continue
			if floor_cells.has(candidate):
				continue
			if wall_cells.has(candidate):
				continue

			wall_cells[candidate] = true
			_spawn_wall(candidate)

func _spawn_wall(cell: Vector2i) -> void:
	var wall := StaticBody2D.new()
	wall.name = "Wall_%d_%d" % [cell.x, cell.y]
	wall.position = grid_to_world_coords(cell)
	wall.collision_layer = 1
	wall.collision_mask = 1

	var wall_sprite := Sprite2D.new()
	wall_sprite.texture = wall_texture
	wall_sprite.modulate = Color(0.2, 0.18, 0.16, 1)
	wall_sprite.scale = Vector2(tile_size / 2.0, tile_size / 2.0)
	wall.add_child(wall_sprite)

	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(tile_size, tile_size)
	collision_shape.shape = rectangle
	wall.add_child(collision_shape)

	walls_root.add_child(wall)
	wall_nodes[cell] = wall

func _build_fog_layers() -> void:
	_configure_fog_layer(fog_of_war, Color(0, 0, 0, 0.9))
	_configure_fog_layer(visited_fog, Color(0, 0, 0, 0.45))

	fog_of_war.clear()
	visited_fog.clear()
	fog_of_war.position = grid_origin
	visited_fog.position = grid_origin

	for floor_cell in floor_cells.keys():
		var cell: Vector2i = floor_cell
		fog_of_war.set_cell(cell, 0, Vector2i.ZERO, 0)

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

func _on_room_body_entered(body: Node2D, room_id: int) -> void:
	if body == null:
		return
	if body.name != "Player" and not body.is_in_group("player"):
		return
	_set_active_room(room_id, true)

func _set_active_room(room_id: int, animate: bool) -> void:
	if room_id < 0 or room_id >= room_infos.size():
		return

	active_room_id = room_id

	for index in range(room_infos.size()):
		var room_info := room_infos[index]
		var info_room_id: int = room_info["id"]
		var is_active := info_room_id == active_room_id
		var visual_root: Node2D = room_info["visual_root"]
		visual_root.visible = is_active

		if is_active:
			room_info["visited"] = true
			room_infos[index] = room_info

	_update_fog_for_room_state()
	_tween_room_lights(animate)
	emit_signal("room_changed", active_room_id)

func _update_fog_for_room_state() -> void:
	for room_info in room_infos:
		var room_id: int = room_info["id"]
		var room_cells: Array = room_info["floor_cells"]
		var is_visited: bool = room_info["visited"]
		var is_active := room_id == active_room_id

		for room_cell in room_cells:
			if is_visited:
				fog_of_war.erase_cell(room_cell)
			else:
				fog_of_war.set_cell(room_cell, 0, Vector2i.ZERO, 0)

			if is_visited and not is_active:
				visited_fog.set_cell(room_cell, 0, Vector2i.ZERO, 0)
			else:
				visited_fog.erase_cell(room_cell)

func _tween_room_lights(animate: bool) -> void:
	var tween_duration := room_light_transition_seconds if animate else 0.0
	var tween := create_tween()
	tween.set_parallel(true)

	for room_info in room_infos:
		var room_id: int = room_info["id"]
		var room_light: PointLight2D = room_info["light"]
		var target_energy := room_light_energy if room_id == active_room_id else 0.0

		if tween_duration <= 0.0:
			room_light.energy = target_energy
		else:
			tween.tween_property(room_light, "energy", target_energy, tween_duration)

# ─────────────────────────────────────────────────────────────────────────────
# Enemy spawning
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_enemies() -> void:
	if _enemy_scene == null:
		_enemy_scene = load(ENEMY_SCENE_PATH) as PackedScene
	if _enemy_scene == null:
		push_error("DungeonGenerator: Could not load Enemy scene at '%s'" % ENEMY_SCENE_PATH)
		return

	# Cache player torch reference once
	var player_torch: PointLight2D = null
	if _spawned_player:
		player_torch = _spawned_player.get_node_or_null("PointLight2D") as PointLight2D

	for room_info in room_infos:
		var room_id: int = room_info["id"]
		var spawn_cell := _get_random_floor_cell_in_room(room_info, room_id == 0)
		if spawn_cell == Vector2i(-1, -1):
			push_warning("DungeonGenerator: No valid spawn cell in room %d, skipping enemy." % room_id)
			continue

		var enemy := _enemy_scene.instantiate() as EnemyAI
		if enemy == null:
			continue

		enemy.name = "Enemy_%d" % room_id
		enemy.position = grid_to_world_coords(spawn_cell)

		# Wire up player reference after the node enters the tree
		var captured_player := _spawned_player
		var captured_torch := player_torch
		enemy.ready.connect(func() -> void:
			enemy.player = captured_player
			enemy.player_torch = captured_torch
		, CONNECT_ONE_SHOT)

		# Track alive count and connect death signal
		_room_enemy_counts[room_id] = _room_enemy_counts.get(room_id, 0) + 1
		var captured_room_id := room_id
		enemy.enemy_defeated.connect(func(e: EnemyAI) -> void:
			_on_enemy_defeated(e, captured_room_id)
		, CONNECT_ONE_SHOT)

		enemies_root.add_child(enemy)
		print("DungeonGenerator: Spawned enemy in room %d at cell %v" % [room_id, spawn_cell])

func _get_random_floor_cell_in_room(room_info: Dictionary, avoid_center: bool) -> Vector2i:
	var room_cells: Array = room_info["floor_cells"]
	var center_cell: Vector2i = room_info["center_cell"]

	# Build candidate list: walkable, not a wall, not adjacent to a wall, and not center if needed
	var candidates: Array[Vector2i] = []
	var avoid_radius: int = 1 if avoid_center else 0

	for raw_cell in room_cells:
		var cell: Vector2i = raw_cell
		if wall_cells.has(cell):
			continue
		# Skip cells too close to center when avoiding player spawn
		if avoid_radius > 0:
			var dx: int = absi(cell.x - center_cell.x)
			var dy: int = absi(cell.y - center_cell.y)
			if dx <= avoid_radius and dy <= avoid_radius:
				continue
		# Skip cells adjacent to a wall
		var near_wall := false
		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if wall_cells.has(cell + dir):
				near_wall = true
				break
		if near_wall:
			continue
		candidates.append(cell)

	if candidates.is_empty():
		# Fallback: any non-wall floor cell in the room
		for raw_cell in room_cells:
			var cell: Vector2i = raw_cell
			if not wall_cells.has(cell):
				candidates.append(cell)

	if candidates.is_empty():
		return Vector2i(-1, -1)

	return candidates[randi() % candidates.size()]

# ─────────────────────────────────────────────────────────────────────────────
# Called when an enemy's enemy_defeated signal fires.
# Decrements the room's alive counter; emits room_cleared when it hits zero.
func _on_enemy_defeated(_enemy: EnemyAI, room_id: int) -> void:
	if not _room_enemy_counts.has(room_id):
		return

	_room_enemy_counts[room_id] = _room_enemy_counts[room_id] - 1
	var remaining: int = _room_enemy_counts[room_id]
	print("DungeonGenerator: Room %d has %d enemies remaining." % [room_id, remaining])

	if remaining <= 0:
		_room_enemy_counts.erase(room_id)
		print("DungeonGenerator: Room %d CLEARED — emitting room_cleared." % room_id)
		emit_signal("room_cleared", room_id)

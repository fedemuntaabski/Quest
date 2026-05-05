extends Node2D
class_name DungeonGenerator

@export var floor_tileset: TileSet = preload("res://assets/texture/enviorment/dungeon_tileset.tres")

signal room_changed(room_id: int)
signal room_cleared(room_id: int)

const WALL_TEXTURE_PATH := "res://assets/ui/white_2x2.svg"
const LIGHT_TEXTURE_PATH := "res://assets/ui/vision_scope.svg"

@export var grid_width: int = 90
@export var grid_height: int = 70
@export var tile_size: float = 16.0
@export var room_count: int = 8
@export var room_min_size: Vector2i = Vector2i(10, 8)
@export var room_max_size: Vector2i = Vector2i(20, 14)
@export var room_padding: int = 4

@export var room_light_energy: float = 2.0
@export var room_light_transition_seconds: float = 0.45

var wall_texture: Texture2D = preload(WALL_TEXTURE_PATH)
var light_texture: Texture2D = preload(LIGHT_TEXTURE_PATH)

var grid_origin: Vector2 = Vector2.ZERO
var floor_cells: Dictionary = {}
var wall_cells: Dictionary = {}
var wall_nodes: Dictionary = {}
var room_infos: Array[Dictionary] = []
var active_room_id: int = -1

var _spawned_player: CharacterBody2D = null

var corridors_root: Node2D
var rooms_root: Node2D
var walls_root: Node2D
var room_detectors_root: Node2D
var room_lights_root: Node2D
var enemies_root: Node2D


var tile_renderer: DungeonTileRenderer = null

var is_ready: bool = false


func _ready() -> void:
	_ensure_runtime_nodes()

func _ensure_runtime_nodes() -> void:
	_ensure_managers()
	_ensure_scene_roots()

func _ensure_managers() -> void:
	return

func _ensure_scene_roots() -> void:
	corridors_root = _ensure_node("Corridors")
	rooms_root = _ensure_node("Rooms")
	walls_root = _ensure_node("Walls")
	room_detectors_root = _ensure_node("RoomDetectors")
	room_lights_root = _ensure_node("RoomLights")
	enemies_root = _ensure_node("Enemies")

func _ensure_node(node_name: String) -> Node2D:
	var existing := get_node_or_null(node_name) as Node2D
	if existing:
		return existing

	var node := Node2D.new()
	node.name = node_name
	add_child(node)
	return node

func _on_room_cleared(room_id: int) -> void:
	emit_signal("room_cleared", room_id)	

func generate_dungeon(player: CharacterBody2D = null) -> void:
	randomize()
	_ensure_runtime_nodes()
	_clear_generated_content()

	floor_cells.clear()
	wall_cells.clear()
	wall_nodes.clear()
	room_infos.clear()

	active_room_id = -1

	grid_origin = Vector2(
		-(float(grid_width) * 0.5 * tile_size),
		-(float(grid_height) * 0.5 * tile_size)
	)

	is_ready = true # 👈 CLAVE

	if not _generate_rooms():
		push_error("DungeonGenerator: Failed to generate exactly %d rooms." % room_count)
		return

	_connect_rooms_with_corridors()
	_generate_walls_from_floor()

	var presentation := get_node_or_null("PresentationManager") as DungeonPresentationManager

	if presentation == null:
		presentation = DungeonPresentationManager.new()
		presentation.name = "PresentationManager"
		add_child(presentation)


	presentation.setup(self, self)

	presentation.build(self, floor_tileset, wall_texture)
	if player:
		_spawned_player = player
		place_player_in_start_room(player)
		
	else:
		push_warning("DungeonGenerator: No player provided for placement. Call place_player_in_start_room() manually after generation.")

	if not room_infos.is_empty():
		_set_active_room(int(room_infos[0]["id"]), false)

	

func place_player_in_start_room(player: CharacterBody2D) -> void:
	if room_infos.is_empty() or player == null:
		return

	var start_room := room_infos[0]
	var center_cell: Vector2i = start_room["center_cell"]
	player.position = grid_to_world_coords(center_cell)
	if player.has_method("sync_to_grid"):
		player.sync_to_grid()

func is_cell_walkable(world_position: Vector2) -> bool:
	var cell := world_to_grid_coords(world_position)
	if not is_within_bounds(cell):
		return false
	if wall_cells.has(cell):
		return false
	return floor_cells.has(cell)

func set_wall_at_world(world_position: Vector2) -> void:
	var cell := world_to_grid_coords(world_position)

	if not is_within_bounds(cell):
		return

	if wall_cells.has(cell):
		return

	wall_cells[cell] = true
	_spawn_wall(cell)

func clear_cell_at_world(world_position: Vector2) -> void:
	var cell := world_to_grid_coords(world_position)

	if not is_within_bounds(cell):
		return

	if not wall_cells.has(cell):
		return

	wall_cells.erase(cell)

	if wall_nodes.has(cell):
		var wall_node := wall_nodes[cell] as Node
		if wall_node:
			wall_node.queue_free()
		wall_nodes.erase(cell)

func world_to_grid_coords(world_pos: Vector2) -> Vector2i:
	if not is_ready:
		return Vector2i.ZERO

	var local_pos := world_pos - grid_origin
	return Vector2i(
		floori(local_pos.x / tile_size),
		floori(local_pos.y / tile_size)
	)

func grid_to_world_coords(grid_pos: Vector2i) -> Vector2:
	return grid_origin + (Vector2(grid_pos) + Vector2(0.5, 0.5)) * tile_size

func get_adjacent_walkable_cells(world_position: Vector2) -> Array:
	var result: Array = []
	var origin := world_to_grid_coords(world_position)

	for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var next: Vector2i = origin + dir

		if not is_within_bounds(next):
			continue

		if floor_cells.has(next) and not wall_cells.has(next):
			result.append(grid_to_world_coords(next))

	return result

func is_within_bounds(grid_pos: Vector2i) -> bool:
	return (
		grid_pos.x >= 0
		and grid_pos.x < grid_width
		and grid_pos.y >= 0
		and grid_pos.y < grid_height
	)

func _ensure_tile_map_layer(node_name: String) -> TileMapLayer:
	var existing := get_node_or_null(node_name) as TileMapLayer
	if existing:
		return existing

	var created := TileMapLayer.new()
	created.name = node_name
	add_child(created)
	return created

func _clear_generated_content() -> void:
	for parent in [corridors_root, rooms_root, walls_root, room_detectors_root, room_lights_root, enemies_root]:
		for child in parent.get_children():
			child.queue_free()


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
	room_light.texture_scale = maxf(1.8, float(max(room_rect.size.x, room_rect.size.y)) * 0.25)
	room_light.color = Color(0.9, 0.95, 1.0, 1.0) # slightly cooler light
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
	
	var occluder = LightOccluder2D.new()
	var occ_polygon = OccluderPolygon2D.new()
	var hs = tile_size / 2.0
	occ_polygon.polygon = PackedVector2Array([
		Vector2(-hs, -hs), Vector2(hs, -hs),
		Vector2(hs, hs), Vector2(-hs, hs)
	])
	occluder.occluder = occ_polygon
	wall.add_child(occluder)

	walls_root.add_child(wall)
	wall_nodes[cell] = wall

func _on_room_body_entered(body: Node2D, room_id: int) -> void:
	if body == null:
		return
	if body.name != "Player" and not body.is_in_group("player"):
		return
	_set_active_room(room_id, true)

func _update_camera_for_room(room_id: int, animate: bool) -> void:
	if _spawned_player == null:
		return

	var camera := _spawned_player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	var room_info = room_infos[room_id]
	var room_rect: Rect2i = room_info["rect"]

	# Centro real de la sala
	var center_cell: Vector2i = room_info["center_cell"]
	var target_pos: Vector2 = grid_to_world_coords(center_cell)

	# 📦 tamaño real en mundo
	var room_size_px = Vector2(room_rect.size) * tile_size

	# 📷 viewport visible (aprox)
	var viewport_size = get_viewport().get_visible_rect().size

	# 🔍 cálculo de zoom automático para encajar sala completa
	var zoom_x = viewport_size.x / room_size_px.x
	var zoom_y = viewport_size.y / room_size_px.y
	var base_zoom = (zoom_x + zoom_y) * 0.5

	# usamos el más restrictivo para que ENTRE ENTERA
	var margin_factor := 0.7  # más chico = más alejado (más aire alrededor)



	# 🛑 clamp para evitar zoom exagerado
	var target_zoom_value = clamp(base_zoom * margin_factor, 0.6, 2.5)

	var zoom_vec = Vector2(target_zoom_value, target_zoom_value)

	var tween := create_tween()

	# 🔥 “cinematic feel”
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	# micro delay para sensación de corte de sala
	tween.tween_interval(0.08)
	
	tween.set_parallel(true)

	# movimiento suave + zoom desacoplado
	tween.tween_property(camera, "global_position", target_pos, 0.35)
	tween.tween_property(camera, "zoom", zoom_vec, 0.35)

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

	_tween_room_lights(animate)
	emit_signal("room_changed", active_room_id)
	_update_camera_for_room(room_id, animate)
	
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

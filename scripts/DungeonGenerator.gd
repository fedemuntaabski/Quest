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
var room_system: RoomSystem = null
var room_camera_controller: RoomCameraController = null
var layout_generator: DungeonLayoutGenerator
var room_manager: DungeonRoomManager = null
var wall_manager: DungeonWallManager = null
var room_factory: DungeonRoomFactory = null
var scene_helper: DungeonSceneHelper = null

var tile_renderer: DungeonTileRenderer = null

var is_ready: bool = false
var runtime_setup: DungeonRuntimeSetup = DungeonRuntimeSetup.new()


func _ready() -> void:
	_ensure_runtime_nodes()


func _ensure_runtime_nodes() -> void:
	if runtime_setup == null:
		runtime_setup = DungeonRuntimeSetup.new()

	runtime_setup.ensure_runtime_nodes(self)


func _ensure_managers() -> void:
	if not room_system:
		room_system = RoomSystem.new()
		room_system.name = "RoomSystem"
		add_child(room_system)
		room_system.setup(self)

		if not room_system.room_changed.is_connected(_on_room_changed_proxy):
			room_system.room_changed.connect(_on_room_changed_proxy)

	if not room_camera_controller:
		room_camera_controller = RoomCameraController.new()
		room_camera_controller.name = "RoomCameraController"
		add_child(room_camera_controller)
		room_camera_controller.setup(self)


func get_spawned_player() -> CharacterBody2D:
	return _spawned_player


func get_room_info(room_id: int) -> Dictionary:
	if room_id < 0 or room_id >= room_infos.size():
		return {}
	return room_infos[room_id]


func _on_room_changed_proxy(room_id: int) -> void:
	_set_active_room(room_id, true)


func _ensure_scene_roots() -> void:
	if scene_helper:
		scene_helper.ensure_scene_roots()


func _ensure_node(node_name: String) -> Node2D:
	return scene_helper.ensure_node(node_name) if scene_helper else null


func _on_room_cleared(room_id: int) -> void:
	emit_signal("room_cleared", room_id)


func generate_dungeon(player: CharacterBody2D = null) -> void:
	randomize()
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

	is_ready = true

	if not layout_generator.generate():
		push_error("DungeonGenerator: Failed to generate exactly %d rooms." % room_count)
		return

	wall_manager.generate_walls_from_floor()

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
	if wall_manager:
		wall_manager.set_wall_at_world(world_position)


func clear_cell_at_world(world_position: Vector2) -> void:
	if wall_manager:
		wall_manager.clear_cell_at_world(world_position)


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
	return scene_helper.ensure_tile_map_layer(node_name) if scene_helper else null


func _clear_generated_content() -> void:
	if scene_helper:
		scene_helper.clear_generated_content()


func _create_room_light(room_rect: Rect2i, center_cell: Vector2i) -> PointLight2D:
	return room_factory.create_room_light(room_rect, center_cell) if room_factory else PointLight2D.new()


func _create_room_area(room_id: int, room_rect: Rect2i) -> Area2D:
	return room_factory.create_room_area(room_id, room_rect) if room_factory else Area2D.new()


func _set_active_room(room_id: int, animate: bool) -> void:
	if room_manager:
		room_manager.set_active_room(room_id, animate)


func _tween_room_lights(animate: bool) -> void:
	if room_manager:
		room_manager.tween_room_lights(animate)
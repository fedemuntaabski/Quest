extends Node2D
class_name DungeonGenerator

@export var floor_tileset: TileSet = preload("res://assets/texture/enviorment/dungeon_tileset.tres")

@warning_ignore("unused_signal")
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

@export var room_light_energy: float = 0.0
@export var room_light_transition_seconds: float = 0.45

@export var corridor_min_length: int = 4
@export var corridor_max_length: int = 10

@export var main_path_branching: bool = false

var wall_texture: Texture2D = preload(WALL_TEXTURE_PATH)
var light_texture: Texture2D = preload(LIGHT_TEXTURE_PATH)

var grid_origin: Vector2 = Vector2.ZERO
var floor_cells: Dictionary = {}
var wall_cells: Dictionary = {}
var corridor_cells: Dictionary = {}
var wall_nodes: Dictionary = {}
# Layout data is the compile-time contract. It must remain free of runtime node
# references and mutable presentation flags.
var room_infos: Array[Dictionary] = []
var room_layouts: Array[DungeonRoomLayoutState] = []
var room_runtime: Dictionary = {}
var room_presentation: Dictionary = {}
var active_room_id: int = -1
var dungeon_graph: DungeonGraph = null

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
var modular_room_assembler: ModularRoomAssembler = null
var room_factory: DungeonRoomFactory = null
var room_prefab_adapter: RoomPrefabAdapter = null
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

		if not room_system.room_changed.is_connected(Callable(self, "_set_active_room").bind(true)):
			room_system.room_changed.connect(Callable(self, "_set_active_room").bind(true))

	if not room_camera_controller:
		room_camera_controller = RoomCameraController.new()
		room_camera_controller.name = "RoomCameraController"
		add_child(room_camera_controller)
		room_camera_controller.setup(self)


func get_spawned_player() -> CharacterBody2D:
	return _spawned_player


func get_room_layout_infos() -> Array[Dictionary]:
	return room_infos


func get_room_layout_info(room_id: int) -> Dictionary:
	if room_id < 0 or room_id >= room_infos.size():
		return {}
	return room_infos[room_id]


func get_room_layout_state(room_id: int) -> DungeonRoomLayoutState:
	if room_id < 0 or room_id >= room_layouts.size():
		return null
	return room_layouts[room_id]


func get_room_connectors(room_id: int) -> Array[RoomConnectorData]:
	var layout_state := get_room_layout_state(room_id)
	if layout_state == null:
		return []
	return layout_state.connectors.duplicate(true)


func get_room_local_floor_cells(room_id: int) -> Array[Vector2i]:
	var layout_state := get_room_layout_state(room_id)
	if layout_state == null:
		return []
	return layout_state.local_floor_cells.duplicate(true)


func get_room_runtime_state(room_id: int) -> DungeonRoomRuntimeState:
	return room_runtime.get(room_id, null)


func get_room_runtime_states() -> Array[DungeonRoomRuntimeState]:
	var states: Array[DungeonRoomRuntimeState] = []
	for info in room_infos:
		var room_id := int(info.get("id", -1))
		states.append(get_room_runtime_state(room_id))
	return states


func get_room_layout_states() -> Array[DungeonRoomLayoutState]:
	return room_layouts


func get_room_presentation_states() -> Array[DungeonRoomPresentationState]:
	var states: Array[DungeonRoomPresentationState] = []
	for info in room_infos:
		var room_id := int(info.get("id", -1))
		states.append(get_room_presentation_state(room_id))
	return states


func get_room_presentation_state(room_id: int) -> DungeonRoomPresentationState:
	return room_presentation.get(room_id, null)


func get_room_prefab_adapter() -> RoomPrefabAdapter:
	return room_prefab_adapter


func get_room_info(room_id: int) -> Dictionary:
	if room_id < 0 or room_id >= room_infos.size():
		return {}
	# Legacy compatibility shim: returns merged room data for older callers.
	var base_info: Dictionary = room_infos[room_id].duplicate(true)
	var runtime_state := get_room_runtime_state(room_id)
	if runtime_state != null:
		base_info["visited"] = runtime_state.visited
	var presentation_state := get_room_presentation_state(room_id)
	if presentation_state != null:
		base_info["visual_root"] = presentation_state.visual_root
		base_info["light"] = presentation_state.light
		base_info["area"] = presentation_state.area
	return base_info


func get_room_infos_with_runtime() -> Array[Dictionary]:
	# Legacy compatibility surface for consumers that still expect merged room
	# dictionaries. Prefer the explicit layout/runtime/presentation accessors.
	var result: Array[Dictionary] = []
	for index in range(room_infos.size()):
		var room_id: int = int(room_infos[index].get("id", index))
		result.append(get_room_info(room_id))
	return result


func _initialize_room_state() -> void:
	room_runtime.clear()
	room_presentation.clear()
	room_layouts.clear()
	for info in room_infos:
		var room_id := int(info.get("id", -1))
		if room_id < 0:
			continue
		var room_local_cells: Array = info.get("local_floor_cells", [])
		var room_connectors: Array = info.get("connectors", [])
		var layout_state := DungeonRoomLayoutState.new(
			room_id,
			info.get("rect", Rect2i()),
			info.get("floor_cells", []),
			room_local_cells,
			room_connectors,
			info.get("corridor_connections", []),
			info.get("connected_room_ids", []),
			str(info.get("template", "")),
			info.get("topology_metadata", {})
		)
		room_layouts.append(layout_state)
		room_runtime[room_id] = DungeonRoomRuntimeState.new(room_id)
		room_presentation[room_id] = DungeonRoomPresentationState.new(room_id)


func is_room_visited(room_id: int) -> bool:
	var runtime_state := get_room_runtime_state(room_id)
	return runtime_state != null and runtime_state.visited


func set_room_visited(room_id: int, value: bool) -> void:
	var runtime_state := get_room_runtime_state(room_id)
	if runtime_state == null:
		runtime_state = DungeonRoomRuntimeState.new(room_id)
		room_runtime[room_id] = runtime_state
	runtime_state.visited = value


func get_room_presentation(room_id: int) -> Dictionary:
	var presentation_state := get_room_presentation_state(room_id)
	if presentation_state == null:
		return {
			"visual_root": null,
			"light": null,
			"area": null,
			"marker_refs": {}
		}
	return presentation_state.to_dictionary()


func get_room_marker_ref(room_id: int, marker_name: String) -> Node2D:
	var presentation_state := get_room_presentation_state(room_id)
	if presentation_state == null:
		return null
	return presentation_state.get_marker_ref(marker_name)


func get_room_spawn_marker_ref(room_id: int) -> Node2D:
	return get_room_marker_ref(room_id, "SpawnJugador")


func get_room_tutorial_spawn_marker_ref(room_id: int) -> Node2D:
	return get_room_marker_ref(room_id, "SpawnTutorial")


func set_room_presentation(room_id: int, presentation: Dictionary) -> void:
	if room_id < 0:
		return
	var presentation_state := get_room_presentation_state(room_id)
	if presentation_state == null:
		presentation_state = DungeonRoomPresentationState.new(room_id)
		room_presentation[room_id] = presentation_state
	if presentation.has("visual_root"):
		presentation_state.visual_root = presentation.get("visual_root", null)
	if presentation.has("light"):
		presentation_state.light = presentation.get("light", null)
	if presentation.has("area"):
		presentation_state.area = presentation.get("area", null)
	if presentation.has("marker_refs"):
		presentation_state.set_marker_refs(presentation.get("marker_refs", {}))


func get_connected_room_ids(room_id: int) -> Array[int]:
	if layout_generator == null:
		return []

	return layout_generator.get_connected_room_ids(room_id)


func are_rooms_connected(room_a: int, room_b: int) -> bool:
	if layout_generator == null:
		return false

	return layout_generator.are_rooms_connected(room_a, room_b)


func get_dungeon_graph() -> DungeonGraph:
	if layout_generator:
		return layout_generator.get_dungeon_graph()
	return dungeon_graph


func get_room_spawn_forbidden_cells(room_id: int) -> Dictionary:
	var forbidden: Dictionary = {}
	var room_info := get_room_info(room_id)
	if room_info.is_empty():
		return forbidden

	var room_cells: Array = room_info.get("floor_cells", [])
	if room_cells.is_empty():
		return forbidden

	var room_cell_set: Dictionary = {}
	for raw_cell in room_cells:
		var cell: Vector2i = raw_cell
		room_cell_set[cell] = true

	for raw_cell in room_cells:
		var cell: Vector2i = raw_cell
		if _is_room_entrance_cell(cell, room_cell_set):
			forbidden[cell] = true
			for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var neighbor: Vector2i = cell + dir
				if room_cell_set.has(neighbor):
					forbidden[neighbor] = true

	return forbidden


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
	corridor_cells.clear()
	wall_nodes.clear()
	room_infos.clear()
	room_layouts.clear()
	room_runtime.clear()
	room_presentation.clear()

	active_room_id = -1
	dungeon_graph = null

	grid_origin = Vector2(
		-(float(grid_width) * 0.5 * tile_size),
		-(float(grid_height) * 0.5 * tile_size)
	)

	is_ready = true
	_ensure_runtime_nodes()

	var layout_data := layout_generator.generate()
	if layout_data == null or not layout_data.is_valid(room_count):
		push_error("DungeonGenerator: Failed to generate exactly %d rooms." % room_count)
		return

	_apply_layout_data(layout_data)

	wall_manager.generate_walls_from_floor()

	var presentation := get_node_or_null("PresentationManager") as DungeonPresentationManager
	if presentation == null:
		presentation = DungeonPresentationManager.new()
		presentation.name = "PresentationManager"
		add_child(presentation)

	presentation.setup(self, self)
	presentation.build(floor_tileset, wall_texture)

	if player:
		_spawned_player = player
		place_player_in_start_room(player)
	else:
		push_warning("DungeonGenerator: No player provided for placement. Call place_player_in_start_room() manually after generation.")

	if not room_infos.is_empty():
		_set_active_room(int(room_infos[0]["id"]), false)


func _apply_layout_data(layout_data: DungeonLayoutData) -> void:
	# Runtime authority commits generated layout data in one place.
	# The layout handoff uses typed arrays, but duplicate(true) can erase the
	# type information at runtime, so normalize the copies before assignment.
	room_layouts = _copy_room_layouts(layout_data.room_layouts)
	floor_cells = layout_data.floor_cells.duplicate(true)
	corridor_cells = layout_data.corridor_cells.duplicate(true)
	room_infos = _copy_room_infos(layout_data.room_infos)
	dungeon_graph = layout_data.graph
	_initialize_room_state()


func _copy_room_layouts(source: Array[DungeonRoomLayoutState]) -> Array[DungeonRoomLayoutState]:
	var copy: Array[DungeonRoomLayoutState] = []
	for room_layout in source:
		copy.append(room_layout)
	return copy


func _copy_room_infos(source: Array[Dictionary]) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for room_info in source:
		copy.append(room_info.duplicate(true))
	return copy


func place_player_in_start_room(player: CharacterBody2D) -> void:
	if room_infos.is_empty() or player == null:
		return

	var start_room := room_infos[0]
	var marker := get_room_spawn_marker_ref(int(start_room.get("id", 0)))
	if marker:
		player.global_position = marker.global_position
	else:
		push_warning("DungeonGenerator: SpawnJugador marker not found in start room; falling back to room center.")
		var center_cell: Vector2i = start_room["center_cell"]
		player.global_position = grid_to_world_coords(center_cell)
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
		emit_signal("room_changed", room_id)


func _tween_room_lights(animate: bool) -> void:
	if room_manager:
		room_manager.tween_room_lights(animate)


func _is_room_entrance_cell(cell: Vector2i, room_cell_set: Dictionary) -> bool:
	for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var neighbor: Vector2i = cell + dir
		if floor_cells.has(neighbor) and not room_cell_set.has(neighbor):
			return true

	return false
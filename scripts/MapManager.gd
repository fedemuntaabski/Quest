extends Node2D
class_name MapManager

@onready var dungeon_generator: DungeonGenerator = $DungeonGenerator
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D

var hovered_cell: Vector2i = Vector2i(-999, -999)
var enemy_manager: EnemyManager
var navigation_helper: MapNavigationHelper
var enemy_tracker: MapEnemyTracker

# 🔥 NUEVO
var turn_manager: TurnManager

signal hover_changed(cell: Vector2i)


func _ready() -> void:
	add_to_group("map_manager")

	if dungeon_generator == null:
		push_error("MapManager: DungeonGenerator node is missing.")
		return

	_ensure_helpers()

	# 🔥 NUEVO
	_setup_turn_manager()

	var player := get_node_or_null("Player") as CharacterBody2D
	dungeon_generator.generate_dungeon(player)

	if dungeon_generator.floor_cells.is_empty():
		push_warning("MapManager: Dungeon generation failed or empty.")
		return

	_setup_enemy_manager()
	navigation_helper.bake_navigation_region()


# 🔥 NUEVO
func _setup_turn_manager() -> void:
	if turn_manager != null:
		return

	turn_manager = TurnManager.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)


func _ensure_helpers() -> void:
	if navigation_helper == null:
		navigation_helper = MapNavigationHelper.new()
		navigation_helper.name = "MapNavigationHelper"
		add_child(navigation_helper)
		navigation_helper.setup(dungeon_generator, nav_region)

	if enemy_tracker == null:
		enemy_tracker = MapEnemyTracker.new()
		enemy_tracker.name = "MapEnemyTracker"
		add_child(enemy_tracker)
		enemy_tracker.setup(dungeon_generator)


# ── Hover ─────────────────────────────────────────────────────────────────────
func update_hover(world_pos: Vector2) -> void:
	var new_cell: Vector2i = world_to_grid(world_pos)

	if new_cell == hovered_cell:
		return

	hovered_cell = new_cell
	hover_changed.emit(new_cell)


func _on_hover_changed(cell: Vector2i) -> void:
	print("DRAW CELL:", cell)
	hovered_cell = cell
	queue_redraw()


func _process(_delta: float) -> void:
	if dungeon_generator == null or not dungeon_generator.is_ready:
		return

	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	update_hover(cam.get_global_mouse_position())


# ── Grid helpers ──────────────────────────────────────────────────────────────
func world_to_grid(world: Vector2) -> Vector2i:
	return navigation_helper.world_to_grid_coords(world) if navigation_helper else Vector2i.ZERO


func grid_to_world(grid: Vector2i) -> Vector2:
	return navigation_helper.grid_to_world_coords(grid) if navigation_helper else Vector2.ZERO


func is_walkable_cell(grid_pos: Vector2i) -> bool:
	if navigation_helper == null:
		return false

	return navigation_helper.is_cell_walkable(
		navigation_helper.grid_to_world_coords(grid_pos)
	)


# ── Enemy manager ─────────────────────────────────────────────────────────────
func _setup_enemy_manager() -> void:
	if enemy_manager != null:
		return

	enemy_manager = EnemyManager.new()
	enemy_manager.name = "EnemyManager"
	add_child(enemy_manager)

	var player := get_node_or_null("Player")

	# 🔥 MODIFICADO: ahora recibe turn_manager
	enemy_manager.setup(
		dungeon_generator,
		player,
		turn_manager
	)

	enemy_manager.room_cleared.connect(_on_room_cleared_from_enemies)

	enemy_manager.spawn_enemies(
		dungeon_generator.room_infos,
		dungeon_generator.wall_cells
	)

	# 🔥 REGISTRAR PLAYER EN TURN MANAGER
	if player and turn_manager:
		turn_manager.register_actor(player)

	# 🔥 INICIAR SISTEMA DE TURNOS
	if turn_manager:
		turn_manager.start()


func _on_room_cleared_from_enemies(room_id: int) -> void:
	print("Room cleared by enemies:", room_id)


# ── Enemy tracking ────────────────────────────────────────────────────────────
func register_enemy(world_position: Vector2, enemy_node: Node2D) -> void:
	if enemy_tracker:
		enemy_tracker.register_enemy(world_position, enemy_node)


func unregister_enemy(world_position: Vector2) -> void:
	if enemy_tracker:
		enemy_tracker.unregister_enemy(world_position)


func get_enemy_at_cell(grid_pos: Vector2i) -> Node2D:
	return enemy_tracker.get_enemy_at_cell(grid_pos) if enemy_tracker else null


func has_enemy_at_cell(world_position: Vector2) -> bool:
	return enemy_tracker.has_enemy_at_cell(world_position) if enemy_tracker else false


# ── Wrappers directos (sin lógica) ────────────────────────────────────────────
func is_cell_walkable(world_position: Vector2) -> bool:
	return navigation_helper.is_cell_walkable(world_position) if navigation_helper else false


func world_to_grid_coords(world_pos: Vector2) -> Vector2i:
	return navigation_helper.world_to_grid_coords(world_pos) if navigation_helper else Vector2i.ZERO


func grid_to_world_coords(grid_pos: Vector2i) -> Vector2:
	return navigation_helper.grid_to_world_coords(grid_pos) if navigation_helper else Vector2.ZERO


func set_wall(world_position: Vector2) -> void:
	if navigation_helper:
		navigation_helper.set_wall(world_position)


func clear_cell(world_position: Vector2) -> void:
	if navigation_helper:
		navigation_helper.clear_cell(world_position)


func get_adjacent_walkable_cells(world_position: Vector2) -> Array:
	return navigation_helper.get_adjacent_walkable_cells(world_position) if navigation_helper else []


func is_within_bounds(grid_pos: Vector2i) -> bool:
	return navigation_helper.is_within_bounds(grid_pos) if navigation_helper else false


# ── Pathfinding ───────────────────────────────────────────────────────────────
func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return navigation_helper.find_path(start, goal) if navigation_helper else []
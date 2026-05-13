extends Node2D
class_name MapManager

const MapTurnSetup = preload("res://scripts/MapTurnSetup.gd")

@onready var dungeon_generator: DungeonGenerator = $DungeonGenerator
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D

var hovered_cell: Vector2i = Vector2i(-999, -999)
var enemy_manager: EnemyManager
var navigation_helper: MapNavigationHelper
var occupancy_manager: OccupancyManager
var floating_text_manager: FloatingTextManager

# 🔥 NUEVO
var turn_manager: TurnManager
var turn_setup: MapTurnSetup = MapTurnSetup.new()

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
	if turn_setup == null:
		turn_setup = MapTurnSetup.new()

	turn_setup.ensure_turn_manager(self)


func _ensure_helpers() -> void:
	if navigation_helper == null:
		navigation_helper = MapNavigationHelper.new()
		navigation_helper.name = "MapNavigationHelper"
		add_child(navigation_helper)
		navigation_helper.setup(dungeon_generator, nav_region)

	if occupancy_manager == null:
		occupancy_manager = OccupancyManager.new()
		occupancy_manager.name = "OccupancyManager"
		add_child(occupancy_manager)

	if floating_text_manager == null:
		floating_text_manager = FloatingTextManager.new()
		floating_text_manager.name = "FloatingTextManager"
		add_child(floating_text_manager)

	if navigation_helper:
		navigation_helper.set_occupancy_manager(occupancy_manager)


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
	update_hover(_get_mouse_world_pos())

func _get_mouse_world_pos() -> Vector2:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var canvas_to_world: Transform2D = get_global_transform_with_canvas().affine_inverse()
	return canvas_to_world * mouse_pos


# ── Grid helpers ──────────────────────────────────────────────────────────────
func world_to_grid(world: Vector2) -> Vector2i:
	return navigation_helper.world_to_grid_coords(world) if navigation_helper else Vector2i.ZERO


func grid_to_world(grid: Vector2i) -> Vector2:
	return navigation_helper.grid_to_world_coords(grid) if navigation_helper else Vector2.ZERO


func is_walkable_cell(grid_pos: Vector2i) -> bool:
	if navigation_helper == null:
		return false

	var world_pos := navigation_helper.grid_to_world_coords(grid_pos)
	if not navigation_helper.is_cell_walkable(world_pos):
		return false

	if occupancy_manager and occupancy_manager.is_cell_blocked(grid_pos):
		return false

	return true

func is_walkable_cell_for_actor(grid_pos: Vector2i, actor: Node) -> bool:
	if not is_walkable_cell(grid_pos):
		return false

	return is_cell_allowed_for_actor(grid_pos, actor)

func is_cell_allowed_for_actor(grid_pos: Vector2i, actor: Node) -> bool:
	if dungeon_generator == null:
		return true

	if actor == null:
		return true

	if actor is PlayerMovement or actor.is_in_group("player"):
		if not _is_player_room_locked():
			return true
		var room_rect := _get_room_rect(dungeon_generator.active_room_id)
		var player_pos: Vector2i = actor.grid_pos if "grid_pos" in actor else Vector2i.ZERO
		# Only restrict movement if player is actually inside the locked room.
		# If player is in corridor (outside room rect), allow free movement.
		if not room_rect.has_point(player_pos):
			return true
		return room_rect.has_point(grid_pos)

	if actor is Enemy:
		var enemy: Enemy = actor
		if enemy.my_room_id < 0:
			return true
		var enemy_rect := _get_room_rect(enemy.my_room_id)
		return enemy_rect.has_point(grid_pos)

	return true


# ── Enemy manager ─────────────────────────────────────────────────────────────
func _setup_enemy_manager() -> void:
	if turn_setup == null:
		turn_setup = MapTurnSetup.new()

	turn_setup.setup_enemy_manager(self)


func _on_room_cleared_from_enemies(room_id: int) -> void:
	print("Room cleared by enemies:", room_id)


# ── Enemy tracking ────────────────────────────────────────────────────────────
func register_enemy(world_position: Vector2, enemy_node: Node2D) -> void:
	if enemy_node == null:
		return
	var grid_pos := world_to_grid_coords(world_position)
	register_actor(enemy_node, grid_pos, true)


func unregister_enemy(world_position: Vector2) -> void:
	var grid_pos := world_to_grid_coords(world_position)
	var actor := get_actor_at_cell(grid_pos)
	if actor is Enemy:
		unregister_actor(actor)


func get_enemy_at_cell(grid_pos: Vector2i) -> Node2D:
	var actor := get_actor_at_cell(grid_pos)
	return actor if actor is Enemy else null


func has_enemy_at_cell(world_position: Vector2) -> bool:
	var grid_pos := world_to_grid_coords(world_position)
	return get_enemy_at_cell(grid_pos) != null


# ── Wrappers directos (sin lógica) ────────────────────────────────────────────
func is_cell_walkable(world_position: Vector2) -> bool:
	if navigation_helper == null:
		return false

	if not navigation_helper.is_cell_walkable(world_position):
		return false

	var grid_pos := navigation_helper.world_to_grid_coords(world_position)
	if occupancy_manager and occupancy_manager.is_cell_blocked(grid_pos):
		return false

	return true


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
func find_path(start: Vector2i, goal: Vector2i, actor: Node = null) -> Array[Vector2i]:
	if navigation_helper == null:
		return []

	var room_rect := _get_actor_room_rect(actor)
	var use_room := room_rect.size != Vector2i.ZERO
	if use_room:
		if not room_rect.has_point(start) or not room_rect.has_point(goal):
			return []

	return navigation_helper.find_path(start, goal, false, room_rect, use_room)

func find_path_to_adjacent(start: Vector2i, target: Vector2i, actor: Node = null) -> Array[Vector2i]:
	if navigation_helper == null:
		return []

	var best_path: Array[Vector2i] = []
	var room_rect := _get_actor_room_rect(actor)
	var use_room := room_rect.size != Vector2i.ZERO
	if use_room and not room_rect.has_point(start):
		return []
	var neighbors: Array[Vector2i] = [
		target + Vector2i.UP,
		target + Vector2i.DOWN,
		target + Vector2i.LEFT,
		target + Vector2i.RIGHT
	]

	for cell in neighbors:
		if not is_walkable_cell_for_actor(cell, actor):
			continue

		var path := navigation_helper.find_path(start, cell, false, room_rect, use_room)
		if path.is_empty():
			continue

		if best_path.is_empty() or path.size() < best_path.size():
			best_path = path

	return best_path

func _get_room_rect(room_id: int) -> Rect2i:
	if dungeon_generator == null:
		return Rect2i()

	if room_id < 0 or room_id >= dungeon_generator.room_infos.size():
		return Rect2i()

	var info: Dictionary = dungeon_generator.room_infos[room_id]
	return info.get("rect", Rect2i())

func get_room_id_for_cell(grid_pos: Vector2i) -> int:
	if dungeon_generator == null:
		return -1
	for info in dungeon_generator.room_infos:
		var rect: Rect2i = info.get("rect", Rect2i())
		if rect.has_point(grid_pos):
			return int(info.get("id", -1))
	return -1

func get_actor_room_id(actor: Node) -> int:
	if actor == null:
		return -1
	if actor is Enemy:
		return actor.my_room_id
	var cell: Variant = get_actor_cell(actor)
	if cell == null and actor.get("grid_pos") != null:
		cell = actor.get("grid_pos")
	if cell == null:
		return -1
	return get_room_id_for_cell(cell)

func can_actors_engage(source: Node, target: Node) -> bool:
	if dungeon_generator == null:
		return true
	if source == null or target == null:
		return false
	var source_room := get_actor_room_id(source)
	var target_room := get_actor_room_id(target)
	if source_room == -1 and target_room == -1:
		return true
	return source_room != -1 and source_room == target_room

func _is_player_room_locked() -> bool:
	if dungeon_generator == null or enemy_manager == null:
		return false

	var room_id := dungeon_generator.active_room_id
	if room_id < 0:
		return false

	return enemy_manager.get_enemies_in_room(room_id) > 0

func _get_actor_room_rect(actor: Node) -> Rect2i:
	if actor == null:
		return Rect2i()

	if actor is PlayerMovement or actor.is_in_group("player"):
		if not _is_player_room_locked():
			return Rect2i()
		var room_rect := _get_room_rect(dungeon_generator.active_room_id)
		var player_pos: Vector2i = actor.grid_pos if "grid_pos" in actor else Vector2i.ZERO
		# Only return room rect if player is actually inside the room.
		# If player is in corridor, return empty rect to allow free pathfinding.
		if room_rect.has_point(player_pos):
			return room_rect
		return Rect2i()

	if actor is Enemy:
		var enemy: Enemy = actor
		return _get_room_rect(enemy.my_room_id)

	return Rect2i()

# ── Occupancy helpers ────────────────────────────────────────────────────────
func register_actor(actor: Node, grid_pos: Vector2i, blocks: bool = true) -> void:
	if occupancy_manager:
		occupancy_manager.register_actor(actor, grid_pos, blocks)

func unregister_actor(actor: Node) -> void:
	if occupancy_manager:
		occupancy_manager.unregister_actor(actor)

func update_actor_cell(actor: Node, grid_pos: Vector2i) -> void:
	if occupancy_manager:
		occupancy_manager.update_actor_cell(actor, grid_pos)

func get_actor_at_cell(grid_pos: Vector2i) -> Node:
	return occupancy_manager.get_actor_at_cell(grid_pos) if occupancy_manager else null

func get_actor_cell(actor: Node) -> Variant:
	return occupancy_manager.get_actor_cell(actor) if occupancy_manager else null

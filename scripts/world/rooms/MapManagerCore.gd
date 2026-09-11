extends Node
class_name MapManagerCore

## Lightweight helper for MapManager: grid conversions, walkability and occupancy helpers
# Notes:
# - This module exposes readonly helpers and does not perform side-effectful
#   repairs unless an explicit `repair_actor_room` call is used by the caller.
var map_manager: MapManager = null

func setup(map_mgr: MapManager) -> void:
	map_manager = map_mgr

func _nav() -> MapNavigationHelper:
	return map_manager.navigation_helper if map_manager else null

func _dungeon() -> DungeonGenerator:
	return map_manager.dungeon_generator if map_manager else null

func _occupancy() -> OccupancyManager:
	return map_manager.occupancy_manager if map_manager else null

func _enemy_manager() -> EnemyManager:
	return map_manager.enemy_manager if map_manager else null

func _is_active_gameplay() -> bool:
	if map_manager == null:
		return false
	var tree := map_manager.get_tree()
	if tree == null:
		return false
	var gsm := tree.get_first_node_in_group("game_state_manager") as GameStateManager
	if gsm == null:
		return true
	return gsm.can_process_input()

func world_to_grid(world: Vector2) -> Vector2i:
	return world_to_grid_coords(world)

func grid_to_world(grid: Vector2i) -> Vector2:
	return grid_to_world_coords(grid)

func is_walkable_cell(grid_pos: Vector2i) -> bool:
	var nav: MapNavigationHelper = _nav()
	if nav == null:
		return false

	var world_pos: Vector2 = nav.grid_to_world_coords(grid_pos)
	if not nav.is_cell_walkable(world_pos):
		return false

	var occ: OccupancyManager = _occupancy()
	if occ and occ.is_cell_blocked(grid_pos):
		return false

	return true

func is_walkable_cell_for_actor(grid_pos: Vector2i, actor: Node) -> bool:
	if not is_walkable_cell(grid_pos):
		return false
	return is_cell_allowed_for_actor(grid_pos, actor)

func is_cell_allowed_for_actor(grid_pos: Vector2i, actor: Node) -> bool:
	var dungeon: DungeonGenerator = _dungeon()
	if dungeon == null:
		return true
	if actor == null:
		return true

	if actor is PlayerMovement or actor.is_in_group("player"):
		if not _is_player_room_locked():
			return true
		var room_rect := _get_room_rect(dungeon.active_room_id)
		var player_pos: Vector2i = actor.grid_pos if "grid_pos" in actor else Vector2i.ZERO
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

func is_cell_walkable_world(world_position: Vector2) -> bool:
	var nav: MapNavigationHelper = _nav()
	if nav == null:
		return false
	if not nav.is_cell_walkable(world_position):
		return false
	var grid_pos: Vector2i = nav.world_to_grid_coords(world_position)
	var occ: OccupancyManager = _occupancy()
	if occ and occ.is_cell_blocked(grid_pos):
		return false
	return true

func world_to_grid_coords(world_pos: Vector2) -> Vector2i:
	var nav: MapNavigationHelper = _nav()
	return nav.world_to_grid_coords(world_pos) if nav else Vector2i.ZERO

func grid_to_world_coords(grid_pos: Vector2i) -> Vector2:
	var nav: MapNavigationHelper = _nav()
	return nav.grid_to_world_coords(grid_pos) if nav else Vector2.ZERO

func set_wall(world_position: Vector2) -> void:
	var nav: MapNavigationHelper = _nav()
	if nav:
		nav.set_wall(world_position)

func clear_cell(world_position: Vector2) -> void:
	var nav: MapNavigationHelper = _nav()
	if nav:
		nav.clear_cell(world_position)

func get_adjacent_walkable_cells(world_position: Vector2) -> Array:
	var nav: MapNavigationHelper = _nav()
	return nav.get_adjacent_walkable_cells(world_position) if nav else []

func is_within_bounds(grid_pos: Vector2i) -> bool:
	var nav: MapNavigationHelper = _nav()
	return nav.is_within_bounds(grid_pos) if nav else false

func find_path(start: Vector2i, goal: Vector2i, actor: Node = null) -> Array[Vector2i]:
	var nav: MapNavigationHelper = _nav()
	if nav == null:
		return []

	var room_rect := _get_actor_room_rect(actor)
	var use_room := room_rect.size != Vector2i.ZERO
	if use_room:
		if not room_rect.has_point(start) or not room_rect.has_point(goal):
			return []

	return nav.find_path_preferred(start, goal, false, room_rect, use_room)

func find_path_to_adjacent(start: Vector2i, target: Vector2i, actor: Node = null) -> Array[Vector2i]:
	var nav: MapNavigationHelper = _nav()
	if nav == null:
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

		var path := nav.find_path_preferred(start, cell, false, room_rect, use_room)
		if path.is_empty():
			continue

		if best_path.is_empty() or path.size() < best_path.size():
			best_path = path

	return best_path

func _get_room_rect(room_id: int) -> Rect2i:
	var dungeon: DungeonGenerator = _dungeon()
	if dungeon == null:
		return Rect2i()
	if room_id < 0 or room_id >= dungeon.room_infos.size():
		return Rect2i()
	var info: Dictionary = dungeon.room_infos[room_id]
	return info.get("rect", Rect2i())

func get_room_id_for_cell(grid_pos: Vector2i) -> int:
	var dungeon: DungeonGenerator = _dungeon()
	if dungeon == null:
		return -1
	for info in dungeon.room_infos:
		var rect: Rect2i = info.get("rect", Rect2i())
		if rect.has_point(grid_pos):
			return int(info.get("id", -1))
	return -1

func _resolve_actor_cell(actor: Node) -> Variant:
	if actor == null:
		return null
	var cell: Variant = get_actor_cell(actor)
	if cell != null:
		return cell
	# Read-only resolution: prefer occupancy, then actor.local grid_pos, then world position.
	if "grid_pos" in actor and actor.grid_pos != null:
		cell = actor.grid_pos
	if cell == null and actor is Node2D and map_manager:
		cell = map_manager.world_to_grid_coords((actor as Node2D).global_position)
	# Do NOT write occupancy here; caller must call explicit repair if needed.
	return cell

func _repair_room_id_from_actor(actor: Node) -> int:
	var cell: Variant = _resolve_actor_cell(actor)
	if cell == null:
		return -1
	return get_room_id_for_cell(cell)


func repair_actor_room(actor: Node) -> int:
	# Explicit repair: reconcile occupancy and actor-local fields, and return resolved room id.
	if actor == null:
		return -1
	var cell: Variant = _resolve_actor_cell(actor)
	if cell == null:
		return -1
	# Register occupancy and ensure actor.grid_pos is canonical via update_actor_cell
	update_actor_cell(actor, cell)
	var room_id: int = get_room_id_for_cell(cell)
	if room_id == -1:
		return -1
	# If actor is Enemy, persist my_room_id
	if actor is Enemy:
		actor.my_room_id = room_id
	return room_id

func get_actor_room_id(actor: Node) -> int:
	if actor == null:
		return -1
	if actor is Enemy and actor.my_room_id >= 0:
		return actor.my_room_id
	var room_id := _repair_room_id_from_actor(actor)
	if room_id != -1:
		return room_id
	# No implicit repair or fallback to dungeon.active_room_id. Caller must call repair_actor_room() explicitly.
	return -1

func can_actors_engage(source: Node, target: Node) -> bool:
	var dungeon: DungeonGenerator = _dungeon()
	if dungeon == null:
		return true
	if source == null or target == null:
		QuestLogger.warn(QuestLogger.Category.MAP, "can_actors_engage: source or target NULL")
		return false
	var source_room := get_actor_room_id(source)
	var target_room := get_actor_room_id(target)
	# If neither actor resolves to a room, allow engagement (legacy behavior)
	if source_room == -1 and target_room == -1:
		return true
	var can_engage := source_room != -1 and source_room == target_room
	if not can_engage:
		QuestLogger.debug(QuestLogger.Category.MAP, "can_actors_engage: blocked source=%s room=%d target=%s room=%d active_room=%d source_cell=%s target_cell=%s" % [source.name if source else "NULL", source_room, target.name if target else "NULL", target_room, dungeon.active_room_id, str(_resolve_actor_cell(source)), str(_resolve_actor_cell(target))])
	return can_engage

func _is_player_room_locked() -> bool:
	var dungeon: DungeonGenerator = _dungeon()
	var enemy_mgr: EnemyManager = _enemy_manager()
	if dungeon == null or enemy_mgr == null:
		return false
	var room_id: int = dungeon.active_room_id
	if room_id < 0:
		return false
	return enemy_mgr.get_enemies_in_room(room_id) > 0

func _get_actor_room_rect(actor: Node) -> Rect2i:
	var dungeon: DungeonGenerator = _dungeon()
	if actor == null:
		return Rect2i()
	if actor is PlayerMovement or actor.is_in_group("player"):
		if not _is_player_room_locked():
			return Rect2i()
		var room_rect := _get_room_rect(dungeon.active_room_id)
		var player_pos: Vector2i = actor.grid_pos if "grid_pos" in actor else Vector2i.ZERO
		if room_rect.has_point(player_pos):
			return room_rect
		return Rect2i()
	if actor is Enemy:
		var enemy: Enemy = actor
		return _get_room_rect(enemy.my_room_id)
	return Rect2i()

func register_actor(actor: Node, grid_pos: Vector2i, blocks: bool = true) -> void:
	var occ: OccupancyManager = _occupancy()
	if occ:
		occ.register_actor(actor, grid_pos, blocks)

func unregister_actor(actor: Node) -> void:
	var occ: OccupancyManager = _occupancy()
	if occ:
		occ.unregister_actor(actor)

func update_actor_cell(actor: Node, grid_pos: Vector2i) -> void:
	var occ: OccupancyManager = _occupancy()
	if occ:
		occ.update_actor_cell(actor, grid_pos)

func get_actor_at_cell(grid_pos: Vector2i) -> Node:
	var occ: OccupancyManager = _occupancy()
	return occ.get_actor_at_cell(grid_pos) if occ else null

func get_actor_cell(actor: Node) -> Variant:
	var occ: OccupancyManager = _occupancy()
	return occ.get_actor_cell(actor) if occ else null

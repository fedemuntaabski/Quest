extends Node
class_name MapManagerCore

# Lightweight helper for MapManager: grid conversions, walkability and occupancy helpers
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

func world_to_grid(world: Vector2) -> Vector2i:
	var nav = _nav()
	return nav.world_to_grid_coords(world) if nav else Vector2i.ZERO

func grid_to_world(grid: Vector2i) -> Vector2:
	var nav = _nav()
	return nav.grid_to_world_coords(grid) if nav else Vector2.ZERO

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
	var dungeon: DungeonGenerator = _dungeon()
	if dungeon == null:
		return true
	if source == null or target == null:
		return false
	var source_room := get_actor_room_id(source)
	var target_room := get_actor_room_id(target)
	if source_room == -1 and target_room == -1:
		return true
	return source_room != -1 and source_room == target_room

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

extends RefCounted
class_name MapTurnSetup

func ensure_turn_manager(map_manager: MapManager) -> void:
	if map_manager == null:
		return

	if map_manager.turn_manager != null:
		return

	map_manager.turn_manager = TurnManager.new()
	map_manager.turn_manager.name = "TurnManager"
	map_manager.add_child(map_manager.turn_manager)

func setup_enemy_manager(map_manager: MapManager) -> void:
	if map_manager == null:
		return

	if map_manager.enemy_manager != null:
		return

	map_manager.enemy_manager = EnemyManager.new()
	map_manager.enemy_manager.name = "EnemyManager"
	map_manager.add_child(map_manager.enemy_manager)

	var player := map_manager.get_node_or_null("Player")

	map_manager.enemy_manager.setup(
		map_manager.dungeon_generator,
		player,
		map_manager.turn_manager
	)

	if not map_manager.enemy_manager.room_cleared.is_connected(map_manager._on_room_cleared_from_enemies):
		map_manager.enemy_manager.room_cleared.connect(map_manager._on_room_cleared_from_enemies)

	map_manager.enemy_manager.spawn_enemies(
		map_manager.dungeon_generator.get_room_layout_infos(),
		map_manager.dungeon_generator.wall_cells
	)

	if player and map_manager.turn_manager:
		map_manager.turn_manager.register_actor(player)

	if map_manager.turn_manager:
		map_manager.turn_manager.start()

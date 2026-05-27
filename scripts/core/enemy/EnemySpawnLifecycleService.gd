extends RefCounted
class_name EnemySpawnLifecycleService

static func spawn_enemies(manager: EnemyManager, room_infos: Array, wall_cells: Dictionary) -> void:
	if manager == null:
		return
		
	# 🌟 MODIFICADO: Eliminamos el chequeo de manager._enemy_scene ya que ahora es dinámico

	manager._room_enemy_counts.clear()
	manager.enemies.clear()
	manager._run_accumulated_gold = 0
	manager.boss_spawned = false
	manager.boss_enemy = null

	var map_manager := manager.get_parent() as MapManager
	var occupied_spawn_cells: Dictionary = {}
	var player_cell: Vector2i = Vector2i(-9999, -9999)
	if map_manager and manager.player:
		player_cell = map_manager.world_to_grid_coords(manager.player.global_position)

	manager.final_room_id = _compute_final_room_id(room_infos)

	for room_info in room_infos:
		_spawn_enemy_for_room(manager, room_info, wall_cells, map_manager, player_cell, occupied_spawn_cells)

static func _compute_final_room_id(room_infos: Array) -> int:
	var computed := -1
	for ri in room_infos:
		computed = max(computed, ri.get("id", -1))
	return computed

static func _spawn_enemy_for_room(
	manager: EnemyManager,
	room_info: Dictionary,
	wall_cells: Dictionary,
	map_manager: MapManager,
	player_cell: Vector2i,
	occupied_spawn_cells: Dictionary
) -> void:
	var room_id: int = room_info["id"]

	var spawn_cell := manager._get_random_floor_cell_in_room(
		room_info,
		wall_cells,
		room_id == 0,
		player_cell,
		occupied_spawn_cells
	)

	if spawn_cell == Vector2i(-1, -1):
		return

	# 🌟 MODIFICADO: Solicitamos de forma dinámica la escena específica (Boss, Skeleton, etc.) al manager
	var enemy_scene: PackedScene = manager.get_enemy_scene_for_room(room_id)
	if enemy_scene == null:
		push_error("EnemySpawnLifecycleService: No se pudo obtener una escena válida para la habitación %d" % room_id)
		return
		
	var enemy := enemy_scene.instantiate()
	if enemy == null:
		return

	enemy.name = "Enemy_%d" % room_id
	enemy.global_position = manager.dungeon.grid_to_world_coords(spawn_cell)
	enemy.my_room_id = room_id
	enemy.dungeon_generator = manager.dungeon
	
	var selected_data := manager._select_enemy_data(room_id, manager.final_room_id)
	if selected_data and enemy.has_method("apply_enemy_data"):
		enemy.apply_enemy_data(selected_data)
		if selected_data.enemy_name != "":
			enemy.name = "%s_%d" % [selected_data.enemy_name, room_id]
			
	manager.add_child(enemy)
	_apply_cycle_hp_scaling_if_needed(enemy, selected_data)
	occupied_spawn_cells[spawn_cell] = true

	enemy.setup(manager.get_parent(), manager.player)

	if map_manager:
		if map_manager.core:
			map_manager.core.repair_actor_room(enemy)
		else:
			var grid_pos := map_manager.world_to_grid_coords(enemy.global_position)
			map_manager.update_actor_cell(enemy, grid_pos)

	if not manager.boss_spawned and room_id == manager.final_room_id:
		if selected_data and selected_data.is_boss:
			manager.boss_spawned = true
			manager.boss_enemy = enemy
			enemy.name = "Boss_Purple_%d" % room_id
			manager._set_enemy_boss_flag(enemy, true)
		else:
			manager._set_enemy_boss_flag(enemy, false)
	elif selected_data and selected_data.is_boss:
		manager._set_enemy_boss_flag(enemy, true)
	else:
		manager._set_enemy_boss_flag(enemy, false)

	manager.enemies.append(enemy)

	if manager.turn_manager:
		manager.turn_manager.register_actor(enemy)

	var captured_player := manager.player
	var captured_torch := manager.player_torch
	enemy.ready.connect(func():
		if not is_instance_valid(enemy):
			return
		enemy.player = captured_player if is_instance_valid(captured_player) else null
		enemy.player_torch = captured_torch if is_instance_valid(captured_torch) else null
	, CONNECT_ONE_SHOT)

	manager._room_enemy_counts[room_id] = manager._room_enemy_counts.get(room_id, 0) + 1

	var captured_room_id := room_id
	enemy.enemy_defeated.connect(func(e):
		manager._on_enemy_defeated(e, captured_room_id)
	, CONNECT_ONE_SHOT)

static func _apply_cycle_hp_scaling_if_needed(enemy: Node, selected_data: EnemyData) -> void:
	if enemy == null or selected_data == null:
		return
	if not selected_data.allow_cycle_scaling:
		return

	var save_mgr = ManagerLocator.get_save_manager()
	if save_mgr == null or not save_mgr.has_method("get_run_cycle"):
		return

	var cycle := int(save_mgr.get_run_cycle())
	if cycle <= 0:
		return

	var apply_scaling := func() -> void:
		var stats := enemy.get_node_or_null("Stats") as CharacterStats
		if stats == null:
			return

		var base_hp = max(1, int(stats.max_hp))
		var multiplier := 1.0 + (float(cycle) * 0.10)
		var scaled_hp = max(1, int(round(float(base_hp) * multiplier)))

		stats.max_hp = scaled_hp
		stats.current_hp = scaled_hp
		stats.hp_changed.emit(stats.current_hp, stats.max_hp)

		var health_bar := enemy.get_node_or_null("HealthBar") as ProgressBar
		if health_bar:
			health_bar.max_value = stats.max_hp
			health_bar.value = stats.current_hp

	if enemy.is_node_ready():
		apply_scaling.call()
	else:
		enemy.ready.connect(func() -> void:
			if not is_instance_valid(enemy):
				return
			apply_scaling.call()
		, CONNECT_ONE_SHOT)

extends Node2D
class_name EnemyManager

signal room_cleared(room_id: int)
signal enemy_defeated_global
signal enemy_defeated_with_reward(enemy, reward_position: Vector2)
signal boss_defeated(enemy)

const ENEMY_SCENE_PATH := "res://scenes/Enemy.tscn"
const TUTORIAL_ENEMY_DATA = preload("res://resources/enemies/tutorial.tres")
const GOBLIN_ENEMY_DATA = preload("res://resources/enemies/goblin.tres")
const BOSS_ENEMY_DATA = preload("res://resources/enemies/boss.tres")
var map_manager: MapManager = null

@export var default_enemy_data: EnemyData
@export var enemy_data_pool: Array[EnemyData] = []

var _enemy_scene: PackedScene = null
var _room_enemy_counts: Dictionary = {}

var dungeon: DungeonGenerator = null
var player: CharacterBody2D = null
var player_torch: PointLight2D = null

var enemies: Array[Enemy] = []
var turn_manager: TurnManager
var boss_spawned: bool = false
var boss_enemy: Enemy = null
var final_room_id: int = -1

const COIN_REWARD_PER_ENEMY := 5


var _run_accumulated_gold: int = 0


func _ready() -> void:
	if default_enemy_data == null:
		default_enemy_data = GOBLIN_ENEMY_DATA

	if enemy_data_pool.is_empty():
		enemy_data_pool = [
			TUTORIAL_ENEMY_DATA,
			GOBLIN_ENEMY_DATA,
			BOSS_ENEMY_DATA,
		]


func setup(dungeon_ref: DungeonGenerator, player_ref: CharacterBody2D, tm: TurnManager) -> void:
	dungeon = dungeon_ref
	player = player_ref
	turn_manager = tm
	map_manager = get_parent() as MapManager

	if player:
		player_torch = player.get_node_or_null("PointLight2D") as PointLight2D

	if _enemy_scene == null:
		_enemy_scene = load(ENEMY_SCENE_PATH) as PackedScene


func spawn_enemies(room_infos: Array, wall_cells: Dictionary) -> void:
	if _enemy_scene == null:
		push_error("EnemyManager: Enemy scene not loaded.")
		return

	_room_enemy_counts.clear()
	enemies.clear() 
	_run_accumulated_gold = 0  # Reset accumulated gold for new run
	boss_spawned = false
	boss_enemy = null

	var occupied_spawn_cells: Dictionary = {}
	var player_cell: Vector2i = Vector2i(-9999, -9999)
	if map_manager and player:
		player_cell = map_manager.world_to_grid_coords(player.global_position)

	# Determine final room id (highest id) and spawn normally for other rooms.
	final_room_id = -1
	for ri in room_infos:
		final_room_id = max(final_room_id, ri.get("id", -1))

	for room_info in room_infos:
		var room_id: int = room_info["id"]

		var spawn_cell := _get_random_floor_cell_in_room(
			room_info,
			wall_cells,
			room_id == 0,
			player_cell,
			occupied_spawn_cells
		)

		if spawn_cell == Vector2i(-1, -1):
			continue

		var enemy := _enemy_scene.instantiate()
		if enemy == null:
			continue

		enemy.name = "Enemy_%d" % room_id
		var selected_data := _select_enemy_data(room_id, final_room_id)

		add_child(enemy)

		_configure_enemy(
			enemy,
			room_id,
			spawn_cell,
			selected_data,
			map_manager
		)

		occupied_spawn_cells[spawn_cell] = true

		# Register occupancy and repair room membership explicitly after setup
		if map_manager:
			var grid_pos := map_manager.world_to_grid_coords(enemy.global_position)
			map_manager.update_actor_cell(enemy, grid_pos)
			if map_manager.core:
				map_manager.core.repair_actor_room(enemy)

		# Boss spawn rules: only one boss per run, must spawn in final room.
		if not boss_spawned and room_id == final_room_id:
			if selected_data and _is_boss_data(selected_data):
				boss_spawned = true
				boss_enemy = enemy
				enemy.name = "Boss_Purple_%d" % room_id

		# 🔥 TRACKING
		enemies.append(enemy)

		# 🔥 REGISTRO EN TURN MANAGER
		if turn_manager:
			turn_manager.register_actor(enemy)

		# mantener lógica existente
		var captured_player := player
		var captured_torch := player_torch

		enemy.ready.connect(func():
			enemy.player = captured_player
			enemy.player_torch = captured_torch
		, CONNECT_ONE_SHOT)

		_room_enemy_counts[room_id] = _room_enemy_counts.get(room_id, 0) + 1

		var captured_room_id := room_id
		enemy.enemy_defeated.connect(func(e):
			_on_enemy_defeated(e, captured_room_id)
		, CONNECT_ONE_SHOT)

func _select_enemy_data(room_id: int, p_final_room_id: int) -> EnemyData:
	if room_id == 0:
		var tutorial := _find_enemy_data_by_id("tutorial")
		if tutorial:
			return tutorial

	if room_id == p_final_room_id:
		var boss_candidates: Array[EnemyData] = []
		for data in enemy_data_pool:
			if data and data.is_boss:
				boss_candidates.append(data)
		if not boss_candidates.is_empty():
			return boss_candidates[randi() % boss_candidates.size()]

	var candidates: Array[EnemyData] = []
	for data in enemy_data_pool:
		if data == null:
			continue
		if _is_boss_data(data):
			continue
		if data.enemy_id == "tutorial":
			continue
		candidates.append(data)

	if not candidates.is_empty():
		return candidates[randi() % candidates.size()]

	if default_enemy_data:
		return default_enemy_data

	return _find_enemy_data_by_id("goblin")


func _find_enemy_data_by_id(enemy_id: String) -> EnemyData:
	for data in enemy_data_pool:
		if data and data.enemy_id == enemy_id:
			return data
	return null


func get_enemies() -> Array:
	return enemies


func get_enemies_in_room(room_id: int) -> int:
	return _room_enemy_counts.get(room_id, 0)


func _get_random_floor_cell_in_room(
	room_info: Dictionary,
	wall_cells: Dictionary,
	avoid_center: bool,
	player_cell: Vector2i,
	occupied_spawn_cells: Dictionary
) -> Vector2i:
	var room_cells: Array = room_info["floor_cells"]
	var center_cell: Vector2i = room_info["center_cell"]
	var forbidden_spawn_cells: Dictionary = {}
	if dungeon and dungeon.has_method("get_room_spawn_forbidden_cells"):
		forbidden_spawn_cells = dungeon.get_room_spawn_forbidden_cells(int(room_info.get("id", -1)))

	var candidates: Array[Vector2i] = []
	var avoid_radius: int = 1 if avoid_center else 0

	for raw_cell in room_cells:
		var cell: Vector2i = raw_cell

		if wall_cells.has(cell):
			continue
		if forbidden_spawn_cells.has(cell):
			continue
		if cell == player_cell:
			continue
		if occupied_spawn_cells.has(cell):
			continue

		if avoid_radius > 0:
			var dx: int = absi(cell.x - center_cell.x)
			var dy: int = absi(cell.y - center_cell.y)
			if dx <= avoid_radius and dy <= avoid_radius:
				continue

		var near_wall := false
		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if wall_cells.has(cell + dir):
				near_wall = true
				break

		if near_wall:
			continue

		candidates.append(cell)

	if candidates.is_empty():
		return Vector2i(-1, -1)

	return candidates[randi() % candidates.size()]


func _on_enemy_defeated(enemy, room_id: int) -> void:
	enemy_defeated_global.emit()

	var is_boss: bool = false
	if enemy and enemy.has_method("is_boss_enemy"):
		is_boss = enemy.is_boss_enemy()

	var reward_gold := COIN_REWARD_PER_ENEMY
	if enemy and enemy.has_method("get_reward_gold"):
		reward_gold = int(enemy.get_reward_gold())
	
	# DEFERRED GOLD: Accumulate reward internally instead of granting immediately
	# This prevents players from spending gold during combat and ensures
	# all rewards are granted atomically at run-end (victory or defeat screen)
	_run_accumulated_gold += max(0, reward_gold)
	print("[EnemyManager] Enemy defeated: +%dg (accumulated total: %dg)" % [reward_gold, _run_accumulated_gold])

	# Bosses: emit boss_defeated and grant gold, but DO NOT emit the reward signal
	if is_boss:
		boss_defeated.emit(enemy)
	else:
		var reward_position: Vector2 = enemy.global_position if enemy and enemy is Node2D else Vector2.ZERO
		enemy_defeated_with_reward.emit(enemy, reward_position)

	# 🔥 REMOVER DEL TURN MANAGER
	if turn_manager:
		turn_manager.unregister_actor(enemy)

	# 🔥 REMOVER DE LISTA
	enemies.erase(enemy)

	if not _room_enemy_counts.has(room_id):
		return

	_room_enemy_counts[room_id] -= 1

	if _room_enemy_counts[room_id] <= 0:
		_room_enemy_counts.erase(room_id)
		room_cleared.emit(room_id)


func grant_and_reset_accumulated_gold() -> int:
	# Grant all accumulated gold at run-end and return the amount granted
	# This is called by Main2d when victory or defeat screen appears
	if _run_accumulated_gold <= 0:
		return 0
	
	var currency := get_node_or_null("/root/CurrencyManager") as CurrencyManager
	if currency == null:
		push_warning("[EnemyManager] Cannot grant accumulated gold: CurrencyManager not found")
		var temp := _run_accumulated_gold
		_run_accumulated_gold = 0
		return temp
	
	var amount := _run_accumulated_gold
	currency.add_gold(amount, Vector2.ZERO)  # Grant without world position (bulk reward)
	print("[EnemyManager] Run ended: granted accumulated gold +%dg" % amount)
	_run_accumulated_gold = 0
	return amount

func _is_boss_data(data: EnemyData) -> bool:
	return data != null and data.is_boss

func _configure_enemy(
	enemy: Enemy,
	room_id: int,
	spawn_cell: Vector2i,
	selected_data: EnemyData,
	map_manager: MapManager
) -> void:

	enemy.global_position = dungeon.grid_to_world_coords(spawn_cell)
	enemy.my_room_id = room_id
	enemy.dungeon_generator = dungeon

	if selected_data:
		enemy.apply_enemy_data(selected_data)

		if selected_data.enemy_name != "":
			enemy.name = "%s_%d" % [selected_data.enemy_name, room_id]

	enemy.setup(map_manager, player)
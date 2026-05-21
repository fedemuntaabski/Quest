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

@export var default_enemy_data: EnemyData
@export var enemy_data_pool: Array[EnemyData] = []

var _enemy_scene: PackedScene = null
var _room_enemy_counts: Dictionary = {}

var dungeon: DungeonGenerator = null
var player: CharacterBody2D = null
var player_torch: PointLight2D = null

# 🔥 NUEVO
var enemies: Array = []
var turn_manager: TurnManager
var boss_spawned: bool = false
var boss_enemy: Node = null
var final_room_id: int = -1

const COIN_REWARD_PER_ENEMY := 5

# Deferred gold reward system: accumulate during run, grant at run-end
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

	if player:
		player_torch = player.get_node_or_null("PointLight2D") as PointLight2D

	if _enemy_scene == null:
		_enemy_scene = load(ENEMY_SCENE_PATH) as PackedScene


func spawn_enemies(room_infos: Array, wall_cells: Dictionary) -> void:
	if _enemy_scene == null:
		push_error("EnemyManager: Enemy scene not loaded.")
		return

	_room_enemy_counts.clear()
	enemies.clear() # 🔥 importante
	_run_accumulated_gold = 0  # Reset accumulated gold for new run
	boss_spawned = false
	boss_enemy = null

	var map_manager := get_parent() as MapManager
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
		enemy.global_position = dungeon.grid_to_world_coords(spawn_cell)
		enemy.my_room_id = room_id
		enemy.dungeon_generator = dungeon
		var selected_data := _select_enemy_data(room_id, final_room_id)
		if selected_data and enemy.has_method("apply_enemy_data"):
			enemy.apply_enemy_data(selected_data)
			if selected_data.enemy_name != "":
				enemy.name = "%s_%d" % [selected_data.enemy_name, room_id]
		add_child(enemy)
		occupied_spawn_cells[spawn_cell] = true

		# Register every enemy through the same setup path after it is inside the scene tree.
		enemy.setup(get_parent(), player)

		# Register occupancy and repair room membership explicitly after setup
		if map_manager:
			var grid_pos := map_manager.world_to_grid_coords(enemy.global_position)
			map_manager.update_actor_cell(enemy, grid_pos)
			if map_manager.core:
				map_manager.core.repair_actor_room(enemy)

		# Boss spawn rules: only one boss per run, must spawn in final room.
		if not boss_spawned and room_id == final_room_id:
			if selected_data and selected_data.is_boss:
				boss_spawned = true
				boss_enemy = enemy
				enemy.name = "Boss_Purple_%d" % room_id
				enemy.set("is_boss", true)
			else:
				enemy.set("is_boss", false)
		elif selected_data and selected_data.is_boss:
			enemy.set("is_boss", true)
		else:
			enemy.set("is_boss", false)

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
	return EnemyDataSelector.select_enemy_data(room_id, p_final_room_id, enemy_data_pool, default_enemy_data)


func _find_enemy_data_by_id(enemy_id: String) -> EnemyData:
	return EnemyDataSelector.find_enemy_data_by_id(enemy_data_pool, enemy_id)


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
	return EnemySpawnPlanner.get_random_floor_cell_in_room(
		room_info,
		wall_cells,
		avoid_center,
		player_cell,
		occupied_spawn_cells,
		dungeon
	)


func _on_enemy_defeated(enemy, room_id: int) -> void:
	EnemyRewardService.process_enemy_defeat(self, enemy, room_id)


func grant_and_reset_accumulated_gold() -> int:
	# Grant all accumulated gold at run-end and return the amount granted.
	# This is called by Main2d when victory or defeat screen appears.
	return EnemyRewardService.grant_and_reset_accumulated_gold(self)

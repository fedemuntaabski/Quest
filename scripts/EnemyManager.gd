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

func _select_enemy_data(room_id: int, final_room_id: int) -> EnemyData:
	if room_id == 0:
		var tutorial := _find_enemy_data_by_id("tutorial")
		if tutorial:
			return tutorial

	if room_id == final_room_id:
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
		if data.is_boss:
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
	if enemy:
		is_boss = enemy.get("is_boss") == true

	var currency := get_node_or_null("/root/CurrencyManager") as CurrencyManager
	var reward_gold := COIN_REWARD_PER_ENEMY
	if enemy and enemy.has_method("get_reward_gold"):
		reward_gold = int(enemy.get_reward_gold())
	if currency and enemy and enemy is Node2D:
		# Always add gold on death; boss victory snapshots must see the finalized total.
		currency.add_gold(reward_gold, enemy.global_position)

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

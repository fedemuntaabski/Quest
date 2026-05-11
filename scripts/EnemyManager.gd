extends Node2D
class_name EnemyManager

signal room_cleared(room_id: int)
signal enemy_defeated_global

const ENEMY_SCENE_PATH := "res://scenes/Enemy.tscn"

var _enemy_scene: PackedScene = null
var _room_enemy_counts: Dictionary = {}

var dungeon: DungeonGenerator = null
var player: CharacterBody2D = null
var player_torch: PointLight2D = null

# 🔥 NUEVO
var enemies: Array = []
var turn_manager: TurnManager

const COIN_REWARD_PER_ENEMY := 5


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

	for room_info in room_infos:
		var room_id: int = room_info["id"]

		var spawn_cell := _get_random_floor_cell_in_room(
			room_info,
			wall_cells,
			room_id == 0
		)

		if spawn_cell == Vector2i(-1, -1):
			continue

		var enemy := _enemy_scene.instantiate()
		if enemy == null:
			continue

		enemy.name = "Enemy_%d" % room_id
		enemy.position = dungeon.grid_to_world_coords(spawn_cell)
		enemy.my_room_id = room_id
		enemy.dungeon_generator = dungeon

		# 🔥 SETUP COMPLETO (CLAVE)
		enemy.setup(get_parent(), player)

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

		add_child(enemy)


func get_enemies() -> Array:
	return enemies


func get_enemies_in_room(room_id: int) -> int:
	return _room_enemy_counts.get(room_id, 0)


func _get_random_floor_cell_in_room(room_info: Dictionary, wall_cells: Dictionary, avoid_center: bool) -> Vector2i:
	var room_cells: Array = room_info["floor_cells"]
	var center_cell: Vector2i = room_info["center_cell"]

	var candidates: Array[Vector2i] = []
	var avoid_radius: int = 1 if avoid_center else 0

	for raw_cell in room_cells:
		var cell: Vector2i = raw_cell

		if wall_cells.has(cell):
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
		for raw_cell in room_cells:
			var cell: Vector2i = raw_cell
			if not wall_cells.has(cell):
				candidates.append(cell)

	if candidates.is_empty():
		return Vector2i(-1, -1)

	return candidates[randi() % candidates.size()]


func _on_enemy_defeated(enemy, room_id: int) -> void:
	enemy_defeated_global.emit()
	var currency := get_node_or_null("/root/CurrencyManager") as CurrencyManager
	if currency and enemy and enemy is Node2D:
		currency.add_gold(COIN_REWARD_PER_ENEMY, enemy.global_position)

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

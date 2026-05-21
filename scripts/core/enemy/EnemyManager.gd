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
	EnemySpawnLifecycleService.spawn_enemies(self, room_infos, wall_cells)

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


func _set_enemy_boss_flag(enemy: Node, value: bool) -> void:
	if enemy is Enemy:
		(enemy as Enemy).is_boss = value
		return
	enemy.set("is_boss", value)


func grant_and_reset_accumulated_gold() -> int:
	# Grant all accumulated gold at run-end and return the amount granted.
	# This is called by Main2d when victory or defeat screen appears.
	return EnemyRewardService.grant_and_reset_accumulated_gold(self)

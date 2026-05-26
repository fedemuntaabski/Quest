extends Node2D
class_name EnemyManager

signal room_cleared(room_id: int)
signal enemy_defeated_global
signal enemy_defeated_with_reward(enemy, reward_position: Vector2)
signal boss_defeated(enemy)

# 🌟 MODIFICADO: Eliminamos la constante fija y las referencias ahora se manejan dinámicamente
const TUTORIAL_ENEMY_DATA = preload("res://resources/enemies/tutorial.tres")
const SKELETON_ENEMY_DATA = preload("res://resources/enemies/skeleton.tres")
const BOSS_ENEMY_DATA = preload("res://resources/enemies/boss.tres")

@export var default_enemy_data: EnemyData
@export var enemy_data_pool: Array[EnemyData] = []

# 🌟 MODIFICADO: Ya no pre-cargamos una escena única al inicio
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
		default_enemy_data = SKELETON_ENEMY_DATA

	if enemy_data_pool.is_empty():
		enemy_data_pool = [
			TUTORIAL_ENEMY_DATA,
			SKELETON_ENEMY_DATA,
			BOSS_ENEMY_DATA,
		]


func setup(dungeon_ref: DungeonGenerator, player_ref: CharacterBody2D, tm: TurnManager) -> void:
	dungeon = dungeon_ref
	player = player_ref
	turn_manager = tm

	if player:
		player_torch = player.get_node_or_null("PointLight2D") as PointLight2D


func spawn_enemies(room_infos: Array, wall_cells: Dictionary) -> void:
	# Pasamos el control al servicio del ciclo de vida
	EnemySpawnLifecycleService.spawn_enemies(self, room_infos, wall_cells)


# 🌟 NUEVO MÉTODO DINÁMICO:
# Este método intercepta la petición de instanciación del 'EnemySpawnLifecycleService'.
# En lugar de devolver siempre 'Enemy.tscn', busca qué datos corresponden a la sala
# y devuelve la escena específica guardada en su .tres (BossEnemy.tscn, SkeletonEnemy.tscn, etc.)
func get_enemy_scene_for_room(room_id: int) -> PackedScene:
	var chosen_data: EnemyData = _select_enemy_data(room_id, final_room_id)
	
	if chosen_data and chosen_data.enemy_scene:
		return chosen_data.enemy_scene
		
	# Resguardo de emergencia por si olvidaste asignar la escena en algún recurso .tres
	push_warning("[EnemyManager] El EnemyData asignado no tiene una escena seteada. Usando fallback.")
	if default_enemy_data and default_enemy_data.enemy_scene:
		return default_enemy_data.enemy_scene
		
	return load("res://scenes/Enemy.tscn") as PackedScene


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
	return EnemyRewardService.grant_and_reset_accumulated_gold(self)

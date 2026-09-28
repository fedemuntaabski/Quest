extends Node
class_name FloorManager

## FloorManager: per-floor facade over FloorConfig. Scene-instantiated per
## Main2d (group "floor_manager"), like EnemyManager/ExtractionManager — so it
## does NOT own the run's floor counter: that survives Main2d reloads on the
## Main orchestrator (Main.current_floor), which passes it in via setup().
## Systems read their scaled numbers from here; nothing else touches FloorConfig.

signal floor_completed(floor_index: int)

const DEFAULT_CONFIG: FloorConfig = preload("res://resources/floors/default_floor_config.tres")

@export var config: FloorConfig = DEFAULT_CONFIG

var floor_index: int = 1
## Deterministic MapGenerator seed for this floor (run seed + floor index).
var map_seed: int = 0
var _completed: bool = false


func _ready() -> void:
	add_to_group("floor_manager")


func setup(p_floor_index: int, run_seed: int = 0) -> void:
	floor_index = maxi(p_floor_index, 1)
	map_seed = hash([run_seed, floor_index])
	if floor_index > 1 and config.dust_bonus_on_descend > 0:
		var resource_manager := ManagerLocator.get_resource_manager()
		if resource_manager:
			resource_manager.add_resource("dust", config.dust_bonus_on_descend)
	QuestLogger.info(QuestLogger.Category.MAP, "Floor %d/%d started (enemy HP x%.2f, dmg x%.2f)." % [floor_index, config.max_floors, enemy_hp_multiplier(), enemy_damage_multiplier()])


## Called once when this floor's exit is reached (ExtractionManager.victory_declared).
func complete_floor() -> void:
	if _completed:
		return
	_completed = true
	QuestLogger.info(QuestLogger.Category.MAP, "Floor %d completed." % floor_index)
	floor_completed.emit(floor_index)


## DoorTurnSystem.room_revealed listener: every discovered room pays dust,
## regardless of invasions. Amount scales per floor (FloorConfig "Discovery").
func on_room_discovered(room_id: String, _cells: Array[Vector2i]) -> void:
	var amount := config.discovery_dust(floor_index)
	var resource_manager := ManagerLocator.get_resource_manager()
	if resource_manager == null or amount <= 0:
		return
	resource_manager.add_resource("dust", amount)
	QuestLogger.info(QuestLogger.Category.MAP, "Discovered '%s': +%d dust." % [room_id, amount])


func room_count() -> int:
	return config.room_count(floor_index)


func branch_chance() -> float:
	return config.branch_chance(floor_index)


func is_final_floor() -> bool:
	return floor_index >= config.max_floors


func enemy_hp_multiplier() -> float:
	return config.enemy_hp_multiplier(floor_index)


func enemy_damage_multiplier() -> float:
	return config.enemy_damage_multiplier(floor_index)


func invasion_chance_bonus() -> float:
	return config.invasion_chance_bonus(floor_index)


func extra_invasion_enemies() -> int:
	return config.extra_invasion_enemies(floor_index)


func extraction_interval() -> float:
	return config.extraction_interval(floor_index)

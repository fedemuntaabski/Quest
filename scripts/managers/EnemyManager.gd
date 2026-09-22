extends Node
class_name EnemyManager

## EnemyManager: spawns/tracks Enemy instances. Scene-instantiated per
## Main2d (per-run state), not an autoload — same reasoning as DoorTurnSystem.

const ENEMY_SCENE := preload("res://scenes/entities/Enemy.tscn")
const VARIANT_WEIGHTS := {
	Enemy.Variant.SWARM: 60,
	Enemy.Variant.SAPPER: 25,
	Enemy.Variant.HUNTER: 15,
}

var room_manager: RoomManager
var _enemies: Array[Enemy] = []


func _ready() -> void:
	add_to_group("enemy_manager")


func setup(p_room_manager: RoomManager) -> void:
	room_manager = p_room_manager


func spawn_enemies_in_room(group_id: String, count: int) -> void:
	if room_manager == null:
		return
	var zone_ids := room_manager.get_group_zone_ids(group_id)
	if zone_ids.is_empty():
		return
	var room_zone_id: String = zone_ids[-1]

	for i in range(count):
		var enemy := ENEMY_SCENE.instantiate() as Enemy
		add_child(enemy)
		enemy.global_position = room_manager.get_center(room_zone_id)
		enemy.configure(_roll_variant(), room_zone_id)
		enemy.died.connect(_on_enemy_died)
		_enemies.append(enemy)

	QuestLogger.info(QuestLogger.Category.ENEMY, "Spawned %d enemies in room '%s'." % [count, room_zone_id])


func get_enemies_in_room(group_id: String) -> Array[Enemy]:
	var result: Array[Enemy] = []
	if room_manager == null:
		return result
	for enemy in _enemies:
		if room_manager.get_group_id(enemy.current_zone_id) == group_id:
			result.append(enemy)
	return result


func _roll_variant() -> Enemy.Variant:
	var total := 0
	for weight in VARIANT_WEIGHTS.values():
		total += weight
	var roll := randi() % total
	var cumulative := 0
	for variant in VARIANT_WEIGHTS.keys():
		cumulative += VARIANT_WEIGHTS[variant]
		if roll < cumulative:
			return variant
	return Enemy.Variant.SWARM


func _on_enemy_died(enemy: Enemy) -> void:
	_enemies.erase(enemy)

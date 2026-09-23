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

## Risk engine: P(spawn) = clamp(BASE + dark_rooms*PER_DARK + turn*PER_TURN).
const BASE_CHANCE := 0.05
const CHANCE_PER_DARK_ROOM := 0.08
const CHANCE_PER_TURN := 0.015
const MAX_CHANCE := 0.85
const TURNS_PER_WAVE_STEP := 5.0

signal invasion_triggered(spawn_rooms: Array[RoomZone], enemy_count: int)

var room_manager: RoomManager
var door_turn_system: DoorTurnSystem
var _enemies: Array[Enemy] = []
var _enemies_root: Node2D


func _ready() -> void:
	add_to_group("enemy_manager")
	_enemies_root = Node2D.new()
	_enemies_root.name = "Enemies"
	add_child(_enemies_root)
	invasion_triggered.connect(_on_invasion_triggered)


func setup(p_room_manager: RoomManager, p_door_turn_system: DoorTurnSystem = null) -> void:
	room_manager = p_room_manager
	door_turn_system = p_door_turn_system
	if door_turn_system and not door_turn_system.turn_advanced.is_connected(_on_turn_advanced):
		door_turn_system.turn_advanced.connect(_on_turn_advanced)


func _on_turn_advanced(current_turn: int) -> void:
	if room_manager == null:
		return
	var dark_rooms: Array[RoomZone] = room_manager.get_dark_rooms()
	if dark_rooms.is_empty():
		return

	var spawn_chance: float = minf(MAX_CHANCE, BASE_CHANCE + (dark_rooms.size() * CHANCE_PER_DARK_ROOM) + (current_turn * CHANCE_PER_TURN))
	var enemy_count: int = 1 + int(floor(current_turn / TURNS_PER_WAVE_STEP))
	var roll: float = randf()
	if roll > spawn_chance:
		QuestLogger.info(QuestLogger.Category.ENEMY, "Turn %d: no invasion (chance %.1f%%, roll %.3f)." % [current_turn, spawn_chance * 100.0, roll])
		return

	dark_rooms.shuffle()
	var selected_spawns: Array[RoomZone] = []
	for i in range(mini(enemy_count, dark_rooms.size())):
		selected_spawns.append(dark_rooms[i])

	var names: Array[String] = []
	for room in selected_spawns:
		names.append(room.zone_id)
	QuestLogger.info(QuestLogger.Category.ENEMY, "Turn %d: INVASION (chance %.1f%%, roll %.3f, count %d, rooms %s)." % [current_turn, spawn_chance * 100.0, roll, enemy_count, names])
	invasion_triggered.emit(selected_spawns, enemy_count)


func _on_invasion_triggered(spawn_rooms: Array[RoomZone], enemy_count: int) -> void:
	if spawn_rooms.is_empty():
		return
	for i in range(enemy_count):
		var room := spawn_rooms.pick_random() as RoomZone
		QuestLogger.info(QuestLogger.Category.ENEMY, "INVASIÓN: Spawneando enemigo en la sala %s" % room.room_id)
		_spawn_enemy(room.zone_id, room.center_position)


func _spawn_enemy(zone_id: String, world_position: Vector2) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	_enemies_root.add_child(enemy)
	enemy.setup(world_position)
	enemy.configure(_roll_variant(), zone_id)
	enemy.died.connect(_on_enemy_died)
	_enemies.append(enemy)
	return enemy


func spawn_enemies_in_room(group_id: String, count: int) -> void:
	if room_manager == null:
		return
	var zone_ids := room_manager.get_group_zone_ids(group_id)
	if zone_ids.is_empty():
		return
	var room_zone_id: String = zone_ids[-1]

	for i in range(count):
		_spawn_enemy(room_zone_id, room_manager.get_center(room_zone_id))

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

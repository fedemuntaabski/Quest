extends Node
class_name EnemyManager

## EnemyManager: spawns/tracks Enemy instances. Scene-instantiated per
## Main2d (per-run state), not an autoload — same reasoning as DoorTurnSystem.

const ENEMY_SCENE := preload("res://scenes/entities/Enemy.tscn")
## Used when there is no FloorManager / no pool (standalone scenes, tests).
const FALLBACK_TYPE: EnemyType = preload("res://resources/enemies/goblin.tres")

signal invasion_triggered(spawn_rooms: Array[RoomZone], enemy_count: int)
## Telegraph: enemies just spawned in these zones (source = "door" | "wave"). HUD
## text/sound and the minimap alert listen to this, not to invasion_triggered.
signal enemies_appeared(zone_ids: Array[String], count: int, source: String)
## Every spawned Enemy (the bestiary counts the first one as "seen").
signal enemy_spawned(enemy: Enemy)

var room_manager: RoomManager
var door_turn_system: DoorTurnSystem
## Optional: null = floor-1 baseline (no scaling).
var floor_manager: FloorManager
var _enemies: Array[Enemy] = []
var _enemies_root: Node2D
var _spawn_count: int = 0


func _ready() -> void:
	add_to_group("enemy_manager")
	_enemies_root = Node2D.new()
	_enemies_root.name = "Enemies"
	add_child(_enemies_root)
	invasion_triggered.connect(_on_invasion_triggered)
	enemy_spawned.connect(_on_enemy_spawned)


func _process(delta: float) -> void:
	Enemy.game_time_msec += delta * 1000.0


func setup(p_room_manager: RoomManager, p_door_turn_system: DoorTurnSystem = null, p_floor_manager: FloorManager = null) -> void:
	room_manager = p_room_manager
	door_turn_system = p_door_turn_system
	floor_manager = p_floor_manager
	if door_turn_system and not door_turn_system.turn_advanced.is_connected(_on_turn_advanced):
		door_turn_system.turn_advanced.connect(_on_turn_advanced)


## Dark rooms enemies may spawn in: RoomManager.get_dark_rooms() minus room
## types whose RoomTypeRule blocks spawns (Rest). Lit or not is the only
## power check, and it lives in get_dark_rooms().
func get_spawn_rooms() -> Array[RoomZone]:
	var rooms: Array[RoomZone] = []
	for room in room_manager.get_dark_rooms():
		if not _spawns_blocked(room.zone_id):
			rooms.append(room)
	return rooms


func _room_rule(zone_id: String) -> RoomTypeRule:
	return floor_manager.room_type_rule(room_manager.get_room_type(zone_id)) if floor_manager else null


func _spawns_blocked(zone_id: String) -> bool:
	var rule := _room_rule(zone_id)
	return rule != null and rule.blocks_spawns


## Door threat (DoorRollConfig): `current_turn` is the count of doors opened on this
## floor (the turn only moves when a door opens), so the chance grows door by door.
func _on_turn_advanced(current_turn: int) -> void:
	if room_manager == null:
		return
	var dark_rooms: Array[RoomZone] = get_spawn_rooms()
	if dark_rooms.is_empty():
		return

	var door_roll := _door_roll()
	var spawn_chance: float = door_roll.threat_chance(current_turn, _floor_index())
	var enemy_count: int = door_roll.enemy_count(current_turn, _floor_index())
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
	var zones: Array[String] = []
	for i in range(enemy_count):
		var room := spawn_rooms.pick_random() as RoomZone
		QuestLogger.info(QuestLogger.Category.ENEMY, "INVASIÓN: Spawneando enemigo en la sala %s" % room.room_id)
		if _spawn_enemy(room.zone_id, room.center_position) and not zones.has(room.zone_id):
			zones.append(room.zone_id)
	if not zones.is_empty():
		enemies_appeared.emit(zones, enemy_count, "door")


## Extraction wave: `count` enemies, each in a random dark room (rooms may repeat);
## stops at the floor's cap. Returns how many spawned.
func spawn_wave(count: int) -> int:
	if room_manager == null:
		return 0
	var rooms := get_spawn_rooms()
	if rooms.is_empty():
		return 0
	var zones: Array[String] = []
	var spawned := 0
	for i in range(count):
		var room := rooms.pick_random() as RoomZone
		if _spawn_enemy(room.zone_id, room.center_position) == null:
			break
		spawned += 1
		if not zones.has(room.zone_id):
			zones.append(room.zone_id)
	if spawned > 0:
		enemies_appeared.emit(zones, spawned, "wave")
	return spawned


## Enemies alive now (freed ones are pruned).
func alive_count() -> int:
	var alive: Array[Enemy] = []
	for enemy in _enemies:
		if is_instance_valid(enemy):
			alive.append(enemy)
	_enemies = alive
	return alive.size()


func _door_roll() -> DoorRollConfig:
	return floor_manager.config.door_roll if floor_manager else FloorManager.DEFAULT_CONFIG.door_roll


## Null when the floor's simultaneous cap is reached.
func _spawn_enemy(zone_id: String, world_position: Vector2) -> Enemy:
	if floor_manager and alive_count() >= floor_manager.max_enemies():
		QuestLogger.info(QuestLogger.Category.ENEMY, "Spawn refused: cap of %d enemies reached." % floor_manager.max_enemies())
		return null
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	_enemies_root.add_child(enemy)
	enemy.setup(world_position)
	enemy.slot = _spawn_count
	_spawn_count += 1
	var hp_mult: float = floor_manager.enemy_hp_multiplier() if floor_manager else 1.0
	var dmg_mult: float = floor_manager.enemy_damage_multiplier() if floor_manager else 1.0
	var rule := _room_rule(zone_id)  # Elite rooms: tougher enemies
	if rule:
		hp_mult *= rule.enemy_hp_mult
		dmg_mult *= rule.enemy_damage_mult
	var type := _roll_type(zone_id)
	enemy.configure(Enemy.Variant.SWARM, zone_id, hp_mult, dmg_mult, type)
	enemy.died.connect(_on_enemy_died)
	_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	return enemy


## Role by the floor's ratio, then a type of that role. A raider that could
## reach the Nexo sooner than raider_min_arrival_sec from here is swapped for a hunter.
func _roll_type(zone_id: String) -> EnemyType:
	if floor_manager == null:
		return FALLBACK_TYPE
	var role := floor_manager.roll_role()
	var type := floor_manager.roll_enemy_type(role)
	if type == null:
		return FALLBACK_TYPE
	if type.role == EnemyType.Role.RAIDER and raider_arrival_sec(zone_id, type) < floor_manager.config.raider_min_arrival_sec:
		type = floor_manager.roll_enemy_type(EnemyType.Role.HUNTER)
	return type if type else FALLBACK_TYPE


## Seconds a `type` raider spawned in `zone_id` needs to reach the Nexo (INF = unreachable).
func raider_arrival_sec(zone_id: String, type: EnemyType) -> float:
	var nexo := ManagerLocator.get_nexo()
	if nexo == null or room_manager == null:
		return INF
	var path := room_manager.find_zone_path(zone_id, nexo.get_target_zone(room_manager))
	if path.is_empty():
		return INF
	var length := 0.0
	for i in range(1, path.size()):
		length += room_manager.get_center(path[i - 1]).distance_to(room_manager.get_center(path[i]))
	return length / (Enemy.resolved_speed(type) * type.speed_mult)


func spawn_enemies_in_room(group_id: String, count: int) -> void:
	if room_manager == null:
		return
	var room_zone_id := room_manager.get_room_zone_id_in_group(group_id)
	if room_zone_id == "" or _spawns_blocked(room_zone_id):
		return

	for i in range(count):
		_spawn_enemy(room_zone_id, room_manager.get_center(room_zone_id))

	QuestLogger.info(QuestLogger.Category.ENEMY, "Spawned %d enemies in room '%s'." % [count, room_zone_id])


func _floor_index() -> int:
	return floor_manager.floor_index if floor_manager else 1


func _on_enemy_spawned(enemy: Enemy) -> void:
	var bestiary := ManagerLocator.get_bestiary()
	if bestiary and enemy.type:
		bestiary.register_seen(enemy.type, _floor_index())


## `died` is only emitted for deaths by damage (hero or turret): those are kills.
func _on_enemy_died(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	var bestiary := ManagerLocator.get_bestiary()
	if bestiary and enemy.killed_by_damage and enemy.type:
		bestiary.register_kill(enemy.type, _floor_index())

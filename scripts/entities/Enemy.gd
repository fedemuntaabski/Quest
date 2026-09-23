extends Node2D
class_name Enemy

## Enemy: minimal DotE-style enemy. No real pathfinding — an AiTimer re-
## evaluates a target zone periodically and glides the whole revealed-only
## path there via EnemyMoveAction (same graph RoomManager/PlayerActionController
## already use). Owns a tiny self-contained HP block mirroring
## CharacterStats.take_damage's clamp/signal shape.

enum Variant { SWARM, SAPPER, HUNTER }

const VARIANT_CONFIG := {
	Variant.SWARM: {"hp": 6, "speed": 500.0, "ai_interval": 1.2},
	Variant.SAPPER: {"hp": 10, "speed": 380.0, "damage_per_tick": 3, "ai_interval": 2.0},
	Variant.HUNTER: {"hp": 8, "speed": 400.0, "ai_interval": 1.2},
}

const TYPE_COLORS := {
	Variant.SWARM: Color(0.85, 0.25, 0.25, 1.0),
	Variant.SAPPER: Color(0.55, 0.4, 0.2, 1.0),
	Variant.HUNTER: Color(0.3, 0.1, 0.5, 1.0),
}

signal died(enemy: Enemy)

@onready var icon: Polygon2D = $Icon
@onready var ai_timer: Timer = $AiTimer

var variant: Variant
var current_zone_id: String = ""
var max_hp: int = 0
var current_hp: int = 0
var _slowed_until_msec: int = 0
var _moving: bool = false


func configure(p_variant: Variant, p_zone_id: String) -> void:
	variant = p_variant
	current_zone_id = p_zone_id

	var cfg: Dictionary = VARIANT_CONFIG[variant]
	max_hp = int(cfg["hp"])
	current_hp = max_hp

	if icon:
		icon.color = TYPE_COLORS.get(variant, Color.WHITE)

	ai_timer.wait_time = float(cfg.get("ai_interval", 1.5))
	ai_timer.one_shot = false
	ai_timer.timeout.connect(_on_ai_tick)
	ai_timer.start()


func take_damage(amount: int) -> void:
	if not is_alive():
		return
	current_hp = maxi(current_hp - maxi(amount, 0), 0)
	if current_hp <= 0:
		QuestLogger.info(QuestLogger.Category.ENEMY, "Enemy '%s' died in zone '%s'." % [Variant.keys()[variant], current_zone_id])
		died.emit(self)
		queue_free()


func is_alive() -> bool:
	return current_hp > 0


func apply_slow(duration: float) -> void:
	_slowed_until_msec = Time.get_ticks_msec() + int(duration * 1000)


func current_speed() -> float:
	var cfg: Dictionary = VARIANT_CONFIG[variant]
	var base_speed := float(cfg["speed"])
	return base_speed * 0.5 if Time.get_ticks_msec() < _slowed_until_msec else base_speed


func _on_ai_tick() -> void:
	if _moving or not is_alive():
		return
	var room_manager := ManagerLocator.get_room_manager()
	if room_manager == null:
		return

	match variant:
		Variant.SWARM:
			await _pursue_zone(room_manager, _player_zone())
		Variant.SAPPER:
			await _sapper_tick(room_manager)
		Variant.HUNTER:
			var player := ManagerLocator.get_player()
			if player and player.is_carrying_nexo:
				await _pursue_zone(room_manager, player.current_zone_id)


func _player_zone() -> String:
	var player := ManagerLocator.get_player()
	return player.current_zone_id if player else ""


func _sapper_tick(room_manager: RoomManager) -> void:
	var group_id := room_manager.get_group_id(current_zone_id)
	var modules := room_manager.get_modules_in_group(group_id)
	if not modules.is_empty():
		var cfg: Dictionary = VARIANT_CONFIG[Variant.SAPPER]
		modules[0].take_damage(int(cfg["damage_per_tick"]))
		return

	var target_zone := _find_zone_with_modules(room_manager)
	if target_zone == "":
		target_zone = _player_zone()
	await _pursue_zone(room_manager, target_zone)


func _find_zone_with_modules(room_manager: RoomManager) -> String:
	for zone_id in room_manager.zones.keys():
		if room_manager.zones[zone_id]["kind"] != "room":
			continue
		if not room_manager.is_zone_revealed(zone_id):
			continue
		var group_id := room_manager.get_group_id(zone_id)
		if not room_manager.get_modules_in_group(group_id).is_empty():
			return zone_id
	return ""


func _pursue_zone(room_manager: RoomManager, target_zone_id: String) -> void:
	if target_zone_id == "" or target_zone_id == current_zone_id:
		return
	var path := room_manager.find_zone_path(current_zone_id, target_zone_id)
	if path.size() < 2:
		return

	var waypoints: Array[Vector2] = []
	for step_id in path.slice(1):
		waypoints.append(room_manager.get_center(step_id))

	_moving = true
	var action := EnemyMoveAction.new(self, waypoints, path[-1])
	await action.execute()
	_moving = false

	_check_trap_in_current_room(room_manager)


func _check_trap_in_current_room(room_manager: RoomManager) -> void:
	var group_id := room_manager.get_group_id(current_zone_id)
	for module in room_manager.get_modules_in_group(group_id):
		if module.is_trap():
			var cfg: Dictionary = Module.CATALOG[Module.ModuleType.TRAP]
			apply_slow(float(cfg["slow_duration"]))
			break

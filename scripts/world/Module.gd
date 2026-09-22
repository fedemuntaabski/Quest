extends Node2D
class_name Module

## Module: buildable room upgrade. Major (Generator) modules feed resource
## bonuses into ResourceManager on door-open (see DoorTurnSystem.open_room).
## Minor (Turret/Trap) modules are the room's defenses against enemies.
## Owns a tiny self-contained HP block mirroring CharacterStats.take_damage's
## clamp/signal shape — not a shared base class, per codebase convention.

enum SlotType { MAJOR, MINOR }
enum ModuleType { GENERATOR, TURRET, TRAP }

const CATALOG := {
	ModuleType.GENERATOR: {"label": "Generador", "slot": SlotType.MAJOR, "cost": 6, "industry": 3, "food": 3, "science": 2},
	ModuleType.TURRET: {"label": "Ballesta", "slot": SlotType.MINOR, "cost": 4, "damage_per_tick": 2, "tick_interval": 1.5},
	ModuleType.TRAP: {"label": "Trampa", "slot": SlotType.MINOR, "cost": 3, "slow_factor": 0.5, "slow_duration": 3.0},
}

const TYPE_COLORS := {
	ModuleType.GENERATOR: Color(0.95, 0.78, 0.42, 1.0),
	ModuleType.TURRET: Color(0.55, 0.65, 0.85, 1.0),
	ModuleType.TRAP: Color(0.8, 0.3, 0.3, 1.0),
}

signal destroyed(module: Module)

@onready var icon: Polygon2D = $Icon
@onready var tick_timer: Timer = $TickTimer

var module_type: ModuleType
var zone_id: String = ""
var max_hp: int = 15
var current_hp: int = 15
var _is_destroyed: bool = false


func configure(p_zone_id: String, p_module_type: ModuleType) -> void:
	zone_id = p_zone_id
	module_type = p_module_type
	max_hp = 15
	current_hp = max_hp

	if icon:
		icon.color = TYPE_COLORS.get(module_type, Color.WHITE)

	if is_turret():
		var cfg: Dictionary = CATALOG[ModuleType.TURRET]
		tick_timer.wait_time = float(cfg["tick_interval"])
		tick_timer.one_shot = false
		tick_timer.timeout.connect(_on_turret_tick)
		tick_timer.start()

	QuestLogger.info(QuestLogger.Category.MODULE, "Module '%s' built in zone '%s'." % [ModuleType.keys()[module_type], zone_id])


func take_damage(amount: int) -> void:
	if _is_destroyed:
		return
	current_hp = maxi(current_hp - maxi(amount, 0), 0)
	if current_hp <= 0:
		_is_destroyed = true
		QuestLogger.info(QuestLogger.Category.MODULE, "Module '%s' in zone '%s' destroyed." % [ModuleType.keys()[module_type], zone_id])
		destroyed.emit(self)
		queue_free()


func is_generator() -> bool:
	return module_type == ModuleType.GENERATOR


func is_turret() -> bool:
	return module_type == ModuleType.TURRET


func is_trap() -> bool:
	return module_type == ModuleType.TRAP


func _on_turret_tick() -> void:
	if _is_destroyed:
		return
	var enemy_manager := ManagerLocator.get_enemy_manager()
	var room_manager := ManagerLocator.get_room_manager()
	if enemy_manager == null or room_manager == null:
		return
	var group_id := room_manager.get_group_id(zone_id)
	var enemies: Array = enemy_manager.get_enemies_in_room(group_id)
	if enemies.is_empty():
		return
	var cfg: Dictionary = CATALOG[ModuleType.TURRET]
	var target: Enemy = enemies[0]
	target.take_damage(int(cfg["damage_per_tick"]))

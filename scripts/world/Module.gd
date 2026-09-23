extends Node2D
class_name Module

## Module: buildable room upgrade. Major (Generator) modules feed resource
## bonuses into ResourceManager on door-open (see DoorTurnSystem.open_room).
## Minor (Turret/Trap) modules are the room's defenses against enemies.
## Owns a tiny self-contained HP block mirroring CharacterStats.take_damage's
## clamp/signal shape — not a shared base class, per codebase convention.

enum SlotType { MAJOR, MINOR }
enum ModuleType { GENERATOR_INDUSTRY, GENERATOR_FOOD, GENERATOR_SCIENCE, TURRET, TRAP }

const MODULE_SCENE_PATH := "res://scenes/world/Module.tscn"
const GENERATOR_SCENE_PATH := "res://scenes/world/GeneratorModule.tscn"
const TURRET_SCENE_PATH := "res://scenes/world/TurretModule.tscn"

const CATALOG := {
	ModuleType.GENERATOR_INDUSTRY: {"hp": 15, "label": "Gen. Industria", "slot": SlotType.MAJOR, "cost": 6, "industry": 3, "food": 0, "science": 0, "scene": GENERATOR_SCENE_PATH},
	ModuleType.GENERATOR_FOOD: {"hp": 15, "label": "Gen. Comida", "slot": SlotType.MAJOR, "cost": 6, "industry": 0, "food": 3, "science": 0, "scene": GENERATOR_SCENE_PATH},
	ModuleType.GENERATOR_SCIENCE: {"hp": 15, "label": "Gen. Ciencia", "slot": SlotType.MAJOR, "cost": 6, "industry": 0, "food": 0, "science": 3, "scene": GENERATOR_SCENE_PATH},
	ModuleType.TURRET: {"hp": 15, "label": "Ballesta", "slot": SlotType.MINOR, "cost": 4, "damage": 15, "fire_rate": 1.0, "scene": TURRET_SCENE_PATH},
	ModuleType.TRAP: {"hp": 15, "label": "Trampa", "slot": SlotType.MINOR, "cost": 3, "slow_factor": 0.5, "slow_duration": 3.0, "scene": MODULE_SCENE_PATH},
}

const TYPE_COLORS := {
	ModuleType.GENERATOR_INDUSTRY: Color(0.72, 0.74, 0.8, 1.0),
	ModuleType.GENERATOR_FOOD: Color(0.85, 0.4, 0.4, 1.0),
	ModuleType.GENERATOR_SCIENCE: Color(0.6, 0.45, 0.85, 1.0),
	ModuleType.TURRET: Color(0.55, 0.65, 0.85, 1.0),
	ModuleType.TRAP: Color(0.8, 0.3, 0.3, 1.0),
}

signal module_destroyed()

@onready var icon: Polygon2D = $Icon

@export var category: SlotType = SlotType.MINOR
@export var industry_cost: int = 5
@export var max_hp: int = 100

var module_type: ModuleType
var zone_id: String = ""
var current_hp: int
var is_active: bool = true
var _is_destroyed: bool = false


func _ready() -> void:
	current_hp = max_hp


func configure(p_zone_id: String, p_module_type: ModuleType) -> void:
	zone_id = p_zone_id
	module_type = p_module_type
	var cfg: Dictionary = CATALOG[module_type]
	category = cfg["slot"]
	industry_cost = int(cfg["cost"])
	max_hp = int(cfg["hp"])
	current_hp = max_hp

	if icon:
		icon.color = TYPE_COLORS.get(module_type, Color.WHITE)

	QuestLogger.info(QuestLogger.Category.MODULE, "Module '%s' built in zone '%s'." % [ModuleType.keys()[module_type], zone_id])


func take_damage(amount: int) -> void:
	if _is_destroyed or not is_active:
		return
	current_hp = maxi(current_hp - maxi(amount, 0), 0)
	if current_hp <= 0:
		die()


func die() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	is_active = false
	QuestLogger.info(QuestLogger.Category.MODULE, "Module '%s' in zone '%s' destroyed." % [ModuleType.keys()[module_type], zone_id])
	module_destroyed.emit()
	queue_free()


func is_trap() -> bool:
	return module_type == ModuleType.TRAP

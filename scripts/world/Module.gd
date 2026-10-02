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

## Flavor line for the build-menu tooltip (effect numbers come from describe_effect()).
const DESCRIPTIONS := {
	ModuleType.GENERATOR_INDUSTRY: "Engranajes oxidados que todavía giran.",
	ModuleType.GENERATOR_FOOD: "Huerto de hongos bajo luz tenue.",
	ModuleType.GENERATOR_SCIENCE: "Instrumentos antiguos que zumban solos.",
	ModuleType.TURRET: "Dispara a los enemigos que entran en la sala.",
	ModuleType.TRAP: "Frena a los enemigos que llegan a la sala.",
}

const RESOURCE_LABELS := {"industry": "Industria", "food": "Comida", "science": "Ciencia", "dust": "Polvo"}

signal module_destroyed()
## Any HP change (damage). The mini bar and the enemy AI listen.
signal hp_changed(current: int, maximum: int)
signal damaged(amount: int)

const FLASH_SEC := 0.15
const BAR_SIZE := Vector2(24.0, 3.0)
const BAR_OFFSET := Vector2(-12.0, 12.0)


## Human-readable effect of a catalog entry, derived from its numbers.
static func describe_effect(type: ModuleType) -> String:
	var cfg: Dictionary = CATALOG[type]
	match type:
		ModuleType.TURRET:
			return "%d de daño cada %.1f s" % [int(cfg["damage"]), float(cfg["fire_rate"])]
		ModuleType.TRAP:
			return "Ralentiza %d%% durante %.0f s" % [roundi((1.0 - float(cfg["slow_factor"])) * 100.0), float(cfg["slow_duration"])]
	for key: String in ["industry", "food", "science"]:
		if int(cfg.get(key, 0)) > 0:
			return "+%d %s por turno" % [int(cfg[key]), RESOURCE_LABELS[key]]
	return ""

@onready var icon: Polygon2D = $Icon

@export var category: SlotType = SlotType.MINOR
@export var industry_cost: int = 5
@export var max_hp: int = 100

var module_type: ModuleType
var zone_id: String = ""
var current_hp: int
var is_active: bool = true
## False while the owning room is switched off (RoomZone.set_powered): the
## module stays built and targetable but produces/fires/slows nothing.
var powered: bool = true
var _is_destroyed: bool = false
var _bar_back: ColorRect
var _bar_fill: ColorRect
var _flash_tween: Tween


func _ready() -> void:
	current_hp = max_hp
	_build_bar()


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
	_update_bar()

	QuestLogger.info(QuestLogger.Category.MODULE, "Module '%s' built in zone '%s'." % [ModuleType.keys()[module_type], zone_id])


func take_damage(amount: int) -> void:
	if _is_destroyed or not is_active:
		return
	current_hp = maxi(current_hp - maxi(amount, 0), 0)
	damaged.emit(amount)
	hp_changed.emit(current_hp, max_hp)
	_update_bar()
	if current_hp <= 0:
		die()
	else:
		_play_hit(amount)


func die() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	is_active = false
	QuestLogger.info(QuestLogger.Category.MODULE, "Module '%s' in zone '%s' destroyed." % [ModuleType.keys()[module_type], zone_id])
	module_destroyed.emit()
	queue_free()


func is_working() -> bool:
	return is_active and powered


## Where enemies close in on it (TargetSelector / Enemy).
func get_target_position() -> Vector2:
	return global_position


## Enemies may attack it: built and alive, even while its room is switched off.
func is_targetable() -> bool:
	return is_active and not _is_destroyed


func is_trap() -> bool:
	return module_type == ModuleType.TRAP


## Mini HP bar under the module: only visible once it is damaged.
func _build_bar() -> void:
	_bar_back = ColorRect.new()
	_bar_back.color = Color(0.05, 0.05, 0.05, 0.85)
	_bar_back.size = BAR_SIZE
	_bar_back.position = BAR_OFFSET
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.z_index = 3
	_bar_fill = ColorRect.new()
	_bar_fill.size = BAR_SIZE
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.add_child(_bar_fill)
	add_child(_bar_back)
	_update_bar()


func _update_bar() -> void:
	if _bar_back == null:
		return
	var ratio := clampf(float(current_hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	_bar_back.visible = current_hp < max_hp
	_bar_fill.size.x = BAR_SIZE.x * ratio
	_bar_fill.color = QuestPalette.BLOOD_LIGHT.lerp(Color(0.45, 0.8, 0.4), ratio)


## White blink + floating damage number (the Nexo's hit feedback, for modules).
func _play_hit(amount: int) -> void:
	if icon:
		if _flash_tween:
			_flash_tween.kill()
		var base: Color = TYPE_COLORS.get(module_type, Color.WHITE)
		icon.color = Color.WHITE
		_flash_tween = create_tween().set_ignore_time_scale()
		_flash_tween.tween_property(icon, "color", base, FLASH_SEC)
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(get_target_position() + Vector2(0.0, -16.0), "-%d" % amount, QuestPalette.BLOOD_LIGHT)

extends Node2D
class_name Module

## Module: buildable room upgrade. Major (Generator) modules feed resource
## bonuses into ResourceManager on door-open (see DoorTurnSystem.open_room).
## Minor (Turret/Trap) modules are the room's defenses against enemies.
## Owns a tiny self-contained HP block mirroring CharacterStats.take_damage's
## clamp/signal shape — not a shared base class, per codebase convention.

enum SlotType { MAJOR, MINOR }
## Values 0-4 are serialized (ResearchEntry.module in .tres): append, never reorder.
enum ModuleType { FORJA, GRANJA, SCRIPTORIUM, BALLESTA, BRASERO, CATAPULTA, PINCHOS }

const DEF_PATHS := [
	"res://resources/modules/forja.tres", "res://resources/modules/granja.tres",
	"res://resources/modules/scriptorium.tres", "res://resources/modules/ballesta.tres",
	"res://resources/modules/brasero.tres", "res://resources/modules/catapulta.tres",
	"res://resources/modules/pinchos.tres",
]

## type -> dict built from resources/modules/*.tres (ModuleDef.to_dict()).
static var CATALOG: Dictionary = _build_catalog()

const TYPE_COLORS := {
	ModuleType.FORJA: Color(0.72, 0.74, 0.8, 1.0),
	ModuleType.GRANJA: Color(0.85, 0.4, 0.4, 1.0),
	ModuleType.SCRIPTORIUM: Color(0.6, 0.45, 0.85, 1.0),
	ModuleType.BALLESTA: Color(0.55, 0.65, 0.85, 1.0),
	ModuleType.BRASERO: Color(0.9, 0.55, 0.2, 1.0),
	ModuleType.CATAPULTA: Color(0.65, 0.55, 0.4, 1.0),
	ModuleType.PINCHOS: Color(0.8, 0.3, 0.3, 1.0),
}

const RESOURCE_LABELS := {"industry": "Industria", "food": "Comida", "science": "Ciencia", "dust": "Polvo"}

signal module_destroyed()
## Any HP change (damage). The mini bar and the enemy AI listen.
signal hp_changed(current: int, maximum: int)
signal damaged(amount: int)

const FLASH_SEC := 0.15
const BAR_SIZE := Vector2(24.0, 3.0)
const BAR_OFFSET := Vector2(-12.0, 12.0)


static func _build_catalog() -> Dictionary:
	var out := {}
	for path: String in DEF_PATHS:
		var def := load(path) as ModuleDef
		out[def.type] = def.to_dict()
	return out


## Flavor line for the build-menu tooltip (effect numbers come from describe_effect()).
static func description_of(type: ModuleType) -> String:
	return str(CATALOG[type]["description"])


## Human-readable effect of a catalog entry, derived from its numbers.
static func describe_effect(type: ModuleType) -> String:
	var cfg: Dictionary = CATALOG[type]
	if cfg.has("damage"):
		var area := " (área)" if float(cfg["splash_radius"]) > 0.0 else ""
		return "%d de daño cada %.1f s%s" % [int(cfg["damage"]), float(cfg["fire_rate"]), area]
	if cfg.has("slow_duration"):
		return "Ralentiza %d%% durante %.0f s" % [roundi((1.0 - float(cfg["slow_factor"])) * 100.0), float(cfg["slow_duration"])]
	if cfg.has("spike_damage"):
		return "%d de daño a cada enemigo que entra" % int(cfg["spike_damage"])
	for key: String in ["industry", "food", "science"]:
		if int(cfg.get(key, 0)) > 0:
			return "+%d %s por turno" % [int(cfg[key]), RESOURCE_LABELS[key]]
	return ""


## Price of the next module of `type`: base cost grows with the ones already built.
static func get_cost(type: ModuleType) -> int:
	var rm := ManagerLocator.get_room_manager()
	var built := rm.count_modules(type) if rm else 0
	return ModuleCostCurve.get_default().cost(int(CATALOG[type]["cost"]), built)

@onready var icon: Polygon2D = $Icon

@export var category: SlotType = SlotType.MINOR
@export var industry_cost: int = 5
@export var max_hp: int = 100

var module_type: ModuleType
## Industria paid when built (set by BuildingMenu): demolishing refunds a share of it.
var paid_cost: int = 0
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
	return is_active and (powered or not bool(CATALOG[module_type].get("requires_power", true)))


## Where enemies close in on it (TargetSelector / Enemy).
func get_target_position() -> Vector2:
	return global_position


## Enemies may attack it: built and alive, even while its room is switched off.
func is_targetable() -> bool:
	return is_active and not _is_destroyed


func is_trap() -> bool:
	return module_type == ModuleType.BRASERO or module_type == ModuleType.PINCHOS


## Industria to restore all missing HP (0 when undamaged).
func repair_cost() -> int:
	return ModuleCostCurve.get_default().repair_cost(int(CATALOG[module_type]["cost"]), max_hp - current_hp, max_hp)


## Pays repair_cost() in Industria and restores full HP. False if undamaged or short.
func repair() -> bool:
	var cost := repair_cost()
	var rm := ManagerLocator.get_resource_manager()
	if cost <= 0 or rm == null or not rm.spend_resource("industry", cost):
		return false
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)
	_update_bar()
	return true


func refund_value() -> int:
	return ModuleCostCurve.get_default().refund(paid_cost)


## Tears it down for a share of what it cost (the slot frees itself via module_destroyed).
func demolish() -> void:
	var rm := ManagerLocator.get_resource_manager()
	if rm and not _is_destroyed:
		rm.add_resource("industry", refund_value())
	die()


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

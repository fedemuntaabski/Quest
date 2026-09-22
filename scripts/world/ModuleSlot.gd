extends Area2D
class_name ModuleSlot

## ModuleSlot: an empty/filled build slot on a powered RoomZone. Click plumbing
## mirrors Door.gd/EnergyButton.gd. `ModuleBuildSystem` listens for
## `slot_clicked` and pops a build menu when the slot is empty.

signal slot_clicked(slot: ModuleSlot)

const MAJOR_COLOR := Color(0.9, 0.9, 0.9, 0.5)
const MINOR_COLOR := Color(0.7, 0.7, 0.7, 0.4)

@onready var marker: Polygon2D = $Marker

var slot_type: Module.SlotType = Module.SlotType.MINOR
var zone_id: String = ""
var built_module: Module = null

const MODULE_SCENE := preload("res://scenes/world/Module.tscn")


func _ready() -> void:
	z_index = 2
	input_event.connect(_on_input_event)


func configure(p_zone_id: String, p_slot_type: Module.SlotType) -> void:
	zone_id = p_zone_id
	slot_type = p_slot_type
	if marker:
		marker.color = MAJOR_COLOR if slot_type == Module.SlotType.MAJOR else MINOR_COLOR


func is_empty() -> bool:
	return built_module == null


func build(module_type: Module.ModuleType) -> Module:
	if not is_empty():
		return built_module

	var module := MODULE_SCENE.instantiate() as Module
	add_child(module)
	module.configure(zone_id, module_type)
	module.destroyed.connect(_on_module_destroyed)
	built_module = module
	if marker:
		marker.visible = false
	return module


func _on_module_destroyed(_module: Module) -> void:
	built_module = null
	if marker:
		marker.visible = true


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	slot_clicked.emit(self)
	get_viewport().set_input_as_handled()

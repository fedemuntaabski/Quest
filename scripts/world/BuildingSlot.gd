extends Area2D
class_name BuildingSlot

## BuildingSlot: an empty/filled build slot on a powered RoomZone. Click plumbing
## mirrors Door.gd/EnergyButton.gd. `ModuleBuildSystem` listens for
## `slot_clicked` and pops a build menu when the slot is empty. Clicks are
## ignored unless the owning room reports `can_build()` (i.e. is energized).

signal slot_clicked(slot: BuildingSlot)

enum SlotType { MAJOR, MINOR }

const MAJOR_COLOR := Color(0.9, 0.9, 0.9, 0.18)
const MINOR_COLOR := Color(0.7, 0.7, 0.7, 0.12)
const MAJOR_OUTLINE := Color(0.9, 0.9, 0.9, 0.5)
const MINOR_OUTLINE := Color(0.7, 0.7, 0.7, 0.4)

@export var slot_type: SlotType = SlotType.MINOR

@onready var marker: Polygon2D = $Marker
@onready var outline: Line2D = $Outline

var zone_id: String = ""
var is_occupied: bool = false
var built_module: Node2D = null


func _ready() -> void:
	z_index = 2
	input_event.connect(_on_input_event)
	_apply_visual()


func configure(p_zone_id: String, p_slot_type: SlotType) -> void:
	zone_id = p_zone_id
	slot_type = p_slot_type
	if is_node_ready():
		_apply_visual()


func is_empty() -> bool:
	return not is_occupied


func build(module_type: Module.ModuleType) -> Module:
	if is_occupied:
		return built_module as Module

	var scene_path: String = Module.CATALOG[module_type]["scene"]
	var module := (load(scene_path) as PackedScene).instantiate() as Module
	add_child(module)
	module.position = Vector2.ZERO
	module.configure(zone_id, module_type)
	module.module_destroyed.connect(_on_module_destroyed)
	built_module = module
	is_occupied = true
	_set_marker_visible(false)
	return module


func _on_module_destroyed() -> void:
	built_module = null
	is_occupied = false
	_set_marker_visible(true)


func _apply_visual() -> void:
	var is_major := slot_type == SlotType.MAJOR
	marker.color = MAJOR_COLOR if is_major else MINOR_COLOR
	outline.default_color = MAJOR_OUTLINE if is_major else MINOR_OUTLINE


func _set_marker_visible(v: bool) -> void:
	marker.visible = v
	outline.visible = v


## The owning RoomZone is the nearest ancestor exposing `can_build()`; walking up
## keeps this valid whether slots sit directly under the zone or in `BuildingSlots`.
func _find_room() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("can_build"):
			return node
		node = node.get_parent()
	return null


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	if is_occupied:
		return
	var room := _find_room()
	if room == null or not room.can_build():
		return
	slot_clicked.emit(self)
	get_viewport().set_input_as_handled()

extends Area2D
class_name BuildingSlot

## BuildingSlot: an empty/filled build slot on a powered RoomZone. Click plumbing
## mirrors Door.gd/EnergyButton.gd. Not pickable by default (session 8): only
## BuildingMenu's armed mode turns slots pickable, so an unarmed click falls
## through to the RoomZone (moves the hero) instead of opening anything.
## `slot_clicked` → ModuleBuildSystem → BuildingMenu.open_menu() builds the
## armed module. Clicks are ignored unless the owning room `can_build()`.

signal slot_clicked(slot: BuildingSlot)

enum SlotType { MAJOR, MINOR }

const MAJOR_COLOR := Color(0.9, 0.9, 0.9, 0.18)
const MINOR_COLOR := Color(0.7, 0.7, 0.7, 0.12)
const MAJOR_OUTLINE := Color(0.9, 0.9, 0.9, 0.5)
const MINOR_OUTLINE := Color(0.7, 0.7, 0.7, 0.4)
const HIGHLIGHT_OUTLINE := Color(1.0, 0.85, 0.4, 1.0)
const OUTLINE_WIDTH := 1.5
const HIGHLIGHT_WIDTH := 3.0
## Armed-mode ghost tint over the module's own icon: can / can't build here.
const GHOST_OK := Color(0.4, 1.0, 0.4, 0.6)
const GHOST_BLOCKED := Color(1.0, 0.3, 0.3, 0.6)

@export var slot_type: SlotType = SlotType.MINOR

@onready var marker: Polygon2D = $Marker
@onready var outline: Line2D = $Outline

var zone_id: String = ""
var is_occupied: bool = false
var built_module: Node2D = null
var _ghost: Polygon2D = null


func _ready() -> void:
	z_index = 2
	input_pickable = false
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
	clear_ghost()
	var scene_path: String = Module.CATALOG[module_type]["scene"]
	var module := (load(scene_path) as PackedScene).instantiate() as Module
	add_child(module)
	module.position = Vector2.ZERO
	module.configure(zone_id, module_type)
	module.module_destroyed.connect(_on_module_destroyed)
	built_module = module
	is_occupied = true
	_set_marker_visible(false)
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"hit_sparks", global_position, vfx.config.build_color)
	return module


func _on_module_destroyed() -> void:
	built_module = null
	is_occupied = false
	_set_marker_visible(true)


func _apply_visual() -> void:
	var is_major := slot_type == SlotType.MAJOR
	marker.color = MAJOR_COLOR if is_major else MINOR_COLOR
	outline.default_color = MAJOR_OUTLINE if is_major else MINOR_OUTLINE
	outline.width = OUTLINE_WIDTH


## BuildingMenu marks the slot it is building into.
func set_highlighted(on: bool) -> void:
	_apply_visual()
	if on:
		outline.default_color = HIGHLIGHT_OUTLINE
		outline.width = HIGHLIGHT_WIDTH


## Semi-transparent preview of `module_type` (the module scene's own Icon,
## detached before the scene ever enters the tree → no _ready, no groups).
func set_ghost(module_type: Module.ModuleType, ok: bool) -> void:
	clear_ghost()
	var scene := (load(Module.CATALOG[module_type]["scene"]) as PackedScene).instantiate()
	_ghost = scene.get_node("Icon") as Polygon2D
	scene.remove_child(_ghost)
	scene.free()
	_ghost.owner = null
	_ghost.color = Module.TYPE_COLORS.get(module_type, Color.WHITE)
	_ghost.modulate = GHOST_OK if ok else GHOST_BLOCKED
	add_child(_ghost)


func clear_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null


func get_ghost() -> Polygon2D:
	return _ghost


func room_can_build() -> bool:
	var room := _find_room()
	return room != null and room.can_build()


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
	if is_occupied or not room_can_build():
		return
	slot_clicked.emit(self)
	get_viewport().set_input_as_handled()

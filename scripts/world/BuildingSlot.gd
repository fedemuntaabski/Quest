extends Area2D
class_name BuildingSlot

## BuildingSlot: an empty/filled build slot on a lit RoomZone. Click plumbing
## mirrors Door.gd/LightHint.gd. Not pickable by default (session 8): only
## BuildingMenu's armed mode turns slots pickable, so an unarmed click falls
## through to the RoomZone (moves the hero) instead of opening anything.
## `slot_clicked` → RoomManager → HUDController → BuildingMenu.open_menu() builds the
## armed building. Clicks are ignored unless the owning room `can_build()`.

signal slot_clicked(slot: BuildingSlot)
signal building_built(building: Building)
## Left click on a built slot (the HUD opens the repair/demolish popup).
signal building_clicked(slot: BuildingSlot)

enum SlotType { MAJOR, MINOR }

const MAJOR_COLOR := Color(0.9, 0.9, 0.9, 0.18)
const MINOR_COLOR := Color(0.7, 0.7, 0.7, 0.12)
const MAJOR_OUTLINE := Color(0.9, 0.9, 0.9, 0.5)
const MINOR_OUTLINE := Color(0.7, 0.7, 0.7, 0.4)
const HIGHLIGHT_OUTLINE := Color(1.0, 0.85, 0.4, 1.0)
const OUTLINE_WIDTH := 1.5
const HIGHLIGHT_WIDTH := 3.0
## While armed: bigger (picking too) and over the heroes, who stand on the center slot.
const HIGHLIGHT_SCALE := 1.8
const HIGHLIGHT_Z := 8
## Armed-mode ghost tint over the building's own icon: can / can't build here.
const GHOST_OK := Color(0.4, 1.0, 0.4, 0.6)
const GHOST_BLOCKED := Color(1.0, 0.3, 0.3, 0.6)

@export var slot_type: SlotType = SlotType.MINOR

@onready var marker: Polygon2D = $Marker
@onready var outline: Line2D = $Outline

var zone_id: String = ""
var is_occupied: bool = false
var built_building: Node2D = null
var _ghost: Polygon2D = null
var _pulse: Tween


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


func build(building_type: Building.BuildingType) -> Building:
	if is_occupied:
		return built_building as Building
	clear_ghost()
	var scene_path: String = Building.CATALOG[building_type]["scene"]
	var building := (load(scene_path) as PackedScene).instantiate() as Building
	building.paid_cost = Building.get_cost(building_type)  # before add_child: it must not count itself
	add_child(building)
	building.position = Vector2.ZERO
	building.configure(zone_id, building_type)
	building.building_destroyed.connect(_on_building_destroyed)
	built_building = building
	is_occupied = true
	_set_marker_visible(false)
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"hit_sparks", global_position, vfx.config.build_color)
	building_built.emit(building)
	return building


func _on_building_destroyed() -> void:
	built_building = null
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
	scale = Vector2.ONE * (HIGHLIGHT_SCALE if on else 1.0)
	z_index = HIGHLIGHT_Z if on else 2
	if _pulse:
		_pulse.kill()
		_pulse = null
	outline.modulate.a = 1.0
	if on:
		outline.default_color = HIGHLIGHT_OUTLINE
		outline.width = HIGHLIGHT_WIDTH
		if not Accessibility.reduce_flashes:
			_pulse = create_tween().set_loops().set_ignore_time_scale()
			_pulse.tween_property(outline, "modulate:a", 0.3, 0.45)
			_pulse.tween_property(outline, "modulate:a", 1.0, 0.45)


## Semi-transparent preview of `building_type` (the building scene's own Icon,
## detached before the scene ever enters the tree → no _ready, no groups).
func set_ghost(building_type: Building.BuildingType, ok: bool) -> void:
	clear_ghost()
	var scene := (load(Building.CATALOG[building_type]["scene"]) as PackedScene).instantiate()
	_ghost = scene.get_node("Icon") as Polygon2D
	scene.remove_child(_ghost)
	scene.free()
	_ghost.owner = null
	_ghost.color = Building.TYPE_COLORS.get(building_type, Color.WHITE)
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
	if is_occupied:
		building_clicked.emit(self)
		get_viewport().set_input_as_handled()
		return
	if not room_can_build():
		return
	slot_clicked.emit(self)
	get_viewport().set_input_as_handled()

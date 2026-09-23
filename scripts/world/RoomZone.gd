extends Area2D
class_name RoomZone

## RoomZone: one clickable room or corridor in the room-graph. Replaces the
## old per-cell BFS Highlight overlay — hover/selection feedback is drawn
## directly on this zone's Fill/Outline instead of painting tiles.

signal clicked(zone: RoomZone)
signal hovered(zone: RoomZone)
signal unhovered(zone: RoomZone)

enum Highlight { NONE, CURRENT, REACHABLE, OPENABLE, BLOCKED }

const SHAPE_INSET := 6.0
const OUTLINE_WIDTH := 3.0
const REVEALED_IDLE_OUTLINE := Color(1, 1, 1, 0.25)
const POWERED_FILL_COLOR := Color(0.95, 0.78, 0.42, 0.28)
const POWERED_OUTLINE_COLOR := Color(1.00, 0.88, 0.53, 0.9)

const FILL_COLORS := {
	Highlight.NONE: Color(1, 1, 1, 0.0),
	Highlight.CURRENT: Color(1, 1, 1, 0.06),
	Highlight.REACHABLE: Color(0.45, 0.85, 1.0, 0.20),
	Highlight.OPENABLE: Color(1.0, 0.75, 0.25, 0.22),
	Highlight.BLOCKED: Color(0.9, 0.25, 0.25, 0.16),
}
const OUTLINE_COLORS := {
	Highlight.NONE: Color(1, 1, 1, 0.0),
	Highlight.CURRENT: Color(1, 1, 1, 0.8),
	Highlight.REACHABLE: Color(0.45, 0.85, 1.0, 0.8),
	Highlight.OPENABLE: Color(1.0, 0.75, 0.25, 0.85),
	Highlight.BLOCKED: Color(0.9, 0.25, 0.25, 0.85),
}

const ENERGY_BUTTON_SCENE := preload("res://scenes/world/EnergyButton.tscn")
const MODULE_SLOT_SCENE := preload("res://scenes/world/ModuleSlot.tscn")
const MODULE_SLOT_OFFSETS := [Vector2(0, -24), Vector2(-24, 20), Vector2(24, 20)]

signal energize_requested(zone_id: String)
signal slot_clicked(zone_id: String, slot: ModuleSlot)

@onready var fill: Polygon2D = $Fill
@onready var outline: Line2D = $Outline
@onready var collision: CollisionShape2D = $CollisionShape2D

var zone_id: String = ""
var kind: String = ""
var is_powered: bool = false

## Room-graph node data (Phase 1). `room_id` aliases `zone_id`; `is_visited`
## mirrors DoorTurnSystem's visited state (synced by RoomManager.on_group_revealed).
var room_id: String:
	get: return zone_id
	set(v): zone_id = v
var center_position: Vector2 = Vector2.ZERO
var is_visited: bool = false
var connected_doors: Array[Door] = []

var _state: int = Highlight.NONE
var _revealed: bool = false
var _energy_button: EnergyButton = null
var _module_slots: Array[ModuleSlot] = []


func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(func(): hovered.emit(self))
	mouse_exited.connect(func(): unhovered.emit(self))


## `size_px` is the zone's full world-space size (rect.size * tile_size).
func configure(p_zone_id: String, size_px: Vector2, p_kind: String) -> void:
	zone_id = p_zone_id
	kind = p_kind

	var half := (size_px - Vector2.ONE * SHAPE_INSET * 2.0) / 2.0
	var points := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])

	fill.polygon = points
	outline.points = PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	outline.width = OUTLINE_WIDTH

	var shape := RectangleShape2D.new()
	shape.size = size_px - Vector2.ONE * SHAPE_INSET * 2.0
	collision.shape = shape

	set_highlight(Highlight.NONE)

	if kind == "room":
		_energy_button = ENERGY_BUTTON_SCENE.instantiate() as EnergyButton
		add_child(_energy_button)
		_energy_button.energy_button_clicked.connect(func(_zid: String): energize_requested.emit(zone_id))
		_update_energy_button_visibility()


func set_revealed(v: bool) -> void:
	_revealed = v
	_apply_visual()
	_update_energy_button_visibility()


func is_revealed() -> bool:
	return _revealed


func set_highlight(state: int) -> void:
	_state = state
	_apply_visual()


func set_powered(v: bool) -> void:
	if is_powered == v:
		return
	is_powered = v
	_apply_visual()
	_update_energy_button_visibility()
	if is_powered and _module_slots.is_empty() and kind == "room":
		_spawn_module_slots()


func get_modules() -> Array[Module]:
	var modules: Array[Module] = []
	for slot in _module_slots:
		if not slot.is_empty():
			modules.append(slot.built_module)
	return modules


func _spawn_module_slots() -> void:
	var slot_types := [Module.SlotType.MAJOR, Module.SlotType.MINOR, Module.SlotType.MINOR]
	for i in range(slot_types.size()):
		var slot := MODULE_SLOT_SCENE.instantiate() as ModuleSlot
		add_child(slot)
		slot.position = MODULE_SLOT_OFFSETS[i]
		slot.configure(zone_id, slot_types[i])
		slot.slot_clicked.connect(func(s: ModuleSlot): slot_clicked.emit(zone_id, s))
		_module_slots.append(slot)


func _update_energy_button_visibility() -> void:
	if _energy_button == null:
		return
	var should_show := _revealed and not is_powered
	_energy_button.visible = should_show
	_energy_button.input_pickable = should_show


func _apply_visual() -> void:
	if _state == Highlight.NONE and is_powered:
		fill.color = POWERED_FILL_COLOR
		outline.default_color = POWERED_OUTLINE_COLOR
		return
	fill.color = FILL_COLORS.get(_state, FILL_COLORS[Highlight.NONE])
	outline.default_color = REVEALED_IDLE_OUTLINE if (_state == Highlight.NONE and _revealed) \
		else OUTLINE_COLORS.get(_state, OUTLINE_COLORS[Highlight.NONE])


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	clicked.emit(self)
	get_viewport().set_input_as_handled()

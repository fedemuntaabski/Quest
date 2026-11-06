extends Area2D
class_name RoomZone

## RoomZone: one clickable room or corridor in the room-graph. Replaces the
## old per-cell BFS Highlight overlay — hover/selection feedback is drawn
## directly on this zone's Fill/Outline instead of painting tiles. Presentation
## and input only: graph/geometry lives in RoomManager, lifecycle in DoorTurnSystem.
## Never queries either: RoomManager pushes `set_shown()`; `_shown` is render
## state, not the source of truth for discovery.

signal clicked(zone: RoomZone)
signal hovered(zone: RoomZone)
signal unhovered(zone: RoomZone)

enum Highlight { NONE, CURRENT, REACHABLE, OPENABLE, BLOCKED }

const SHAPE_INSET := 6.0
const OUTLINE_WIDTH := 3.0
const REVEALED_IDLE_OUTLINE := Color(1, 1, 1, 0.25)
const LIGHT_COST: int = 10
const LIT_FILL_COLOR := Color(1.0, 0.9, 0.5, 0.30)
const LIT_OUTLINE_COLOR := Color(1.0, 0.9, 0.5, 0.95)

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

const UNSHADED: CanvasItemMaterial = preload("res://resources/maps/unshaded_material.tres")
## Room-type badge: small diamond + name, inset from the room's top-left corner.
const TYPE_BADGE_INSET := Vector2(18, 18)
const TYPE_BADGE_RADIUS := 7.0
## Light status icon (top-right corner, mirrors the type badge).
const LIGHT_ICON_INSET := Vector2(34, 26)
const LIGHT_ON_COLOR := Color(1.0, 0.85, 0.3)
const LIGHT_OFF_COLOR := Color(0.6, 0.6, 0.65)
const LIGHT_OFF_SLASH_COLOR := Color(0.9, 0.25, 0.25)

const LIGHT_HINT_SCENE := preload("res://scenes/world/LightHint.tscn")
const BUILDING_SLOT_SCENE := preload("res://scenes/world/BuildingSlot.tscn")
const BUILDING_SLOT_OFFSETS := [Vector2(0, 0), Vector2(-28, 22), Vector2(28, 22)]
const MAJOR_SLOT_SPACING := 56.0

## Any light state change (player-paid or scripted). RoomLight listens.
signal light_changed(zone_id: String, lit: bool)
signal slot_clicked(zone_id: String, slot: BuildingSlot)
signal building_built(zone_id: String, building: Building)
signal building_clicked(zone_id: String, slot: BuildingSlot)

@onready var fill: Polygon2D = $Fill
@onready var outline: Line2D = $Outline
@onready var collision: CollisionShape2D = $CollisionShape2D

var zone_id: String = ""
var kind: String = ""
var is_lit: bool = false

## Room-graph node data. `room_id` aliases `zone_id`. Visited/discovery state
## is NOT stored here — DoorTurnSystem owns it (query RoomManager.is_zone_revealed).
## `_shown` below is only what RoomManager last pushed for rendering.
var room_id: String:
	get: return zone_id
	set(v): zone_id = v
var center_position: Vector2 = Vector2.ZERO
var connected_doors: Array[Door] = []

var _state: int = Highlight.NONE
var _shown: bool = false
var _light_hint: LightHint = null
var _light: RoomLight = null
var _type_badge: Node2D = null
var _light_icon: Node2D = null
var _light_flame: Polygon2D = null
var _light_slash: Line2D = null
var _light_label: Label = null
var _building_slots: Array[BuildingSlot] = []
## Extra MAJOR slots on top of the usual one (RoomTypeRule.extra_major_slots,
## set by Main2d before the room is lit).
var extra_major_slots: int = 0
## Embers the player paid to light this room; refunded when switched off. 0 for
## rooms lit for free (the start room), so toggling can't mint embers.
var _light_paid: int = 0
@onready var _slots_container: Node2D = $BuildingSlots


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
		_light_hint = LIGHT_HINT_SCENE.instantiate() as LightHint
		add_child(_light_hint)
		_light_hint.light_hint_clicked.connect(func(_zid: String): try_light_up())
		_update_light_hint_visibility()
		_build_light_icon(half)

	_set_render_visible(false)


## Pushed by RoomManager.apply_zone_visibility(): show/hide this zone.
func set_shown(v: bool) -> void:
	_shown = v
	_set_render_visible(v)
	_apply_visual()
	_update_light_hint_visibility()


## Fog-of-war switch: hidden zones draw nothing and cannot receive clicks.
func _set_render_visible(p_visible: bool) -> void:
	collision.set_deferred("disabled", not p_visible)
	input_pickable = p_visible
	fill.visible = p_visible
	outline.visible = p_visible
	if _light != null:
		_light.visible = p_visible
	if _type_badge != null:
		_type_badge.visible = p_visible
	if _light_icon != null:
		_light_icon.visible = p_visible
	for slot in _building_slots:
		slot.visible = p_visible
		slot.input_pickable = p_visible
	if _light_hint != null:
		if p_visible:
			_update_light_hint_visibility()
		else:
			_light_hint.visible = false
			_light_hint.input_pickable = false


func is_shown() -> bool:
	return _shown


func set_highlight(state: int) -> void:
	_state = state
	_apply_visual()


func set_lit(v: bool) -> void:
	if is_lit == v:
		return
	is_lit = v
	var had_workshop := false
	for building in get_buildings():
		building.lit = v
		had_workshop = had_workshop or building is WorkshopBuilding
	if had_workshop:
		var resources := ManagerLocator.get_resource_manager()
		if resources:
			resources.notify_production_changed()
	light_changed.emit(zone_id, v)
	_apply_visual()
	_update_light_icon()
	_update_light_hint_visibility()
	if is_lit and _building_slots.is_empty() and kind == "room":
		_spawn_building_slots()


## Adds the dark/lit lighting layer (rooms only), drawn under Fill and the
## energy button/slots. Call after configure(), once the zone is in the tree.
func attach_light(size_px: Vector2, config: MapVisualConfig) -> void:
	_light = RoomLight.new()
	_light.name = "RoomLight"
	add_child(_light)
	move_child(_light, 0)
	_light.setup(self, size_px - Vector2.ONE * SHAPE_INSET * 2.0, config)
	_light.visible = _shown


func get_light() -> RoomLight:
	return _light


## Types with a marker (RoomTypeVisual.show_marker) get a badge (icon or diamond
## + name) in the type color, unshaded so it reads in dark rooms too; shown/hidden
## with the fog like the rest of the zone. Combat/Start/Exit get none (the exit
## keeps its own hint-gated marker).
func set_room_type(type: RoomData.RoomType, size_px: Vector2, config: MapVisualConfig) -> void:
	var visual := config.room_type_visual(type) if config else null
	if visual == null or not visual.show_marker:
		return
	var color := visual.color
	_type_badge = Node2D.new()
	_type_badge.name = "TypeBadge"
	_type_badge.position = -size_px / 2.0 + Vector2.ONE * SHAPE_INSET + TYPE_BADGE_INSET
	add_child(_type_badge)

	var r := TYPE_BADGE_RADIUS
	if visual.icon:
		var icon := Sprite2D.new()
		icon.material = UNSHADED
		icon.texture = visual.icon
		icon.scale = Vector2.ONE * ArtConfig.ART_SCALE
		_type_badge.add_child(icon)
		r = visual.icon.get_width() * ArtConfig.ART_SCALE / 2.0
	else:
		var diamond := Polygon2D.new()
		diamond.material = UNSHADED
		diamond.color = color
		diamond.polygon = PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
		_type_badge.add_child(diamond)

	var label := Label.new()
	label.material = UNSHADED
	label.text = visual.display_name
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", Accessibility.font(14))
	label.position = Vector2(r + 4.0, -11.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_badge.add_child(label)
	_type_badge.visible = _shown


## LIGHT_COST + FloorConfig.light_cost_step per room already lit with embers
## (`lit_count`, the free start room excluded), minus the research discount (min 1).
static func get_light_cost(lit_count: int = 0) -> int:
	var rm := ManagerLocator.get_resource_manager()
	var fm := ManagerLocator.get_floor_manager()
	var step: int = (fm.config if fm else FloorManager.DEFAULT_CONFIG).light_cost_step
	return maxi(1, LIGHT_COST + step * lit_count - (roundi(rm.get_bonus(ResearchEntry.Effect.LIGHT_COST)) if rm else 0))


## What lighting THIS room costs right now (grows per lit room).
func next_light_cost() -> int:
	var room_manager := ManagerLocator.get_room_manager()
	return get_light_cost(room_manager.get_lit_count() if room_manager else 0)


## Lit with embers (the free start room is not): each one raises the next cost.
func is_paid_light() -> bool:
	return is_lit and _light_paid > 0


## Cost text / affordability follow the lit count (RoomManager calls this on every light change).
func refresh_light_hints() -> void:
	if _light_hint != null:
		_light_hint.refresh_label(next_light_cost())
	if _light != null:
		_light.refresh_affordable()


## Pays next_light_cost() embers to light this room. No-op if already lit.
func try_light_up() -> void:
	if is_lit:
		return
	var resource_manager := ManagerLocator.get_resource_manager()
	if resource_manager == null:
		return
	var cost := next_light_cost()
	if not resource_manager.spend_resource("embers", cost):
		var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
		if text_mgr:
			text_mgr.spawn_text(center_position, "Brasas insuficientes", QuestPalette.GOLD_DARK)
		return
	_light_paid = cost
	set_lit(true)
	var audio := ManagerLocator.get_audio()
	if audio:
		audio.play_sfx(&"light")
	QuestLogger.info(QuestLogger.Category.ROOM, "Zone '%s' lit for %d embers." % [zone_id, cost])


## Switches a lit room off and refunds the embers paid for it (DotE-style).
func light_down() -> void:
	if not is_lit:
		return
	var resource_manager := ManagerLocator.get_resource_manager()
	if resource_manager and _light_paid > 0:
		resource_manager.add_resource("embers", _light_paid)
	_light_paid = 0
	set_lit(false)


## Middle-click on a revealed room: light it (pays embers) or switch it off.
func toggle_light() -> void:
	if kind != "room" or not _shown:
		return
	if is_lit:
		light_down()
	else:
		try_light_up()


## Sole build gate: only lit rooms accept buildings.
func can_build() -> bool:
	return is_lit


## coop-12: build slot by index (majors first, then the 2 minors); null if none.
func get_slot(index: int) -> BuildingSlot:
	return _building_slots[index] if index >= 0 and index < _building_slots.size() else null


func get_slot_index(slot: BuildingSlot) -> int:
	return _building_slots.find(slot)


func get_light_paid() -> int:
	return _light_paid


## coop-12 (client mirror): the host's light state, no embers moves here.
func apply_light(lit: bool, paid: int) -> void:
	_light_paid = paid
	if lit != is_lit:
		set_lit(lit)


func get_buildings() -> Array[Building]:
	var buildings: Array[Building] = []
	for slot in _building_slots:
		if not slot.is_empty():
			buildings.append(slot.built_building)
	return buildings


func _spawn_building_slots() -> void:
	var majors := 1 + maxi(extra_major_slots, 0)
	var slot_types: Array[BuildingSlot.SlotType] = []
	var offsets: Array[Vector2] = []
	for i in majors:
		slot_types.append(BuildingSlot.SlotType.MAJOR)
		# One major sits in the center; several share a row above the minors.
		offsets.append(BUILDING_SLOT_OFFSETS[0] if majors == 1 else Vector2((i - (majors - 1) * 0.5) * MAJOR_SLOT_SPACING, -14.0))
	for i in [1, 2]:
		slot_types.append(BuildingSlot.SlotType.MINOR)
		offsets.append(BUILDING_SLOT_OFFSETS[i])
	for i in range(slot_types.size()):
		var slot := BUILDING_SLOT_SCENE.instantiate() as BuildingSlot
		_slots_container.add_child(slot)
		slot.position = offsets[i]
		slot.configure(zone_id, slot_types[i])
		slot.slot_clicked.connect(func(s: BuildingSlot): slot_clicked.emit(zone_id, s))
		slot.building_clicked.connect(func(s: BuildingSlot): building_clicked.emit(zone_id, s))
		slot.building_built.connect(func(m: Building): building_built.emit(zone_id, m))
		_building_slots.append(slot)


## Top-right status icon of a room: gold flame + "Encendida" when lit, grey crossed
## flame + "Apagada" when dark. Unshaded (reads in the dark), hidden with the fog.
func _build_light_icon(half: Vector2) -> void:
	_light_icon = Node2D.new()
	_light_icon.name = "LightIcon"
	_light_icon.position = Vector2(half.x - LIGHT_ICON_INSET.x, -half.y + LIGHT_ICON_INSET.y)
	_light_icon.visible = _shown
	add_child(_light_icon)

	_light_flame = Polygon2D.new()
	_light_flame.material = UNSHADED
	_light_flame.polygon = PackedVector2Array([Vector2(1, -12), Vector2(3, -6), Vector2(7, -1), Vector2(8, 4), Vector2(5, 9), Vector2(0, 11), Vector2(-5, 9), Vector2(-8, 4), Vector2(-6, -1), Vector2(-4, 1), Vector2(-3, -5)])
	_light_icon.add_child(_light_flame)

	_light_slash = Line2D.new()
	_light_slash.material = UNSHADED
	_light_slash.points = PackedVector2Array([Vector2(-9, -9), Vector2(9, 9)])
	_light_slash.width = 3.0
	_light_slash.default_color = LIGHT_OFF_SLASH_COLOR
	_light_icon.add_child(_light_slash)

	_light_label = Label.new()
	_light_label.material = UNSHADED
	_light_label.add_theme_font_size_override("font_size", Accessibility.font(12))
	_light_label.position = Vector2(-28, 12)
	_light_label.size = Vector2(56, 16)
	_light_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_light_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_icon.add_child(_light_label)
	_update_light_icon()


func _update_light_icon() -> void:
	if _light_icon == null:
		return
	_light_flame.color = LIGHT_ON_COLOR if is_lit else LIGHT_OFF_COLOR
	_light_slash.visible = not is_lit
	_light_label.text = "Encendida" if is_lit else "Apagada"
	_light_label.add_theme_color_override("font_color", LIGHT_ON_COLOR if is_lit else LIGHT_OFF_COLOR)


func _update_light_hint_visibility() -> void:
	if _light_hint == null:
		return
	var should_show := _shown and not is_lit
	_light_hint.visible = should_show
	# Passive hint since session 7: the room is lit with middle-click (toggle_light).
	_light_hint.input_pickable = false


func _apply_visual() -> void:
	if _state == Highlight.NONE and is_lit:
		fill.color = LIT_FILL_COLOR
		outline.default_color = LIT_OUTLINE_COLOR
		return
	fill.color = FILL_COLORS.get(_state, FILL_COLORS[Highlight.NONE])
	outline.default_color = REVEALED_IDLE_OUTLINE if (_state == Highlight.NONE and _shown) \
		else OUTLINE_COLORS.get(_state, OUTLINE_COLORS[Highlight.NONE])


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	if not _shown or get_viewport().is_input_handled():
		return
	match event.button_index:
		# heroes-9 (DotE): right = move; left selects (HeroInputController) and
		# does nothing on an empty room. While a building is armed,
		# BuildingMenu._input consumes the right click first (cancel).
		MOUSE_BUTTON_RIGHT:
			if not event.pressed:
				return
			clicked.emit(self)
		# coop-12: Alt + left = map ping (everyone sees it); plain left is selection.
		MOUSE_BUTTON_LEFT:
			if not (event.pressed and event.alt_pressed):
				return
			ManagerLocator.get_net_commands().request("map_ping", {"zone": zone_id})
		# Middle = light/unlight on release, unless it was a camera drag.
		MOUSE_BUTTON_MIDDLE:
			if event.pressed or kind != "room":
				return
			var camera := ManagerLocator.get_camera()
			if camera and camera.was_dragged():
				return
			ManagerLocator.get_net_commands().request("toggle_light", {"zone": zone_id})
		_:
			return
	get_viewport().set_input_as_handled()

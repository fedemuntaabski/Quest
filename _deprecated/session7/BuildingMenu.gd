extends PanelContainer
class_name BuildingMenu

## BuildingMenu: DotE-style build panel docked in the HUD bottom bar, above
## the resource/build row. Two entry points, one purchase path:
##  - bottom-bar "Producción"/"Defensa" → open_category(): pick a card → the
##    module is armed and every free matching slot in a powered room is
##    highlighted → clicking one of them builds it (open_menu → purchase).
##  - clicking an empty slot → open_menu(slot): cards for that slot, build now. Tabs by category (Producción =
## MAJOR-slot generators, Defensa = MINOR-slot turret/trap), one card per
## Module.CATALOG entry: color icon, name, cost colored by resource (red if
## short), native tooltip with description + effect, "Construir" disabled when
## unaffordable or the slot is the wrong size. Highlights the chosen slot while
## open. Owns the purchase: spends Industria and asks the slot to build.
## Closes on right-click, or left-click outside the panel (not while armed:
## that click is the slot pick).

## Static style helper via preload (the ThemeManager autoload identifier is
## missing in --script test runs).
const ThemeStyles = preload("res://scripts/core/theme/ThemeManager.gd")

const SHAKE_DISTANCE := 8.0
const SHAKE_STEP := 0.04
## Every catalog cost is Industria today.
const COST_RESOURCE := "industry"
const ICON_SIZE := Vector2(28, 28)
## Tab index == Module.SlotType (MAJOR = production, MINOR = defense).
const TAB_TITLES := ["Producción", "Defensa"]
const SLOT_NAMES := ["mayor", "menor"]

@onready var options: VBoxContainer = $Margin/Content/Options
@onready var tabs: TabBar = $Margin/Content/Tabs
@onready var title: Label = $Margin/Content/Title

var _slot: BuildingSlot = null
var _shake_tween: Tween
## Module picked from the bottom bar with no slot yet; -1 = none.
var _armed_type: int = -1
var _armed_slots: Array[BuildingSlot] = []


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", ThemeStyles.build_panel_style(Color(0.08, 0.08, 0.1, 0.95), QuestPalette.GOLD_DARK, 2, 8))
	tabs.tab_changed.connect(func(_tab: int) -> void:
		_disarm()
		_populate())
	var rm := ManagerLocator.get_resource_manager()
	if rm:
		rm.resource_changed.connect(_on_resource_changed)


func open_menu(slot_node: BuildingSlot) -> void:
	if slot_node == null or not slot_node.is_empty():
		return
	if _armed_type != -1 and visible:
		_build_armed_into(slot_node)
		return
	_disarm()
	if _slot and is_instance_valid(_slot):
		_slot.set_highlighted(false)
	_slot = slot_node
	_slot.set_highlighted(true)
	title.text = "Construir — slot %s" % SLOT_NAMES[int(slot_node.slot_type)]
	tabs.current_tab = int(slot_node.slot_type)
	_populate()
	visible = true


## Bottom-bar entry: cards for `tab` (== Module.SlotType) with no slot chosen.
func open_category(tab: int) -> void:
	close_menu()
	title.text = "Construir — elegí un módulo"
	tabs.current_tab = tab
	_disarm()
	_populate()
	visible = true


func is_armed() -> bool:
	return _armed_type != -1


func close_menu() -> void:
	visible = false
	_disarm()
	if _slot and is_instance_valid(_slot):
		_slot.set_highlighted(false)
	_slot = null


## Cards for the current tab. Resource changes and tab switches rebuild them.
func _populate() -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var rm := ManagerLocator.get_resource_manager()
	var available: int = rm.get_resource(COST_RESOURCE) if rm else 0
	for module_type in Module.CATALOG.keys():
		var cfg: Dictionary = Module.CATALOG[module_type]
		if int(cfg["slot"]) != tabs.current_tab:
			continue
		var fits := _slot == null or int(cfg["slot"]) == int(_slot.slot_type)
		options.add_child(_make_card(module_type, cfg, fits, available >= int(cfg["cost"])))


func _make_card(module_type: Module.ModuleType, cfg: Dictionary, fits_slot: bool, affordable: bool) -> Control:
	var cost := int(cfg["cost"])
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", ThemeStyles.build_panel_style(QuestPalette.DUNGEON_STONE, QuestPalette.UI_PANEL_BORDER, 1, 6, 6))
	var reason := ""
	if not fits_slot:
		reason = "\nRequiere un slot %s." % SLOT_NAMES[int(cfg["slot"])]
	elif not affordable:
		reason = "\nIndustria insuficiente."
	card.tooltip_text = "%s\n%s\n%s\nVida: %d%s" % [cfg["label"], Module.DESCRIPTIONS.get(module_type, ""), Module.describe_effect(module_type), int(cfg["hp"]), reason]
	if not (fits_slot and affordable):
		card.modulate = Color(1, 1, 1, 0.55)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var icon := ColorRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.color = Module.TYPE_COLORS.get(module_type, Color.WHITE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_label := Label.new()
	name_label.text = str(cfg["label"])
	name_label.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	column.add_child(name_label)
	var effect_label := Label.new()
	effect_label.text = Module.describe_effect(module_type)
	effect_label.add_theme_color_override("font_color", QuestPalette.UI_TEXT_SECONDARY)
	effect_label.add_theme_font_size_override("font_size", 13)
	column.add_child(effect_label)

	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cost_row)
	var cost_icon := StatIcon.new()
	cost_icon.icon_type = COST_RESOURCE
	cost_row.add_child(cost_icon)
	cost_icon.custom_minimum_size = Vector2(18, 18)
	cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost_label := Label.new()
	cost_label.text = str(cost)
	cost_label.add_theme_color_override("font_color", StatIcon.BASE_COLORS[COST_RESOURCE] if affordable else QuestPalette.UI_TEXT_BLOCKED)
	cost_row.add_child(cost_label)

	var build_button := Button.new()
	build_button.text = "Construir" if _slot else "Elegir"
	build_button.disabled = not (fits_slot and affordable)
	build_button.tooltip_text = card.tooltip_text
	build_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _slot:
		build_button.pressed.connect(_on_module_selected.bind(module_type, cost, String(cfg["scene"])))
	else:
		build_button.pressed.connect(_arm.bind(module_type))
	row.add_child(build_button)
	return card


## Bottom-bar flow: remember the module and outline every free slot it fits.
func _arm(module_type: Module.ModuleType) -> void:
	_disarm()
	_armed_type = int(module_type)
	var slot_type := int(Module.CATALOG[module_type]["slot"])
	_armed_slots = _free_slots(slot_type)
	for slot in _armed_slots:
		slot.set_highlighted(true)
	var label := str(Module.CATALOG[module_type]["label"])
	if _armed_slots.is_empty():
		title.text = "%s: no hay slots %ss libres — energizá una sala" % [label, SLOT_NAMES[slot_type]]
	else:
		title.text = "%s: clic en un slot %s resaltado (clic derecho cancela)" % [label, SLOT_NAMES[slot_type]]


func _disarm() -> void:
	for slot in _armed_slots:
		if is_instance_valid(slot):
			slot.set_highlighted(false)
	_armed_slots.clear()
	_armed_type = -1


func _build_armed_into(slot_node: BuildingSlot) -> void:
	var module_type := _armed_type as Module.ModuleType
	var cfg: Dictionary = Module.CATALOG[module_type]
	if int(cfg["slot"]) != int(slot_node.slot_type):
		var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
		if text_mgr:
			text_mgr.spawn_text(slot_node.global_position, "Requiere un slot %s" % SLOT_NAMES[int(cfg["slot"])], QuestPalette.GOLD_DARK)
		return
	_slot = slot_node
	_on_module_selected(module_type, int(cfg["cost"]), String(cfg["scene"]))
	if visible:  # purchase refused: stay armed, no slot chosen
		_slot = null


## Empty slots of `slot_type` in powered (buildable) rooms.
func _free_slots(slot_type: int) -> Array[BuildingSlot]:
	var result: Array[BuildingSlot] = []
	var rm := ManagerLocator.get_room_manager()
	if rm == null:
		return result
	for room in rm.get_powered_rooms():
		for node in room.find_children("*", "BuildingSlot", true, false):
			var slot := node as BuildingSlot
			if slot.is_empty() and int(slot.slot_type) == slot_type:
				result.append(slot)
	return result


func _on_resource_changed(key: String, _amount: int, _delta: int) -> void:
	if visible and key == COST_RESOURCE and _armed_type == -1:
		_populate()


func _on_module_selected(module_type: Module.ModuleType, cost: int, _scene_path: String) -> void:
	if _slot == null or not is_instance_valid(_slot) or not _slot.is_empty():
		close_menu()
		return

	var resource_manager := ManagerLocator.get_resource_manager()
	if resource_manager == null:
		return

	if not resource_manager.spend_resource(COST_RESOURCE, cost):
		_reject_purchase()
		return

	var slot := _slot
	slot.build(module_type)
	QuestLogger.info(QuestLogger.Category.MODULE, "Built '%s' in zone '%s'." % [Module.CATALOG[module_type]["label"], slot.zone_id])
	close_menu()


func _reject_purchase() -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr and _slot:
		text_mgr.spawn_text(_slot.global_position, "Industria insuficiente", QuestPalette.GOLD_DARK)

	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	var origin_x := position.x
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position:x", origin_x + SHAKE_DISTANCE, SHAKE_STEP)
	_shake_tween.tween_property(self, "position:x", origin_x - SHAKE_DISTANCE, SHAKE_STEP * 2.0)
	_shake_tween.tween_property(self, "position:x", origin_x, SHAKE_STEP)


## Deliberately never marks input handled: `_input` runs before Area2D picking,
## so swallowing here would block clicks on other slots/zones.
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		close_menu()
	elif event.button_index == MOUSE_BUTTON_LEFT and _armed_type == -1 and not get_global_rect().has_point(event.position):
		close_menu()

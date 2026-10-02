extends PanelContainer
class_name BuildingMenu

## BuildingMenu: DotE-style build panel docked in the HUD bottom bar, above
## the resource/build row. Only entry point (session 8): bottom-bar
## "Producción"/"Defensa" → open_category(): pick a card (or press 1-9) → the
## module is *armed*: free matching slots in powered rooms are outlined, every
## empty slot becomes pickable and shows a ghost of the module under the cursor
## (green = buildable, red = floating text with the reason) → clicking a slot
## (BuildingSlot → RoomManager.slot_clicked → HUDController → open_menu) builds it. Tabs by category
## (Producción = MAJOR-slot generators, Defensa = MINOR-slot turret/trap), one
## card per Module.CATALOG entry. Owns the purchase: spends Industria and asks
## the slot to build. Right-click or Esc cancels (Esc is consumed, so it never
## reaches Main2d's pause toggle); left-click outside closes when not armed.
## The session-7 "click an empty slot to open the menu" flow is gone
## (_deprecated/session7/).
## Session 10: modules locked behind research (ResourceManager.is_unlocked)
## show a padlock + "Requiere: <research>", can't be armed (button disabled,
## so 1-9 skip them too) and get_block_reason() reports the lock first.

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

var _shake_tween: Tween
## Module picked from the bottom bar; -1 = none.
var _armed_type: int = -1
## Free matching slots in powered rooms (outlined).
var _armed_slots: Array[BuildingSlot] = []
## Every empty slot, pickable + ghost-on-hover while armed → its bound hover Callable.
var _hover_slots: Dictionary = {}


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", UiStyles.build_panel_style(Color(0.08, 0.08, 0.1, 0.95), QuestPalette.GOLD_DARK, 2, 8))
	tabs.tab_changed.connect(func(_tab: int) -> void:
		_disarm()
		_populate())
	var rm := ManagerLocator.get_resource_manager()
	if rm:
		rm.resource_changed.connect(_on_resource_changed)
		rm.research_changed.connect(_on_research_changed)
	# A room lit/unlit while armed changes which slots are free/buildable.
	var room_manager := ManagerLocator.get_room_manager()
	if room_manager:
		room_manager.room_power_changed.connect(func(_zone_id: String, _powered: bool) -> void:
			if is_armed():
				_arm(_armed_type as Module.ModuleType))


## Slot click routed by HUDController. Builds the armed module; without
## one armed it does nothing (slots aren't even pickable then).
func open_menu(slot_node: BuildingSlot) -> void:
	if slot_node == null or not slot_node.is_empty() or not is_armed() or not visible:
		return
	_build_armed_into(slot_node)


## Bottom-bar entry: cards for `tab` (== Module.SlotType).
func open_category(tab: int) -> void:
	close_menu()
	title.text = "Construir — elegí un módulo (1-9)"
	tabs.current_tab = tab
	_disarm()
	_populate()
	visible = true


func is_armed() -> bool:
	return _armed_type != -1


func close_menu() -> void:
	visible = false
	_disarm()


## "" if the armed module can be built in `slot`, else why not.
func get_block_reason(slot: BuildingSlot) -> String:
	if not is_armed():
		return "Ningún módulo elegido"
	var lock := get_lock_reason(_armed_type as Module.ModuleType)
	if lock != "":
		return lock
	var cfg: Dictionary = Module.CATALOG[_armed_type]
	if int(cfg["slot"]) != int(slot.slot_type):
		return "Tamaño incorrecto: requiere un slot %s" % SLOT_NAMES[int(cfg["slot"])]
	if not slot.room_can_build():
		return "Sala apagada"
	var rm := ManagerLocator.get_resource_manager()
	if rm == null or rm.get_resource(COST_RESOURCE) < int(cfg["cost"]):
		return "Falta Industria"
	return ""


## "Requiere: <research>" while `module_type` is locked behind research, else "".
static func get_lock_reason(module_type: Module.ModuleType) -> String:
	var rm := ManagerLocator.get_resource_manager()
	if rm == null or rm.is_unlocked(module_type):
		return ""
	return "Requiere: %s" % rm.research_config.get_unlock_entry(module_type).display_name


## Cards for the current tab. Resource changes and tab switches rebuild them.
func _populate() -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var rm := ManagerLocator.get_resource_manager()
	var available: int = rm.get_resource(COST_RESOURCE) if rm else 0
	var index := 0
	for module_type in Module.CATALOG.keys():
		var cfg: Dictionary = Module.CATALOG[module_type]
		if int(cfg["slot"]) != tabs.current_tab:
			continue
		index += 1
		options.add_child(_make_card(module_type, cfg, index, available >= int(cfg["cost"]), get_lock_reason(module_type)))


func _make_card(module_type: Module.ModuleType, cfg: Dictionary, hotkey: int, affordable: bool, lock := "") -> Control:
	var cost := int(cfg["cost"])
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", UiStyles.build_panel_style(QuestPalette.DUNGEON_STONE, QuestPalette.UI_PANEL_BORDER, 1, 6, 6))
	var reason := "\n" + lock if lock != "" else ("" if affordable else "\nIndustria insuficiente.")
	card.tooltip_text = "%s\n%s\n%s\nVida: %d%s" % [cfg["label"], Module.DESCRIPTIONS.get(module_type, ""), Module.describe_effect(module_type), int(cfg["hp"]), reason]
	if not affordable or lock != "":
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
	if lock != "":
		var padlock := StatIcon.new()
		padlock.icon_type = "lock"
		icon.add_child(padlock)
		padlock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		padlock.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_label := Label.new()
	name_label.text = "%d. %s" % [hotkey, cfg["label"]]
	name_label.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	column.add_child(name_label)
	var effect_label := Label.new()
	effect_label.text = lock if lock != "" else Module.describe_effect(module_type)
	effect_label.add_theme_color_override("font_color", QuestPalette.UI_TEXT_BLOCKED if lock != "" else QuestPalette.UI_TEXT_SECONDARY)
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

	var pick_button := Button.new()
	pick_button.text = "Elegir"
	pick_button.disabled = not affordable or lock != ""
	pick_button.tooltip_text = card.tooltip_text
	pick_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pick_button.pressed.connect(_arm.bind(module_type))
	row.add_child(pick_button)
	return card


## Remember the module, outline every free slot it fits, and make every empty
## slot pickable with a ghost preview on hover.
func _arm(module_type: Module.ModuleType) -> void:
	if get_lock_reason(module_type) != "":
		return
	_disarm()
	_armed_type = int(module_type)
	var slot_type := int(Module.CATALOG[module_type]["slot"])
	_armed_slots = _free_slots(slot_type)
	for slot in _armed_slots:
		slot.set_highlighted(true)
	for slot in _empty_slots():
		_hover_slots[slot] = _on_slot_hovered.bind(slot)
		slot.input_pickable = true
		slot.mouse_entered.connect(_hover_slots[slot])
		slot.mouse_exited.connect(slot.clear_ghost)
	var label := str(Module.CATALOG[module_type]["label"])
	if _armed_slots.is_empty():
		title.text = "%s: no hay slots %ss libres — energizá una sala" % [label, SLOT_NAMES[slot_type]]
	else:
		title.text = "%s: clic en un slot %s resaltado (clic derecho / Esc cancela)" % [label, SLOT_NAMES[slot_type]]


func _disarm() -> void:
	for slot in _armed_slots:
		if is_instance_valid(slot):
			slot.set_highlighted(false)
	_armed_slots.clear()
	for slot in _hover_slots:
		if is_instance_valid(slot):
			slot.input_pickable = false
			slot.mouse_entered.disconnect(_hover_slots[slot])
			slot.mouse_exited.disconnect(slot.clear_ghost)
			slot.clear_ghost()
	_hover_slots.clear()
	_armed_type = -1


func _on_slot_hovered(slot: BuildingSlot) -> void:
	if not is_armed() or not slot.is_empty():
		return
	var reason := get_block_reason(slot)
	slot.set_ghost(_armed_type as Module.ModuleType, reason == "")
	if reason != "":
		_float_text(slot, reason)


func _build_armed_into(slot_node: BuildingSlot) -> void:
	var reason := get_block_reason(slot_node)
	var module_type := _armed_type as Module.ModuleType
	var resource_manager := ManagerLocator.get_resource_manager()
	if reason != "" or resource_manager == null \
			or not resource_manager.spend_resource(COST_RESOURCE, int(Module.CATALOG[module_type]["cost"])):
		_reject(slot_node, reason if reason != "" else "Falta Industria")
		return  # stay armed
	slot_node.build(module_type)
	QuestLogger.info(QuestLogger.Category.MODULE, "Built '%s' in zone '%s'." % [Module.CATALOG[module_type]["label"], slot_node.zone_id])
	close_menu()


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


## Every empty slot on the map (lit or not, any size) — hover explains why not.
func _empty_slots() -> Array[BuildingSlot]:
	var result: Array[BuildingSlot] = []
	var rm := ManagerLocator.get_room_manager()
	if rm == null:
		return result
	for zone_id in rm.get_zone_ids():
		var zone := rm.get_zone_node(zone_id)
		if zone == null:
			continue
		for node in zone.find_children("*", "BuildingSlot", true, false):
			if (node as BuildingSlot).is_empty():
				result.append(node)
	return result


func _on_resource_changed(key: String, _amount: int, _delta: int) -> void:
	if visible and key == COST_RESOURCE and _armed_type == -1:
		_populate()


func _on_research_changed() -> void:
	if visible and not is_armed():
		_populate()


func _float_text(slot: BuildingSlot, text: String) -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(slot.global_position, text, QuestPalette.GOLD_DARK)


func _reject(slot: BuildingSlot, reason: String) -> void:
	_float_text(slot, reason)
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	var origin_x := position.x
	_shake_tween = create_tween().set_ignore_time_scale()
	_shake_tween.tween_property(self, "position:x", origin_x + SHAKE_DISTANCE, SHAKE_STEP)
	_shake_tween.tween_property(self, "position:x", origin_x - SHAKE_DISTANCE, SHAKE_STEP * 2.0)
	_shake_tween.tween_property(self, "position:x", origin_x, SHAKE_STEP)


## Mouse clicks are left unhandled (`_input` runs before Area2D picking, so
## swallowing them would block the slot pick) except the armed right click:
## consumed on purpose so the cancel doesn't also move the hero (RoomZone).
## Unarmed, right click moves the hero and the menu stays; Esc / left click
## outside close it. Esc / 1-9 are consumed while the menu is visible (closed,
## 1-3 are control groups; Ctrl+N always assigns a group, so it is skipped here).
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed \
			and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var buttons := options.find_children("*", "Button", true, false)
		var index: int = event.keycode - KEY_1
		if index < buttons.size() and not (buttons[index] as Button).disabled:
			(buttons[index] as Button).pressed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and is_armed():
			close_menu()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and _armed_type == -1 and not get_global_rect().has_point(event.position):
			close_menu()

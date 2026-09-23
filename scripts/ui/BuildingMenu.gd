extends PanelContainer
class_name BuildingMenu

## BuildingMenu: floating build menu shown over a clicked empty BuildingSlot.
## Lives in the HUD CanvasLayer. Owns the purchase: spends Industria and asks
## the slot to build. Closes on right-click or left-click outside the panel.

const SLOT_OFFSET := Vector2(0.0, -12.0)
const SCREEN_PADDING := 8.0
const SHAKE_DISTANCE := 8.0
const SHAKE_STEP := 0.04

@onready var options: VBoxContainer = $Margin/Options

var _slot: BuildingSlot = null
var _shake_tween: Tween


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", ThemeManager.build_panel_style(Color(0.08, 0.08, 0.1, 0.95), QuestPalette.GOLD_DARK, 2, 8))


func open_menu(slot_node: BuildingSlot) -> void:
	if slot_node == null or not slot_node.is_empty():
		return
	_slot = slot_node

	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()

	for module_type in Module.CATALOG.keys():
		var cfg: Dictionary = Module.CATALOG[module_type]
		if int(cfg["slot"]) != int(slot_node.slot_type):
			continue
		var button := Button.new()
		button.text = "%s (%d Industria)" % [cfg["label"], int(cfg["cost"])]
		button.pressed.connect(_on_module_selected.bind(module_type, int(cfg["cost"]), String(cfg["scene"])))
		options.add_child(button)

	if options.get_child_count() == 0:
		_slot = null
		return

	visible = true
	reset_size()
	var anchor := slot_node.get_global_transform_with_canvas().origin + SLOT_OFFSET
	var vp := get_viewport_rect().size
	var pos := Vector2(anchor.x - size.x * 0.5, anchor.y - size.y)
	pos.x = clampf(pos.x, SCREEN_PADDING, maxf(SCREEN_PADDING, vp.x - size.x - SCREEN_PADDING))
	pos.y = clampf(pos.y, SCREEN_PADDING, maxf(SCREEN_PADDING, vp.y - size.y - SCREEN_PADDING))
	global_position = pos


func close_menu() -> void:
	visible = false
	_slot = null


func _on_module_selected(module_type: Module.ModuleType, cost: int, _scene_path: String) -> void:
	if _slot == null or not is_instance_valid(_slot) or not _slot.is_empty():
		close_menu()
		return

	var resource_manager := ManagerLocator.get_resource_manager()
	if resource_manager == null:
		return

	if not resource_manager.spend_resource("industry", cost):
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
	elif event.button_index == MOUSE_BUTTON_LEFT and not get_global_rect().has_point(event.position):
		close_menu()

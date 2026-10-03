extends Control
class_name ModulePopup

## ModulePopup: small modal opened by clicking a built module (BuildingSlot.module_clicked).
## Shows HP and offers Reparar (Industria, scales with missing HP) and Desmontar
## (refunds a share of what it cost). Esc / X / click outside close it; Esc is
## consumed here so it doesn't also open the pause menu. Built in code by HUDController.

const PANEL_WIDTH := 300.0

var module: Module

var _title: Label
var _info: Label
var _repair: Button
var _demolish: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	var rm := ManagerLocator.get_resource_manager()
	if rm:
		rm.resource_changed.connect(func(_k: String, _a: int, _d: int) -> void: _refresh())


func open_for(p_module: Module) -> void:
	module = p_module
	visible = true
	_refresh()


func close() -> void:
	visible = false
	module = null


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.45)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", UiStyles.build_panel_style(QuestPalette.UI_PANEL_BG, QuestPalette.GOLD_DARK, 2, 8, 14))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", QuestPalette.GOLD)
	_title.add_theme_font_size_override("font_size", 20)
	header.add_child(_title)
	var x := Button.new()
	x.text = "X"
	x.tooltip_text = "Cerrar (Esc)"
	x.pressed.connect(close)
	header.add_child(x)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", QuestPalette.PARCHMENT_LIGHT)
	content.add_child(_info)
	_repair = Button.new()
	_repair.name = "Repair"
	_repair.pressed.connect(func() -> void:
		if module and module.repair():
			_refresh())
	content.add_child(_repair)
	_demolish = Button.new()
	_demolish.name = "Demolish"
	_demolish.pressed.connect(func() -> void:
		if module:
			module.demolish()
		close())
	content.add_child(_demolish)


func _refresh() -> void:
	if not visible:
		return
	if module == null or not is_instance_valid(module) or not module.is_targetable():
		close()
		return
	var cfg: Dictionary = Module.CATALOG[module.module_type]
	_title.text = str(cfg["label"])
	_info.text = "%s\n%s\nVida: %d / %d" % [cfg["description"], Module.describe_effect(module.module_type), module.current_hp, module.max_hp]
	var cost := module.repair_cost()
	var rm := ManagerLocator.get_resource_manager()
	_repair.disabled = cost <= 0 or rm == null or rm.get_resource("industry") < cost
	_repair.text = "Sin daños" if cost <= 0 else "Reparar (%d Industria)" % cost
	_repair.tooltip_text = "" if cost <= 0 or not _repair.disabled else "Industria insuficiente"
	_demolish.text = "Desmontar (+%d Industria)" % module.refund_value()

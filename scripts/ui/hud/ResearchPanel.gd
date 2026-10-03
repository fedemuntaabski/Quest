extends PanelContainer
class_name ResearchPanel

## ResearchPanel (session 10): Ciencia sink. Docked in the HUD bottom bar
## above the resource row (HUDController adds it next to BuildingMenu, same
## style). Bottom-bar "Investigar" → toggle(); one card per ResearchConfig
## entry: name, effect, cost, state (Disponible / Falta Ciencia / Requiere: X
## / Investigada) and an "Investigar" button → ResourceManager.research().
## Esc and right click close it and are consumed (Esc never reaches Main2d's
## pause toggle). Plain Controls, so it works at Engine.time_scale 0.

const COST_RESOURCE := "science"
const COLUMNS := 2

var _list: GridContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyles.build_panel_style(Color(0.08, 0.08, 0.1, 0.95), QuestPalette.GOLD_DARK, 2, 8))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_theme_constant_override("margin_top", 8)
	add_child(margin)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	var title := Label.new()
	title.text = "Investigar — se paga con Ciencia (Esc cierra)"
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42, 1))
	content.add_child(title)
	_list = GridContainer.new()
	_list.columns = COLUMNS
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("h_separation", 6)
	_list.add_theme_constant_override("v_separation", 6)
	content.add_child(_list)
	var rm := ManagerLocator.get_resource_manager()
	if rm:
		rm.research_changed.connect(_on_research_changed)
		rm.resource_changed.connect(_on_resource_changed)


func open() -> void:
	_populate()
	visible = true


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## State shown on a card: "Disponible" or the ResourceManager block reason.
static func get_state(id: String) -> String:
	var rm := ManagerLocator.get_resource_manager()
	if rm == null:
		return ""
	var reason: String = rm.get_research_block_reason(id)
	return "Disponible" if reason == "" else reason


func _populate() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var rm := ManagerLocator.get_resource_manager()
	if rm == null:
		return
	for entry: ResearchEntry in rm.research_config.entries:
		_list.add_child(_make_card(entry))


func _make_card(entry: ResearchEntry) -> Control:
	var rm := ManagerLocator.get_resource_manager()
	var state := get_state(entry.id)
	var available: bool = rm.can_research(entry.id)
	var done: bool = rm.is_researched(entry.id)
	var card := PanelContainer.new()
	card.name = entry.id
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "%s\n%s\n%s" % [entry.display_name, entry.description, entry.describe_effect()]
	card.add_theme_stylebox_override("panel", UiStyles.build_panel_style(QuestPalette.DUNGEON_STONE, QuestPalette.GOLD_DARK if done else QuestPalette.UI_PANEL_BORDER, 1, 6, 6))
	if not available and not done:
		card.modulate = Color(1, 1, 1, 0.6)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	column.add_child(_label(("T2 · " if entry.prerequisite != "" else "T1 · ") + entry.display_name, QuestPalette.PARCHMENT, 15))
	column.add_child(_label(entry.describe_effect(), QuestPalette.UI_TEXT_SECONDARY, 13))
	var state_label := _label(state, QuestPalette.GOLD if done else (StatIcon.BASE_COLORS[COST_RESOURCE] if available else QuestPalette.UI_TEXT_BLOCKED), 12)
	state_label.name = "State"
	column.add_child(state_label)

	var side := VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(cost_row)
	var cost_icon := StatIcon.new()
	cost_icon.icon_type = COST_RESOURCE
	cost_row.add_child(cost_icon)
	cost_icon.custom_minimum_size = Vector2(18, 18)
	cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(_label(str(entry.cost), StatIcon.BASE_COLORS[COST_RESOURCE] if available else QuestPalette.UI_TEXT_BLOCKED, 14))
	var button := Button.new()
	button.name = "Research"
	button.text = "Hecho" if done else "Investigar"
	button.disabled = not available
	button.tooltip_text = card.tooltip_text
	button.pressed.connect(_on_research_pressed.bind(entry.id))
	side.add_child(button)
	return card


func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _on_research_pressed(id: String) -> void:
	var rm := ManagerLocator.get_resource_manager()
	if rm and rm.research(id):  # research_changed → _populate
		var entry := rm.research_config.get_entry(id)
		var hud := ManagerLocator.get_hud()
		if hud:
			hud.show_hint("Investigado: %s" % entry.display_name, entry.describe_effect(), QuestPalette.GOLD)


func _on_research_changed() -> void:
	if visible:
		_populate()


func _on_resource_changed(key: String, _amount: int, _delta: int) -> void:
	if visible and key == COST_RESOURCE:
		_populate()


## Esc / right click close and are consumed. Other clicks pass through.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		close()
		get_viewport().set_input_as_handled()

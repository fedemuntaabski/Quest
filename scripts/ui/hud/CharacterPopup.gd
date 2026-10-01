extends Control
class_name CharacterPopup

## CharacterPopup: modal hero sheet opened by clicking a HeroPortrait. Full-rect
## veil (click = close) + centered panel: preview, name, level, exact HP, combat
## stats from CharacterStats/CharacterData, and a "Subir de nivel" section:
## next level, Comida cost and what each stat gains (PlayerStats.get_level_up_
## preview → level_up_hero, for this popup's hero — not necessarily the
## active one; the UI computes nothing). Closes with the
## X button, a click outside, or Esc — Esc is consumed here, so it never also
## toggles the pause menu (HUD's _input runs before Main2d's).
## Built in code by HUDController; refreshes on signals only.

## Static style helper via preload (the ThemeManager autoload identifier is
## missing in --script test runs).
const ThemeStyles = preload("res://scripts/core/theme/ThemeManager.gd")

const PREVIEW_SIZE := Vector2(128, 128)
const PANEL_WIDTH := 460.0

var stats: CharacterStats
var character_data: CharacterData

var _title: Label
var _preview: TextureRect
var _info: Label
var _level_title: Label
var _upgrade_rows: GridContainer
var _level_button: Button
var _found_title: Label
var _found_rows: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()

	var ps := ManagerLocator.get_player_stats()
	if ps:
		ps.stats_changed.connect(func(_s: CharacterStats) -> void: _refresh())
		ps.run_upgrades_changed.connect(func(_k: String, _l: int, _id: String) -> void: _refresh())
		ps.found_items_changed.connect(_refresh)
	var rm := ManagerLocator.get_resource_manager()
	if rm:
		rm.resource_changed.connect(func(_k: String, _a: int, _d: int) -> void: _refresh())


func open_for(p_stats: CharacterStats, p_data: CharacterData) -> void:
	if stats and stats != p_stats and stats.hp_changed.is_connected(_on_hp_changed):
		stats.hp_changed.disconnect(_on_hp_changed)
	stats = p_stats
	character_data = p_data
	if stats and not stats.hp_changed.is_connected(_on_hp_changed):
		stats.hp_changed.connect(_on_hp_changed)
	_preview.texture = _preview_texture()
	visible = true
	_refresh()


func close() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_hp_changed(_current: int, _max: int) -> void:
	_refresh()


# ---------------- BUILD ----------------

func _build() -> void:
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.55)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(_on_veil_input)
	add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", ThemeStyles.build_panel_style(QuestPalette.UI_PANEL_BG, QuestPalette.GOLD_DARK, 2, 8, 14))
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", QuestPalette.GOLD)
	_title.add_theme_font_size_override("font_size", 24)
	header.add_child(_title)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Cerrar (Esc)"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	content.add_child(body)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ThemeStyles.build_panel_style(QuestPalette.DUNGEON_STONE, QuestPalette.UI_PANEL_BORDER, 2, 6, 4))
	body.add_child(frame)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = PREVIEW_SIZE
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_preview)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", QuestPalette.PARCHMENT_LIGHT)
	body.add_child(_info)

	content.add_child(HSeparator.new())
	_level_title = Label.new()
	_level_title.add_theme_color_override("font_color", QuestPalette.GOLD)
	content.add_child(_level_title)
	_upgrade_rows = GridContainer.new()
	_upgrade_rows.columns = 2
	_upgrade_rows.add_theme_constant_override("h_separation", 16)
	content.add_child(_upgrade_rows)
	var hint := Label.new()
	hint.text = "Los niveles se pierden al terminar la partida."
	hint.add_theme_color_override("font_color", QuestPalette.UI_TEXT_MUTED)
	hint.add_theme_font_size_override("font_size", 13)
	content.add_child(hint)
	_level_button = Button.new()
	_level_button.pressed.connect(_on_level_up_pressed)
	content.add_child(_level_button)

	content.add_child(HSeparator.new())
	_found_title = Label.new()
	_found_title.add_theme_color_override("font_color", QuestPalette.GOLD)
	content.add_child(_found_title)
	_found_rows = VBoxContainer.new()
	content.add_child(_found_rows)


func _on_level_up_pressed() -> void:
	var ps := ManagerLocator.get_player_stats()
	if ps and stats:
		ps.level_up_hero(stats.hero_id)


func _on_veil_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


## Sprite idle frame > portrait > nothing (the frame stays as placeholder).
func _preview_texture() -> Texture2D:
	if character_data == null:
		return null
	var frames := character_data.sprite_frames
	if frames and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		return frames.get_frame_texture("idle", 0)
	return character_data.portrait


# ---------------- REFRESH ----------------

func _refresh() -> void:
	if not visible or stats == null:
		return
	var ps := ManagerLocator.get_player_stats()
	var level: int = ps.get_hero_level(stats.hero_id) if ps else 1
	_title.text = character_data.display_name if character_data else stats.character_name

	var lines: Array[String] = [
		"Nivel %d" % level,
		"Vida: %d / %d" % [stats.current_hp, stats.max_hp],
		"Ataque: %d de daño" % stats.attack_damage,
		"Intervalo: %.2f s (%.2f golpes/s)" % [stats.attack_interval, 1.0 / maxf(stats.attack_interval, 0.01)],
	]
	if character_data:
		if character_data.passive_ability_name != "":
			lines.append("Pasiva: %s" % character_data.passive_ability_name)
		if character_data.active_ability_name != "":
			lines.append("Activa: %s" % character_data.active_ability_name)
	_info.text = "\n".join(lines)

	if ps:
		_rebuild_level_up(ps)
		_rebuild_found_items(ps)


func _rebuild_level_up(ps: PlayerStats) -> void:
	for child in _upgrade_rows.get_children():
		_upgrade_rows.remove_child(child)
		child.queue_free()

	var p: Dictionary = ps.get_level_up_preview(stats.hero_id)
	var maxed: bool = p["maxed"]
	var affordable: bool = p["affordable"]
	var resource_label := str(Module.RESOURCE_LABELS.get(p["cost_resource"], p["cost_resource"]))
	_level_title.text = "Nivel máximo (%d)" % p["level"] if maxed else "Subir de nivel: %d → %d" % [p["level"], p["next_level"]]
	for row: Dictionary in p["rows"]:
		var key := str(row["key"])
		_add_cell(str(row["label"]), QuestPalette.PARCHMENT)
		var values := _format_value(key, row["current"]) if maxed else "%s → %s" % [_format_value(key, row["current"]), _format_value(key, row["next"])]
		_add_cell(values, QuestPalette.UI_TEXT_PRIMARY)

	_level_button.disabled = maxed or not affordable
	_level_button.text = "Nivel máximo" if maxed else "Subir de nivel (%d %s)" % [p["cost"], resource_label]
	_level_button.tooltip_text = "" if maxed or affordable else "%s insuficiente" % resource_label
	_level_button.add_theme_color_override("font_color", StatIcon.BASE_COLORS.get(p["cost_resource"], QuestPalette.PARCHMENT) if affordable else QuestPalette.UI_TEXT_BLOCKED)


## Objetos hallados en cofres: solo lectura (aún no hay sistema de equipo).
func _rebuild_found_items(ps: PlayerStats) -> void:
	for child in _found_rows.get_children():
		_found_rows.remove_child(child)
		child.queue_free()
	_found_title.text = "Hallazgos (%d)" % ps.found_items.size() if not ps.found_items.is_empty() else "Hallazgos: ninguno todavía"
	for item in ps.found_items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s (%s) %s" % [item.display_name, ItemData.RARITY_LABELS[item.rarity], item.describe_modifiers()]
		label.add_theme_color_override("font_color", ItemData.RARITY_COLORS[item.rarity])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_found_rows.add_child(row)


func _add_cell(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	_upgrade_rows.add_child(label)


static func _format_value(key: String, value: Variant) -> String:
	return "%.2f s" % float(value) if key == "attack_speed" else str(int(value))

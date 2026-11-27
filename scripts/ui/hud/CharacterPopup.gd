extends Control
class_name CharacterPopup

## CharacterPopup: modal hero sheet opened by clicking a HeroPortrait. Full-rect
## veil (click = close) + centered panel: preview, name, level, exact HP, combat
## stats from CharacterStats/CharacterData, an "Equipo" section (EquipmentSection)
## and a "Subir de nivel" section:
## next level, Comida cost and what each stat gains (PlayerStats.get_level_up_
## preview → level_up_hero, for this popup's hero — not necessarily the
## active one; the UI computes nothing). Closes with the
## X button, a click outside, or Esc — Esc is consumed here, so it never also
## toggles the pause menu (HUD's _input runs before Main2d's).
## heroes-9: a stats table split by layer (base | nivel | perks | equipo | total,
## PlayerStats.get_stat_breakdown), the passive/active with icon and their real
## description (AbilityData via HeroAbilities.describe), green "-> next" values
## in the level-up rows, and Reanimar instead of Curar for a downed hero.
## Built in code by HUDController; refreshes on signals only.

const PREVIEW_SIZE := Vector2(128, 128)
const STAT_COLUMNS := ["Atributo", "Base", "Nivel", "Mejoras", "Equipo", "Total"]
const ABILITY_ICON := Vector2(32, 32)
const NEXT_COLOR := Color(0.5, 0.95, 0.55)
## Tallest the sheet gets (base viewport 1080) before it scrolls.
const MAX_CONTENT_HEIGHT := 960.0

var stats: CharacterStats
var character_data: CharacterData

var _title: Label
var _preview: TextureRect
var _info: Label
var _stat_table: GridContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _ability_rows: VBoxContainer
var _level_title: Label
var _upgrade_rows: GridContainer
var _level_button: Button
var _heal_button: Button
var _perk_title: Label
var _perk_rows: VBoxContainer
var _equipment_title: Label
var _equipment: EquipmentSection


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()

	var ps := ManagerLocator.get_player_stats()
	if ps:
		ps.stats_changed.connect(func(_s: CharacterStats) -> void: _refresh())
		ps.run_upgrades_changed.connect(func(_k: String, _l: int, _id: String) -> void: _refresh())
		ps.perk_chosen.connect(func(_id: String, _perk: StringName) -> void: _refresh())
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

## personajes-46 (owner's pick of 2 mockups, "Libro abierto"): a menu frame with two columns, the
## hero, Atributos and Habilidades on the left; level-up, Curar, class perks and Equipo on the right.
const PANEL_WIDTH := 1000.0
const COLUMN_WIDTH := 470.0


func _build() -> void:
	theme = UiStyles.menu_font_theme()
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
	panel.name = "Frame"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyles.style_menu_frame(panel, 22)
	center.add_child(panel)

	# Scrolls when the sheet outgrows the screen (big text, perk cards + full equipment).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	var header := HBoxContainer.new()
	_content.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyles.style_menu_title(_title, 30)
	header.add_child(_title)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Cerrar (Esc)"
	close_button.pressed.connect(close)
	UiStyles.style_menu_button(close_button)
	header.add_child(close_button)
	UiStyles.add_ornament_after(header)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 14)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyles.build_inset_style(6))
	hero_row.add_child(frame)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = PREVIEW_SIZE
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_preview)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyles.style_menu_text(_info, 18, QuestPalette.PARCHMENT_LIGHT)
	hero_row.add_child(_info)

	_stat_table = GridContainer.new()
	_stat_table.name = "StatTable"
	_stat_table.columns = STAT_COLUMNS.size()
	_stat_table.add_theme_constant_override("h_separation", 14)
	_ability_rows = VBoxContainer.new()
	_ability_rows.name = "Abilities"
	_ability_rows.add_theme_constant_override("separation", 8)

	var level_box := VBoxContainer.new()
	level_box.add_theme_constant_override("separation", 8)
	_level_title = _section_label("")
	level_box.add_child(_level_title)
	_upgrade_rows = GridContainer.new()
	_upgrade_rows.columns = 4
	_upgrade_rows.add_theme_constant_override("h_separation", 16)
	level_box.add_child(_upgrade_rows)
	var hint := Label.new()
	hint.text = "Los niveles se pierden al terminar la partida."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyles.style_menu_text(hint, 14, QuestPalette.UI_TEXT_MUTED)
	level_box.add_child(hint)
	_level_button = Button.new()
	_level_button.pressed.connect(_on_level_up_pressed)
	UiStyles.style_plaque_button(_level_button, false, 20, false)
	level_box.add_child(_level_button)
	_heal_button = Button.new()
	_heal_button.pressed.connect(_on_heal_pressed)
	UiStyles.style_plaque_button(_heal_button, false, 18, false)
	level_box.add_child(_heal_button)

	var perk_box := VBoxContainer.new()
	perk_box.add_theme_constant_override("separation", 8)
	_perk_title = _section_label("")
	perk_box.add_child(_perk_title)
	_perk_rows = VBoxContainer.new()
	_perk_rows.add_theme_constant_override("separation", 6)
	perk_box.add_child(_perk_rows)
	_equipment_title = _section_label("Equipo")
	perk_box.add_child(_equipment_title)
	_equipment = EquipmentSection.new()
	perk_box.add_child(_equipment)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	_content.add_child(columns)
	var left := _column([hero_row, _section_label("Atributos"), _stat_table, _section_label("Habilidades"), _ability_rows])
	columns.add_child(left)
	columns.add_child(VSeparator.new())
	columns.add_child(_column([level_box, HSeparator.new(), perk_box]))


func _column(children: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child: Control in children:
		column.add_child(child)
	return column


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	UiStyles.style_menu_text(label, 20, QuestPalette.RELIC_GOLD_PALE)
	return label


func _on_level_up_pressed() -> void:
	var ps := ManagerLocator.get_player_stats()
	if ps and stats:
		ManagerLocator.get_net_commands().request("level_up", {"hero": stats.hero_id})


func _on_heal_pressed() -> void:
	var ps := ManagerLocator.get_player_stats()
	if ps and stats:
		ManagerLocator.get_net_commands().request("heal" if stats.is_alive() else "revive", {"hero": stats.hero_id})


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

	var ranged := character_data != null and character_data.attack_style == CharacterData.AttackStyle.RANGED
	var lines: Array[String] = [
		"Nivel %d" % level,
		"Vida: %d / %d%s" % [stats.current_hp, stats.max_hp, "  (caído)" if not stats.is_alive() else ""],
		"%.2f golpes/s · %s" % [1.0 / maxf(stats.attack_interval, 0.01), "a distancia" if ranged else "cuerpo a cuerpo"],
	]
	if character_data and not is_equal_approx(character_data.move_speed_mult, 1.0):
		lines.append("Velocidad: x%.2f" % character_data.move_speed_mult)
	if character_data and character_data.role != "":
		lines.append(character_data.role)
	_info.text = "\n".join(lines)

	if ps:
		_rebuild_stat_table(ps)
		_rebuild_abilities()
		_rebuild_level_up(ps)
		_rebuild_perks(ps)
	_equipment.bind(stats.hero_id)
	_fit_height.call_deferred()


## As tall as the content, up to MAX_CONTENT_HEIGHT (then it scrolls).
func _fit_height() -> void:
	if _content == null:
		return
	_scroll.custom_minimum_size = Vector2(PANEL_WIDTH, minf(_content.get_combined_minimum_size().y, MAX_CONTENT_HEIGHT))


func _rebuild_level_up(ps: PlayerStats) -> void:
	for child in _upgrade_rows.get_children():
		_upgrade_rows.remove_child(child)
		child.queue_free()

	var p: Dictionary = ps.get_level_up_preview(stats.hero_id)
	var maxed: bool = p["maxed"]
	var affordable: bool = p["affordable"]
	var resource_label := str(Building.RESOURCE_LABELS.get(p["cost_resource"], p["cost_resource"]))
	_level_title.text = "Nivel máximo (%d)" % p["level"] if maxed else "Subir de nivel: %d → %d" % [p["level"], p["next_level"]]
	for row: Dictionary in p["rows"]:
		var key := str(row["key"])
		_cell(_upgrade_rows, str(row["label"]), QuestPalette.PARCHMENT)
		_cell(_upgrade_rows, _format_value(key, row["current"]), QuestPalette.UI_TEXT_PRIMARY)
		_cell(_upgrade_rows, "" if maxed else "→", QuestPalette.UI_TEXT_MUTED)
		var changed: bool = not maxed and _format_value(key, row["next"]) != _format_value(key, row["current"])
		_cell(_upgrade_rows, "" if maxed else _format_value(key, row["next"]), NEXT_COLOR if changed else QuestPalette.UI_TEXT_PRIMARY)

	_level_button.disabled = maxed or not affordable
	_level_button.text = "Nivel máximo" if maxed else "Subir de nivel (%d %s)" % [p["cost"], resource_label]
	var alt_label := str(Building.RESOURCE_LABELS.get(p["alt_resource"], p["alt_resource"]))
	_level_button.tooltip_text = "" if maxed or affordable else ("Faltan %d %s o %d %s" % [p["cost"], resource_label, p["alt_cost"], alt_label] if int(p["alt_cost"]) > 0 else "%s insuficiente" % resource_label)
	if not stats.is_alive():  # downed: the same button revives (an ally in its room + Comida)
		var reason: String = ps.get_revive_block_reason(stats.hero_id)
		_heal_button.disabled = reason != ""
		_heal_button.text = "Reanimar (%d %s)" % [ps.get_revive_cost(stats.hero_id), resource_label]
		_heal_button.tooltip_text = reason
	else:
		var heal_cost: int = ps.get_heal_cost(stats.hero_id) if ps else 0
		var heal_affordable: bool = ManagerLocator.get_resource_manager().get_resource("food") >= heal_cost
		_heal_button.disabled = heal_cost <= 0 or not heal_affordable
		_heal_button.text = "Vida completa" if heal_cost <= 0 else "Curar (%d %s)" % [heal_cost, resource_label]
		_heal_button.tooltip_text = "" if heal_cost <= 0 or heal_affordable else "%s insuficiente" % resource_label
	_level_button.add_theme_color_override("font_color", StatIcon.BASE_COLORS.get(p["cost_resource"], QuestPalette.PARCHMENT) if affordable else QuestPalette.UI_TEXT_BLOCKED)


## "Mejoras de clase": perks already picked (tooltip = description) and, when a
## level just unlocked one, the two cards to choose from. PlayerStats decides what is on offer.
func _rebuild_perks(ps: PlayerStats) -> void:
	for child in _perk_rows.get_children():
		_perk_rows.remove_child(child)
		child.queue_free()
	var picked := ps.get_perks_of(stats.hero_id)
	var pending := ps.get_pending_perk_choices(stats.hero_id)
	var has_perks: bool = character_data != null and not character_data.perks.is_empty()
	if not has_perks:
		_perk_title.text = ""
		return
	_perk_title.text = "Mejoras de clase (%d / %d)" % [picked.size(), character_data.perks.size() / 2]
	for perk in picked:
		var label := Label.new()
		label.text = "✔ %s — %s" % [perk.display_name, perk.describe_mods()]
		label.tooltip_text = perk.description
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.add_theme_color_override("font_color", QuestPalette.PARCHMENT_LIGHT)
		_perk_rows.add_child(label)
	if not pending.is_empty():
		var offer := Label.new()
		offer.text = "¡Elige una mejora!"
		offer.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT)
		_perk_rows.add_child(offer)
		for perk in pending:
			_perk_rows.add_child(_make_perk_card(perk))
	elif picked.is_empty():
		var hint := Label.new()
		hint.text = "Se desbloquea al llegar a nivel %d." % _next_perk_level()
		hint.add_theme_color_override("font_color", QuestPalette.UI_TEXT_MUTED)
		hint.add_theme_font_size_override("font_size", Accessibility.font(13))
		_perk_rows.add_child(hint)


func _next_perk_level() -> int:
	var lowest := 99
	for perk in character_data.perks:
		lowest = mini(lowest, perk.unlock_level)
	return lowest


func _make_perk_card(perk: HeroPerk) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyles.build_panel_style(QuestPalette.DUNGEON_STONE, QuestPalette.GOLD_DARK, 2, 6, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = "%s  (%s)" % [perk.display_name, perk.describe_mods()]
	name_label.add_theme_color_override("font_color", QuestPalette.GOLD)
	text.add_child(name_label)
	var description := Label.new()
	description.text = perk.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	description.add_theme_font_size_override("font_size", Accessibility.font(13))
	text.add_child(description)
	var button := Button.new()
	button.text = "Elegir"
	button.pressed.connect(_on_perk_pressed.bind(perk.id))
	row.add_child(button)
	return card


func _on_perk_pressed(perk_id: StringName) -> void:
	var ps := ManagerLocator.get_player_stats()
	if ps and stats:
		ManagerLocator.get_net_commands().request("choose_perk", {"hero": stats.hero_id, "perk": String(perk_id)})


## base | nivel | perks | equipo | total per stat (PlayerStats.get_stat_breakdown).
## A zero layer shows "-"; bonuses are signed ("+2", "-0.10").
func _rebuild_stat_table(ps: PlayerStats) -> void:
	for child in _stat_table.get_children():
		_stat_table.remove_child(child)
		child.queue_free()
	for title: String in STAT_COLUMNS:
		_cell(_stat_table, title, QuestPalette.GOLD)
	for row: Dictionary in ps.get_stat_breakdown(stats.hero_id):
		var key := str(row["key"])
		_cell(_stat_table, str(row["label"]), QuestPalette.PARCHMENT)
		_cell(_stat_table, _format_stat(key, row["base"], false), QuestPalette.UI_TEXT_PRIMARY)
		for layer in ["level", "perks", "equipment"]:
			_cell(_stat_table, _format_stat(key, row[layer], true), NEXT_COLOR if float(row[layer]) != 0.0 else QuestPalette.UI_TEXT_MUTED)
		_cell(_stat_table, _format_stat(key, row["total"], false), QuestPalette.GOLD_LIGHT)


func _cell(parent: Control, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


static func _format_stat(key: String, value: Variant, signed: bool) -> String:
	var v := float(value)
	if signed and is_zero_approx(v):
		return "-"
	var text := "%.2f" % v if key == "attack_interval" else str(roundi(v))
	return ("+" + text) if signed and v > 0.0 else text


## Passive + active: icon, name, kind and the real description (numbers with perks).
func _rebuild_abilities() -> void:
	for child in _ability_rows.get_children():
		_ability_rows.remove_child(child)
		child.queue_free()
	var player := stats.get_parent() as Player
	var abilities: HeroAbilities = player.abilities if player else null
	var passive: AbilityData = character_data.passive if character_data else null
	var active: AbilityData = character_data.active if character_data else null
	for entry in [[passive, "Pasiva"], [active, "Activa (Q)"]]:
		var ability: AbilityData = entry[0]
		if ability == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = ability.icon
		icon.custom_minimum_size = ABILITY_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var text := Label.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(COLUMN_WIDTH - 60.0, 0)
		var description: String = abilities.describe(ability) if abilities else ability.format_description()
		text.text = "%s — %s\n%s" % [entry[1], ability.display_name, description]
		text.add_theme_color_override("font_color", QuestPalette.PARCHMENT_LIGHT)
		row.add_child(text)
		_ability_rows.add_child(row)


## Plain text of the abilities block (tests).
func get_abilities_text() -> String:
	var parts: Array[String] = []
	for row in _ability_rows.get_children():
		for child in row.get_children():
			if child is Label:
				parts.append(child.text)
	return "\n".join(parts)


static func _format_value(key: String, value: Variant) -> String:
	return "%.2f s" % float(value) if key == "attack_speed" else str(int(value))

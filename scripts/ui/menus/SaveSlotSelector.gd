extends Control
class_name SaveSlotSelector

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")
const EMPTY_SLOT_TEXT := "No hay datos guardados."


signal slot_selected(slot_id: int)
signal back_pressed

const SAVE_SECTION := "save_data"

var _style_source: Button
var _click_sound: AudioStreamPlayer
var _hover_sound: AudioStreamPlayer
var _slot_count: int = 3

var _slot_root: VBoxContainer
var _hover_panel: PanelContainer
var _hover_label: Label
var _info_text: String = ""
var _info_visible: bool = false

func setup(style_source: Button, click_sound: AudioStreamPlayer, hover_sound: AudioStreamPlayer, slot_count: int = 3) -> void:
	_style_source = style_source
	_click_sound = click_sound
	_hover_sound = hover_sound
	_slot_count = slot_count
	if is_inside_tree():
		_build_ui()

func _ready() -> void:
	if _style_source:
		_build_ui()

func refresh() -> void:
	_build_ui()

# ---------------- UI ----------------

func _build_ui() -> void:
	var previous_info_text := _info_text
	var previous_info_visible := _info_visible
	var save_mgr := ManagerLocator.get_save_manager()

	for child in get_children():
		child.queue_free()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root_center := CenterContainer.new()
	root_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root_center)

	_slot_root = VBoxContainer.new()
	_slot_root.custom_minimum_size = Vector2(900, 720)
	_slot_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_root.add_theme_constant_override("separation", 24)
	root_center.add_child(_slot_root)

	var slot_vbox := VBoxContainer.new()
	slot_vbox.custom_minimum_size = Vector2(560, 560)
	slot_vbox.add_theme_constant_override("separation", 36)
	slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_root.add_child(slot_vbox)

	var title := Label.new()
	title.text = "SELECCIONAR RANURA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.62, 1))
	slot_vbox.add_child(title)

	for i in range(1, _slot_count + 1):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		slot_vbox.add_child(row)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(400, 100)
		btn.text = "RANURA %d" % i
		if save_mgr and save_mgr.has_save(i):
			btn.text += " (GUARDADA)"
		else:
			btn.text += " (VACIA)"

		_apply_primary_button_style(btn)
		btn.pressed.connect(_on_slot_selected.bind(i))
		btn.mouse_entered.connect(_on_slot_hovered.bind(i))
		btn.focus_entered.connect(_on_slot_hovered.bind(i))
		btn.mouse_entered.connect(_play_hover)
		btn.focus_entered.connect(_play_hover)
		row.add_child(btn)

		var del_btn := Button.new()
		del_btn.custom_minimum_size = Vector2(80, 100)
		del_btn.text = "X"
		del_btn.add_theme_font_size_override("font_size", 34)
		del_btn.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1))
		del_btn.add_theme_color_override("font_hover_color", Color(1, 0.4, 0.4, 1))
		_apply_primary_button_style(del_btn)
		del_btn.pressed.connect(_on_slot_deleted.bind(i))
		del_btn.mouse_entered.connect(_play_hover)

		if not (save_mgr and save_mgr.has_save(i)):
			del_btn.disabled = true
			del_btn.modulate.a = 0.5

		row.add_child(del_btn)

	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(400, 100)
	back_btn.text = "VOLVER"
	_apply_primary_button_style(back_btn)
	back_btn.pressed.connect(_on_slot_back_pressed)
	back_btn.mouse_entered.connect(_play_hover)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_child(back_btn)
	slot_vbox.add_child(margin)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_top", 24)
	_slot_root.add_child(info_margin)

	var info_center := CenterContainer.new()
	info_margin.add_child(info_center)

	_hover_panel = PanelContainer.new()
	_hover_panel.custom_minimum_size = Vector2(640, 220)
	_hover_panel.visible = previous_info_visible
	info_center.add_child(_hover_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 20)
	panel_margin.add_theme_constant_override("margin_top", 20)
	panel_margin.add_theme_constant_override("margin_right", 20)
	panel_margin.add_theme_constant_override("margin_bottom", 20)
	_hover_panel.add_child(panel_margin)

	var panel_vbox := VBoxContainer.new()
	panel_margin.add_child(panel_vbox)

	_hover_label = Label.new()
	_hover_label.text = previous_info_text
	_hover_label.add_theme_font_size_override("font_size", 24)
	_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_vbox.add_child(_hover_label)

	_info_text = previous_info_text
	_info_visible = previous_info_visible

func _apply_primary_button_style(button: Button) -> void:
	if not _style_source:
		return

	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_stylebox_override("normal", _style_source.get_theme_stylebox("normal"))
	button.add_theme_stylebox_override("pressed", _style_source.get_theme_stylebox("pressed"))
	button.add_theme_stylebox_override("hover", _style_source.get_theme_stylebox("hover"))
	button.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42, 1))

# ---------------- AUDIO ----------------

func _play_click() -> void:
	if _click_sound and _click_sound.stream:
		_click_sound.play()

func _play_hover() -> void:
	if _hover_sound and _hover_sound.stream:
		_hover_sound.play()

# ---------------- EVENTS ----------------

func _on_slot_deleted(slot_id: int) -> void:
	_play_click()
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.delete_save(slot_id)
	_info_text = ""
	_info_visible = false
	refresh()

func _on_slot_hovered(slot_id: int) -> void:

	var summary := _get_slot_summary(slot_id)

	if summary.is_empty():
		return

	_info_text = summary
	_info_visible = true

	if _hover_panel:
		_hover_panel.visible = true

	if _hover_label:
		_hover_label.text = summary
func _on_slot_selected(slot_id: int) -> void:
	_play_click()
	slot_selected.emit(slot_id)

func _on_slot_back_pressed() -> void:
	_play_click()
	back_pressed.emit()

func _get_slot_summary(slot_id: int) -> String:

	var save_mgr := ManagerLocator.get_save_manager()

	if not save_mgr:
		return ""

	if not save_mgr.has_save(slot_id):
		return EMPTY_SLOT_TEXT

	var cfg := ConfigFile.new()

	var err := cfg.load(
		save_mgr.get_save_path(slot_id)
	)

	if err != OK:
		return "No se pudieron leer los datos."

	return _build_slot_summary(
		slot_id,
		cfg
	)


func _build_slot_summary(
	slot_id: int,
	cfg: ConfigFile
) -> String:

	var gold = cfg.get_value(
		SAVE_SECTION,
		"gold",
		0
	)

	var contracts = cfg.get_value(
		SAVE_SECTION,
		"contracts_completed",
		0
	)

	var s_hp = cfg.get_value(
		SAVE_SECTION,
		"base_hp",
		StatBalance.PLAYER_BASE_HP
	)

	var s_str = cfg.get_value(
		SAVE_SECTION,
		"base_str",
		0
	)

	var s_mag = cfg.get_value(
		SAVE_SECTION,
		"base_mag",
		0
	)

	var s_dex = cfg.get_value(
		SAVE_SECTION,
		"base_dex",
		0
	)

	var max_stat_name :	= "Fuerza"
	var max_stat_val = s_str

	if s_mag > max_stat_val:
		max_stat_name = "Magia"
		max_stat_val = s_mag

	if s_dex > max_stat_val:
		max_stat_name = "Destreza"
		max_stat_val = s_dex

	return (
		"Datos de la ranura %d:\n\n" +
		"Oro total: %d\n" +
		"Etapa de contrato: %d\n" +
		"Vida base: %d/%d\n" +
		"Mejor atributo: %s (+%d)"
	) % [
		slot_id,
		gold,
		contracts,
		s_hp,
		StatBalance.PLAYER_MAX_HP,
		max_stat_name,
		max_stat_val
	]


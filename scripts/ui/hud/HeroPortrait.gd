extends PanelContainer
class_name HeroPortrait

## HeroPortrait: one hero in the HUD's top-right Portraits column. Portrait
## texture (idle sprite frame, else CharacterData.portrait) or a placeholder circle with the initial,
## name, and an HP bar driven by CharacterStats.hp_changed — no numbers (the
## exact value lives in CharacterPopup). Bar color/timings: HealthBarStyle.
## The selected hero gets a bright gold border (set_selected, session 12).
## Built in code; `setup()` before add_child().

## Static style helper via preload (the ThemeManager autoload identifier is
## missing in --script test runs).
const ThemeStyles = preload("res://scripts/core/theme/ThemeManager.gd")

signal portrait_clicked(portrait: HeroPortrait)
## Ctrl + left click: add/remove this hero from the selection.
signal portrait_ctrl_clicked(portrait: HeroPortrait)
## Right click: open this hero's sheet without selecting it.
signal portrait_right_clicked(portrait: HeroPortrait)

const DEFAULT_STYLE: HealthBarStyle = preload("res://resources/ui/health_bar_style.tres")
const ICON_SIZE := Vector2(56, 56)
const BAR_SIZE := Vector2(120, 12)
const INITIAL_BG := Color(0.25, 0.2, 0.16, 1.0)
const PANEL_BG := Color(0.05, 0.05, 0.06, 0.8)
const BORDER_WIDTH := 2
const SELECTED_BORDER_WIDTH := 4

var style: HealthBarStyle = DEFAULT_STYLE
var stats: CharacterStats
var character_data: CharacterData
## Fill fraction the bar is heading to (tests read this; `_bar.value` tweens).
var target_ratio: float = 1.0
## Selected (active) hero: gold border.
var is_selected: bool = false

var _group_label: Label
var _group_nums: Array = []
var _bar: ProgressBar
var _ability_bar: ProgressBar
var _abilities: HeroAbilities
var _fill: StyleBoxFlat
var _last_hp: int = -1
var _bar_tween: Tween
var _flash_tween: Tween


func setup(p_stats: CharacterStats, p_data: CharacterData) -> void:
	character_data = p_data
	if is_node_ready():
		bind_stats(p_stats)
	else:
		stats = p_stats


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Clic: seleccionar (si ya está elegido, ver ficha)\nCtrl+clic: agregar/quitar de la selección\nClic derecho: ver ficha"
	_apply_panel_style()

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	row.add_child(_make_icon())

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_row)
	var name_label := Label.new()
	name_label.text = character_data.display_name if character_data else "Héroe"
	name_label.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	name_row.add_child(name_label)
	_group_label = Label.new()
	_group_label.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT)
	name_row.add_child(_group_label)
	set_groups(_group_nums)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill = StyleBoxFlat.new()
	var background := StyleBoxFlat.new()
	background.bg_color = style.background_color
	_bar.add_theme_stylebox_override("fill", _fill)
	_bar.add_theme_stylebox_override("background", background)
	column.add_child(_bar)

	# Thin Q-ability bar: gold = ready, dim = recharging.
	_ability_bar = ProgressBar.new()
	_ability_bar.custom_minimum_size = Vector2(BAR_SIZE.x, 4)
	_ability_bar.show_percentage = false
	_ability_bar.max_value = 1.0
	_ability_bar.step = 0.0
	_ability_bar.value = 1.0
	_ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ability_fill := StyleBoxFlat.new()
	ability_fill.bg_color = QuestPalette.GOLD_LIGHT
	_ability_bar.add_theme_stylebox_override("fill", ability_fill)
	_ability_bar.add_theme_stylebox_override("background", StyleBoxFlat.new())
	_ability_bar.visible = false
	column.add_child(_ability_bar)

	gui_input.connect(_on_gui_input)
	bind_stats(stats)
	if _abilities:
		bind_abilities(_abilities)


## Shows the hero's active-ability cooldown (Q) under the HP bar.
func bind_abilities(p_abilities: HeroAbilities) -> void:
	_abilities = p_abilities
	if _ability_bar == null or p_abilities == null or p_abilities.active == null:
		return
	_ability_bar.visible = true
	_ability_bar.tooltip_text = "%s (Q)" % p_abilities.ability_name
	if not p_abilities.cooldown_changed.is_connected(_on_cooldown_changed):
		p_abilities.cooldown_changed.connect(_on_cooldown_changed)
	_on_cooldown_changed(p_abilities.cooldown_left, p_abilities.active.cooldown)


func _on_cooldown_changed(left: float, total: float) -> void:
	_ability_bar.value = 1.0 - left / maxf(total, 0.001)
	_ability_bar.modulate = Color.WHITE if left <= 0.0 else Color(1, 1, 1, 0.45)


func bind_stats(p_stats: CharacterStats) -> void:
	if stats and stats != p_stats and stats.hp_changed.is_connected(_on_hp_changed):
		stats.hp_changed.disconnect(_on_hp_changed)
	stats = p_stats
	_last_hp = -1
	if stats == null:
		return
	if not stats.hp_changed.is_connected(_on_hp_changed):
		stats.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(stats.current_hp, stats.max_hp)


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	target_ratio = HealthBarStyle.ratio_of(current_hp, max_hp)
	var color := style.color_for(target_ratio)
	var first := _last_hp < 0
	var took_damage := not first and current_hp < _last_hp
	_last_hp = current_hp

	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()
	if first or not is_inside_tree():
		_bar.value = target_ratio
		_fill.bg_color = color
	else:
		_bar_tween = create_tween().set_parallel()
		_bar_tween.tween_property(_bar, "value", target_ratio, style.tween_time)
		_bar_tween.tween_property(_fill, "bg_color", color, style.tween_time)

	if took_damage and is_inside_tree():
		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		modulate = style.flash_color
		_flash_tween = create_tween()
		_flash_tween.tween_property(self, "modulate", Color.WHITE, style.flash_time)


## Control groups this hero belongs to, shown next to the name ("[1] [3]").
func set_groups(nums: Array) -> void:
	_group_nums = nums
	if _group_label:
		var parts: Array[String] = []
		for n in nums:
			parts.append("[%d]" % n)
		_group_label.text = " " + " ".join(parts) if not parts.is_empty() else ""


func set_selected(value: bool) -> void:
	is_selected = value
	if is_node_ready():
		_apply_panel_style()


func _apply_panel_style() -> void:
	var border := QuestPalette.GOLD_LIGHT if is_selected else QuestPalette.GOLD_DARK
	var width := SELECTED_BORDER_WIDTH if is_selected else BORDER_WIDTH
	add_theme_stylebox_override("panel", ThemeStyles.build_panel_style(PANEL_BG, border, width, 6, 6))


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.ctrl_pressed:
			portrait_ctrl_clicked.emit(self)
		else:
			portrait_clicked.emit(self)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		portrait_right_clicked.emit(self)
		accept_event()


## Idle sprite frame (pixel art, shown enlarged with Nearest) > portrait PNG > nothing.
func _icon_texture() -> Texture2D:
	if character_data == null:
		return null
	var frames := character_data.sprite_frames
	if frames and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		return frames.get_frame_texture("idle", 0)
	return character_data.portrait


func _make_icon() -> Control:
	var texture := _icon_texture()
	if texture:
		var texture_rect := TextureRect.new()
		texture_rect.texture = texture
		texture_rect.custom_minimum_size = ICON_SIZE
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return texture_rect
	var icon := Control.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var initial := (character_data.display_name if character_data else "?").left(1).to_upper()
	icon.draw.connect(_draw_initial.bind(icon, initial))
	return icon


static func _draw_initial(icon: Control, initial: String) -> void:
	var radius := minf(icon.size.x, icon.size.y) * 0.5
	var center := icon.size * 0.5
	icon.draw_circle(center, radius, INITIAL_BG)
	icon.draw_arc(center, radius - 1.0, 0.0, TAU, 32, QuestPalette.GOLD_DARK, 2.0)
	var font := ThemeDB.fallback_font
	var font_size := int(radius)
	var text_size := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	icon.draw_string(font, center + Vector2(-text_size.x * 0.5, text_size.y * 0.3), initial, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, QuestPalette.PARCHMENT)

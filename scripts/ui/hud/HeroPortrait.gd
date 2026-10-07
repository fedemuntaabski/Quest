extends PanelContainer
class_name HeroPortrait

## HeroPortrait: one hero in the HUD's top-right Portraits column. Portrait
## texture (idle sprite frame, else CharacterData.portrait) or a placeholder circle with the initial,
## name, and an HP bar driven by CharacterStats.hp_changed — no numbers (the
## exact value lives in CharacterPopup). Bar color/timings: HealthBarStyle.
## The selected hero gets a bright gold border (set_selected, session 12).
## Under the bars: the active ability (AbilityButton: icon, radial cooldown,
## "ready" pulse; click = Q) and one small button per equipped consumable
## (click = use it, dimmed while it cools down; InventoryComponent decides).
## heroes-9: the bar blinks below HealthBarStyle.low_threshold; a downed hero
## turns grey with a "Reanimar (N Comida)" button (PlayerStats.revive_hero).
## Built in code; `setup()` before add_child().

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
var _perk_dot: Label
var _group_nums: Array = []
var _bar: ProgressBar
var ability_button: AbilityButton
var revive_button: Button
var _low_tween: Tween
var _downed_label: Label
var _icon: Control
var _abilities: HeroAbilities
var _inventory: InventoryComponent
var _consumable_buttons: Array[Button] = []
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
	_icon = _make_icon()
	row.add_child(_icon)

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
	# Gold dot: a class perk is waiting to be chosen (open the sheet).
	_perk_dot = Label.new()
	_perk_dot.text = " ●"
	_perk_dot.tooltip_text = "Hay una mejora de clase para elegir (clic derecho: ver ficha)"
	_perk_dot.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT)
	_perk_dot.mouse_filter = Control.MOUSE_FILTER_PASS
	_perk_dot.visible = false
	name_row.add_child(_perk_dot)
	var player_stats := ManagerLocator.get_player_stats()
	if player_stats:
		player_stats.run_upgrades_changed.connect(func(_k: String, _l: int, _id: String) -> void: _update_perk_dot())
		player_stats.perk_chosen.connect(func(_id: String, _perk: StringName) -> void: _update_perk_dot())

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # the Reanimar button must not stretch it
	_fill = StyleBoxFlat.new()
	var background := StyleBoxFlat.new()
	background.bg_color = style.background_color
	_bar.add_theme_stylebox_override("fill", _fill)
	_bar.add_theme_stylebox_override("background", background)
	column.add_child(_bar)

	_downed_label = Label.new()
	_downed_label.text = "Caído"
	_downed_label.add_theme_color_override("font_color", QuestPalette.BLOOD_LIGHT)
	_downed_label.visible = false
	name_row.add_child(_downed_label)

	var consumables := HBoxContainer.new()
	consumables.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(consumables)
	ability_button = AbilityButton.new()
	ability_button.name = "AbilityButton"
	consumables.add_child(ability_button)
	revive_button = Button.new()
	revive_button.name = "ReviveButton"
	revive_button.focus_mode = Control.FOCUS_NONE
	revive_button.visible = false
	revive_button.pressed.connect(_on_revive_pressed)
	column.add_child(revive_button)
	var party := ManagerLocator.get_party_inventory()
	for index in int(party.SLOT_CAPACITY[ItemData.Slot.CONSUMABLE]) if party else 2:
		var button := Button.new()
		button.custom_minimum_size = Vector2(28, 28)
		button.expand_icon = true
		button.focus_mode = Control.FOCUS_NONE
		button.visible = false
		button.pressed.connect(_on_consumable_pressed.bind(index))
		consumables.add_child(button)
		_consumable_buttons.append(button)

	gui_input.connect(_on_gui_input)
	bind_stats(stats)
	_update_perk_dot()
	if _abilities:
		bind_abilities(_abilities)
	if _inventory:
		bind_inventory(_inventory)


func has_pending_perk() -> bool:
	return _perk_dot != null and _perk_dot.visible


func _update_perk_dot() -> void:
	var player_stats := ManagerLocator.get_player_stats()
	_perk_dot.visible = player_stats != null and stats != null and stats.hero_id != "" and player_stats.has_pending_perk(stats.hero_id)


## Shows the hero's active ability (button with radial cooldown, Q).
func bind_abilities(p_abilities: HeroAbilities) -> void:
	_abilities = p_abilities
	if ability_button and p_abilities:
		ability_button.bind(p_abilities)


## Shortcut buttons for the hero's equipped consumables.
func bind_inventory(p_inventory: InventoryComponent) -> void:
	_inventory = p_inventory
	if _consumable_buttons.is_empty() or p_inventory == null:
		return
	if not p_inventory.consumable_cooldown_changed.is_connected(_on_consumable_cooldown):
		p_inventory.consumable_cooldown_changed.connect(_on_consumable_cooldown)
	var party := ManagerLocator.get_party_inventory()
	if party and not party.equipment_changed.is_connected(_on_equipment_changed):
		party.equipment_changed.connect(_on_equipment_changed)
	_refresh_consumables()


func _on_equipment_changed(_hero_id: String, _slot: ItemData.Slot, _item: ItemData) -> void:
	_refresh_consumables()


func _on_consumable_cooldown(_item_id: String, _left: float) -> void:
	_refresh_consumables()


func _refresh_consumables() -> void:
	var party := ManagerLocator.get_party_inventory()
	if party == null or stats == null or _inventory == null:
		return
	var list := party.get_equipped(stats.hero_id, ItemData.Slot.CONSUMABLE)
	for index in _consumable_buttons.size():
		var button := _consumable_buttons[index]
		button.visible = index < list.size()
		if not button.visible:
			continue
		var item := list[index]
		button.icon = item.icon
		button.text = "" if item.icon else item.display_name.left(1)
		button.tooltip_text = "%s: %s\nClic: usar" % [item.display_name, item.describe_effect()]
		button.modulate = Color(1, 1, 1, 0.45) if _inventory.cooldown_left(item) > 0.0 else Color.WHITE


func _on_consumable_pressed(index: int) -> void:
	if _inventory and stats:
		ManagerLocator.get_net_commands().request("consume", {"hero": stats.hero_id, "index": index})


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

	_set_low_blink(current_hp > 0 and target_ratio < style.low_threshold)
	_refresh_downed()

	if took_damage and is_inside_tree():
		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		modulate = style.flash_color
		_flash_tween = create_tween()
		_flash_tween.tween_property(self, "modulate", Color.WHITE, style.flash_time)


## Low HP: the bar blinks (real time, so it keeps blinking in the tactical pause).
func _set_low_blink(on: bool) -> void:
	if on == is_low_blinking():
		return
	if _low_tween and _low_tween.is_valid():
		_low_tween.kill()
	_low_tween = null
	_bar.modulate = Color.WHITE
	if on and is_inside_tree():
		_low_tween = create_tween().set_loops().set_ignore_time_scale()
		_low_tween.tween_property(_bar, "modulate", Color(1, 1, 1, 0.3), 0.3)
		_low_tween.tween_property(_bar, "modulate", Color.WHITE, 0.3)


func is_low_blinking() -> bool:
	return _low_tween != null and _low_tween.is_valid()


## While downed, revive availability (Comida, an ally in the room) is re-read
## every frame (cheap) instead of wiring every hero's zone_changed.
func _process(_delta: float) -> void:
	if is_downed():
		_refresh_downed()


func is_downed() -> bool:
	return stats != null and not stats.is_alive()


## Downed: grey portrait, "Caído", and the revive button (cost + why it's blocked).
func _refresh_downed() -> void:
	if revive_button == null:
		return
	var downed := is_downed()
	_downed_label.visible = downed
	_icon.modulate = Color(0.4, 0.4, 0.45) if downed else Color.WHITE
	revive_button.visible = downed
	if ability_button:
		ability_button.disabled = downed
	if not downed:
		return
	var ps := ManagerLocator.get_player_stats()
	if ps == null:
		return
	revive_button.text = "Reanimar (%d Comida)" % ps.get_revive_cost(stats.hero_id)
	var reason: String = ps.get_revive_block_reason(stats.hero_id)
	revive_button.disabled = reason != ""
	revive_button.tooltip_text = reason if reason != "" else "Un aliado en su sala lo reanima"


func _on_revive_pressed() -> void:
	var ps := ManagerLocator.get_player_stats()
	if ps and stats:
		ManagerLocator.get_net_commands().request("revive", {"hero": stats.hero_id})


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
	add_theme_stylebox_override("panel", UiStyles.build_panel_style(PANEL_BG, border, width, 6, 6))


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

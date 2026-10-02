extends Control
class_name BestiaryPanel

## BestiaryPanel: the pause menu's enemy encyclopedia. Grid of every EnemyType
## (silhouette until seen) + a detail column that unlocks by tier: seen = sprite,
## name, behavior; killed = stats + description; mastered (3 kills) = damage to
## modules/Nexo, role, floors it appears on, lore. Data from BestiaryService;
## stats are the base x multipliers of the deepest floor it was seen on.
## Same open()/close()/`closed` contract as OptionsMenu; Esc closes only this panel.

signal closed

const PANEL_SIZE := Vector2(940, 560)
const GRID_COLUMNS := 4
const PREVIEW_SIZE := Vector2(160, 160)
const ANIM_FPS := 6.0

var is_open: bool = false

var _counter: Label
var _grid: GridContainer
var _items: Dictionary = {}
var _selected: EnemyType
var _sprite: TextureRect
var _name_label: Label
var _info: Label
var _frames: Array[Texture2D] = []
var _bestiary: BestiaryService


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_bestiary = ManagerLocator.get_bestiary()
	_build()


func open() -> void:
	is_open = true
	visible = true
	_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible and _frames.size() > 1:
		_sprite.texture = _frames[int(Time.get_ticks_msec() / (1000.0 / ANIM_FPS)) % _frames.size()]


# ---------------- build ----------------

func _build() -> void:
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", UiStyles.build_panel_style(QuestPalette.DUNGEON_CHARCOAL, QuestPalette.GOLD_DARK, 3, 16, 18))
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "BESTIARIO"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", QuestPalette.GOLD)
	header.add_child(title)
	_counter = Label.new()
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.add_theme_font_size_override("font_size", 22)
	_counter.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	header.add_child(_counter)
	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(120, 40)
	back.pressed.connect(close)
	header.add_child(back)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	content.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(GRID_COLUMNS * (BestiaryListItem.SIZE.x + 8.0) + 12.0, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	if _bestiary:
		for type in _bestiary.get_all_ordered():
			var item := BestiaryListItem.new()
			_grid.add_child(item)
			item.setup(type, BestiaryEntry.Tier.UNKNOWN)
			item.chosen.connect(_select)
			_items[type.id] = item

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	body.add_child(detail)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyles.build_panel_style(QuestPalette.DUNGEON_STONE, QuestPalette.UI_PANEL_BORDER, 2, 8, 6))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	detail.add_child(frame)
	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = PREVIEW_SIZE
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_sprite)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", QuestPalette.GOLD)
	detail.add_child(_name_label)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_theme_color_override("font_color", QuestPalette.PARCHMENT_LIGHT)
	detail.add_child(_info)


# ---------------- refresh ----------------

func _refresh() -> void:
	if _bestiary == null:
		return
	var types := _bestiary.get_all_ordered()
	_counter.text = "%d / %d descubiertos" % [_bestiary.unlocked_count(), types.size()]
	for type in types:
		(_items[type.id] as BestiaryListItem).set_tier(_bestiary.get_tier(type.id))
	if _selected == null and not types.is_empty():
		_selected = types[0]
	_select(_selected)


func _select(type: EnemyType) -> void:
	if type == null or _bestiary == null:
		return
	_selected = type
	for id: String in _items:
		(_items[id] as BestiaryListItem).set_selected(id == type.id)
	var entry := _bestiary.get_entry(type.id)
	var known := entry.tier() != BestiaryEntry.Tier.UNKNOWN
	_frames = _idle_frames(type) if known else _idle_frames(null)
	_sprite.texture = BestiaryListItem.first_frame(type)
	_sprite.modulate = Color.WHITE if known else Color.BLACK
	_name_label.text = type.display_name if known else "???"
	_info.text = detail_text(type, entry)


## Detail text for `type` at the entry's tier (also what the tests read).
static func detail_text(type: EnemyType, entry: BestiaryEntry) -> String:
	var tier := entry.tier()
	if tier == BestiaryEntry.Tier.UNKNOWN:
		return "Todavía no has visto a este enemigo."
	var profile := type.get_target_profile()
	var lines: Array[String] = ["Comportamiento: %s" % profile.display_name, profile.description]
	lines.append("Visto por primera vez en el piso %d (más profundo: %d)." % [entry.first_seen_floor, entry.max_floor_seen])
	lines.append("Muertes: %d" % entry.kill_count)
	if tier == BestiaryEntry.Tier.SEEN:
		lines.append("\nDerrótalo para conocer sus estadísticas.")
		return "\n".join(lines)
	var floor_index := maxi(entry.max_floor_seen, 1)
	var config: FloorConfig = FloorManager.DEFAULT_CONFIG
	var hp_mult := config.enemy_hp_multiplier(floor_index) * type.hp_mult
	var dmg_mult := config.enemy_damage_multiplier(floor_index) * type.damage_mult
	lines.append("\nEstadísticas (piso %d)" % floor_index)
	lines.append("Vida: %d" % maxi(1, roundi(Enemy.resolved_hp(type) * hp_mult)))
	lines.append("Velocidad: %d" % roundi(Enemy.resolved_speed(type) * type.speed_mult))
	lines.append("Daño por contacto: %d" % maxi(1, roundi(Enemy.resolved_contact_damage(type) * dmg_mult)))
	if type.description != "":
		lines.append("\n%s" % type.description)
	if tier == BestiaryEntry.Tier.KILLED:
		lines.append("\n(%d muertes más para saberlo todo)" % (BestiaryEntry.MASTER_KILLS - entry.kill_count))
		return "\n".join(lines)
	lines.append("Daño a módulos: %d" % maxi(1, roundi(Enemy.resolved_module_damage(type) * dmg_mult)))
	if type.damage_vs_nexo > 0:
		lines.append("Daño al Nexo: %d" % maxi(1, roundi(type.damage_vs_nexo * dmg_mult)))
	lines.append("Rol: %s" % ("Saqueador" if type.role == EnemyType.Role.RAIDER else "Cazador"))
	lines.append(_floor_range_text(type, config))
	if type.lore != "":
		lines.append("\n\"%s\"" % type.lore)
	return "\n".join(lines)


static func _floor_range_text(type: EnemyType, config: FloorConfig) -> String:
	var floors: Array[int] = []
	for f in range(1, config.max_floors + 1):
		var pool := config.enemy_pool(f)
		if pool and type in pool.types and not floors.has(f):
			floors.append(f)
	if floors.is_empty():
		return "Aparece en: sin piso fijo"
	if floors.size() == 1:
		return "Aparece en el piso %d" % floors[0]
	return "Aparece en los pisos %d a %d" % [floors[0], floors[-1]]


static func _idle_frames(type: EnemyType) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var frames := type.sprite_frames if type else null
	if frames == null:
		return out
	var names := frames.get_animation_names()
	var anim: StringName = &"idle" if frames.has_animation(&"idle") else (names[0] if names.size() > 0 else &"")
	if anim != &"":
		for i in frames.get_frame_count(anim):
			out.append(frames.get_frame_texture(anim, i))
	return out

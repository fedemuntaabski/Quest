extends CanvasLayer
class_name HUDController

const TOOLTIP_INDUSTRY := "Industria: Se utiliza para construir módulos de apoyo y defensas en las salas."
const TOOLTIP_FOOD := "Comida: Se utiliza para subir de nivel a los héroes (clic derecho en su retrato)."
const TOOLTIP_SCIENCE := "Ciencia: Se gasta en investigaciones (botón Investigar): desbloquea módulos y mejora generadores, torretas y Polvo."
const TOOLTIP_DUST := "Polvo: Se utiliza para iluminar salas oscuras y evitar la aparición de enemigos."

const _STAT_BAR_PATH := "Control/BottomBar/BottomRow/ResourcePanel/MarginContainer/StatPanelUI"
const _BUILD_BUTTONS_PATH := "Control/BottomBar/BottomRow/BuildPanel/MarginContainer/BuildButtons"

@onready var stat_panel: StatPanelUI = get_node(_STAT_BAR_PATH)
@onready var stats_hud_panel: PanelContainer = $Control/BottomBar/BottomRow/ResourcePanel
@onready var portraits: VBoxContainer = $Control/Portraits

@onready var stat_tooltip: PanelContainer = get_node_or_null("Control/StatTooltip")
@onready var stat_tooltip_label: Label = get_node_or_null("Control/StatTooltip/Label")

@onready var chip_industry: Control = get_node_or_null(_STAT_BAR_PATH + "/ChipIndustry")
@onready var chip_food: Control = get_node_or_null(_STAT_BAR_PATH + "/ChipFood")
@onready var chip_science: Control = get_node_or_null(_STAT_BAR_PATH + "/ChipScience")
@onready var chip_dust: Control = get_node_or_null(_STAT_BAR_PATH + "/ChipDust")

@onready var invasion_flash: ColorRect = get_node_or_null("Control/InvasionFlash")
@onready var building_menu: BuildingMenu = get_node_or_null("Control/BottomBar/BuildingMenu")
@onready var floor_label: Label = get_node_or_null("Control/TopLeft/FloorLabel")
@onready var production_button: Button = get_node_or_null(_BUILD_BUTTONS_PATH + "/ProductionButton")
@onready var defense_button: Button = get_node_or_null(_BUILD_BUTTONS_PATH + "/DefenseButton")
@onready var research_button: Button = get_node_or_null(_BUILD_BUTTONS_PATH + "/ResearchButton")

const INVASION_FLASH_ALPHA := 0.3
const INVASION_FLASH_HALF_TIME := 0.25

const HINT_WIDTH := 440.0
const HINT_TOP := 72
const HINT_HOLD := 8.0
const HINT_FADE := 0.6

const TOOLTIP_GAP := 12.0
const TOOLTIP_SCREEN_PADDING := 8.0

var _bound_player_stats: PlayerStats

var _tooltip_anchor: Vector2 = Vector2.ZERO
var _tooltip_grow_up: bool = false
var _invasion_tween: Tween
## One per hero, in party order. hero_id → HeroPortrait.
var _portraits: Dictionary = {}
var character_popup: CharacterPopup
var pause_label: Label
var _hint_panel: PanelContainer
var _hint_title: Label
var _hint_body: Label
var _hint_tween: Tween
## Red blinking screen border while raiders hit the Nexo (Nexo.under_attack_changed).
var nexo_alert: Panel
var _alert_tween: Tween
## Code-built, docked in BottomBar next to BuildingMenu (session 10).
var research_panel: ResearchPanel


func _ready() -> void:
	add_to_group("hud")

	_wire_chip_tooltip(chip_industry, TOOLTIP_INDUSTRY)
	_wire_chip_tooltip(chip_food, TOOLTIP_FOOD)
	_wire_chip_tooltip(chip_science, TOOLTIP_SCIENCE)
	_wire_chip_tooltip(chip_dust, TOOLTIP_DUST)

	if stat_tooltip:
		stat_tooltip.grow_vertical = Control.GROW_DIRECTION_BEGIN
		if not stat_tooltip.resized.is_connected(_reposition_tooltip):
			stat_tooltip.resized.connect(_reposition_tooltip)

	var ps := ManagerLocator.get_player_stats()
	if ps:
		_bind_player_stats(ps)

	var rm := ManagerLocator.get_resource_manager()
	if rm:
		if not rm.resource_changed.is_connected(_on_resource_changed):
			rm.resource_changed.connect(_on_resource_changed)
		if not rm.production_changed.is_connected(_refresh_gains):
			rm.production_changed.connect(_refresh_gains)
		for key in rm.KEYS:
			_on_resource_changed(key, rm.get_resource(key), 0)
		_refresh_gains()

	var em := ManagerLocator.get_enemy_manager()
	if em:
		if not em.invasion_triggered.is_connected(_on_invasion_triggered):
			em.invasion_triggered.connect(_on_invasion_triggered)
	else:
		QuestLogger.warn(QuestLogger.Category.UI, "HUD: EnemyManager not found; invasion alert disabled.")

	# Floor index is fixed for a Main2d instance (a new floor = new Main2d + new
	# HUD), so one read at bind time is enough — no signal needed.
	var fm := ManagerLocator.get_floor_manager()
	if fm and floor_label:
		floor_label.text = "Piso %d/%d" % [fm.floor_index, fm.config.max_floors]

	# Bottom-bar build entry: tab index == Module.SlotType.
	_add_research_panel()
	if building_menu:
		if production_button:
			production_button.pressed.connect(research_panel.close)
			production_button.pressed.connect(building_menu.open_category.bind(int(Module.SlotType.MAJOR)))
		if defense_button:
			defense_button.pressed.connect(research_panel.close)
			defense_button.pressed.connect(building_menu.open_category.bind(int(Module.SlotType.MINOR)))
	if research_button:
		research_button.pressed.connect(_on_research_pressed)

	_add_minimap()
	var room_manager := ManagerLocator.get_room_manager()
	if room_manager:
		room_manager.slot_clicked.connect(_on_slot_clicked)
	character_popup = CharacterPopup.new()
	character_popup.name = "CharacterPopup"
	$Control.add_child(character_popup)
	_add_pause_label()
	_add_nexo_alert()
	_add_hint_panel()

	# Death/victory: nothing modal may stay open over the overlays.
	if ps and not ps.player_died.is_connected(close_popups):
		ps.player_died.connect(close_popups)
	var gsm := ManagerLocator.get_game_state_manager()
	if gsm and not gsm.victory_entered.is_connected(close_popups):
		gsm.victory_entered.connect(close_popups)


func close_popups() -> void:
	character_popup.close()
	research_panel.close()
	if building_menu:
		building_menu.close_menu()


## Docked above the resource row, right under BuildingMenu; one open at a time.
func _add_research_panel() -> void:
	research_panel = ResearchPanel.new()
	research_panel.name = "ResearchPanel"
	research_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bar := $Control/BottomBar
	bar.add_child(research_panel)
	bar.move_child(research_panel, $Control/BottomBar/BottomRow.get_index())


func _on_research_pressed() -> void:
	if building_menu:
		building_menu.close_menu()
	research_panel.toggle()


## Tactical pause banner (PauseController → ManagerLocator.get_hud().set_pause_label).
func _add_pause_label() -> void:
	pause_label = Label.new()
	pause_label.name = "PauseLabel"
	pause_label.text = "PAUSA"
	pause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_label.add_theme_font_size_override("font_size", 32)
	pause_label.visible = false
	$Control.add_child(pause_label)
	pause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)


func _add_nexo_alert() -> void:
	nexo_alert = Panel.new()
	nexo_alert.name = "NexoAlert"
	nexo_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nexo_alert.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = QuestPalette.BLOOD
	style.set_border_width_all(10)
	nexo_alert.add_theme_stylebox_override("panel", style)
	$Control.add_child(nexo_alert)
	nexo_alert.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var nexo := ManagerLocator.get_nexo()
	if nexo:
		nexo.under_attack_changed.connect(set_nexo_alert)


func set_nexo_alert(active: bool) -> void:
	if _alert_tween:
		_alert_tween.kill()
	nexo_alert.visible = active
	if not active:
		return
	nexo_alert.modulate.a = 1.0
	_alert_tween = create_tween().set_loops().set_ignore_time_scale()
	_alert_tween.tween_property(nexo_alert, "modulate:a", 0.25, 0.3)
	_alert_tween.tween_property(nexo_alert, "modulate:a", 1.0, 0.3)


## First-discovery tip of a room type (FloorManager → ManagerLocator.get_hud().show_hint):
## top-center card that fades by itself; a newer hint replaces the old one.
func _add_hint_panel() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.name = "HintPanel"
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.custom_minimum_size = Vector2(HINT_WIDTH, 0)
	_hint_panel.visible = false
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_title = Label.new()
	_hint_title.add_theme_font_size_override("font_size", 20)
	_hint_body = Label.new()
	_hint_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_body.custom_minimum_size = Vector2(HINT_WIDTH - 24.0, 0)
	box.add_child(_hint_title)
	box.add_child(_hint_body)
	margin.add_child(box)
	_hint_panel.add_child(margin)
	$Control.add_child(_hint_panel)
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, HINT_TOP)


func show_hint(title: String, text: String, color: Color) -> void:
	if _hint_panel == null:
		return
	_hint_title.text = title
	_hint_title.add_theme_color_override("font_color", color)
	_hint_body.text = text
	_hint_panel.reset_size()
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, HINT_TOP)
	if _hint_tween:
		_hint_tween.kill()
	_hint_panel.modulate.a = 1.0
	_hint_panel.visible = true
	_hint_tween = create_tween().set_ignore_time_scale()
	_hint_tween.tween_interval(HINT_HOLD)
	_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, HINT_FADE)
	_hint_tween.tween_callback(_hint_panel.hide)


func set_pause_label(v: bool) -> void:
	if pause_label:
		pause_label.visible = v


## Built in code (not in HUD.tscn): bottom-right corner, self-wiring.
func _add_minimap() -> void:
	var minimap := Minimap.new()
	minimap.name = "Minimap"
	$Control.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)


# ---------------- PLAYER STATS BINDING ----------------

func _bind_player_stats(ps: PlayerStats) -> void:
	if ps == null:
		return

	if _bound_player_stats and _bound_player_stats.stats_changed.is_connected(_on_player_stats_changed):
		_bound_player_stats.stats_changed.disconnect(_on_player_stats_changed)

	_bound_player_stats = ps

	if not ps.stats_changed.is_connected(_on_player_stats_changed):
		ps.stats_changed.connect(_on_player_stats_changed)
	var selection := ManagerLocator.get_selection_manager()
	if selection and not selection.selection_changed.is_connected(_refresh_selection):
		selection.selection_changed.connect(_refresh_selection)
	if selection and not selection.groups_changed.is_connected(_refresh_groups):
		selection.groups_changed.connect(_refresh_groups)

	for stats in ps.get_all_stats():
		_on_player_stats_changed(stats)


## One portrait per hero id; a new CharacterStats for a hero that already has
## one (re-register) just rebinds it.
func _on_player_stats_changed(stats: CharacterStats) -> void:
	if stats == null:
		return

	var portrait: HeroPortrait = _portraits.get(stats.hero_id)
	if portrait == null:
		var owner_player := stats.get_parent() as Player
		add_hero_portrait(stats, owner_player.character_data if owner_player else null)
	elif portrait.stats != stats:
		portrait.bind_stats(stats)


# ---------------- PORTRAITS ----------------

## Stacks one more portrait in the top-right column (multi-hero ready).
func add_hero_portrait(stats: CharacterStats, data: CharacterData) -> HeroPortrait:
	var portrait := HeroPortrait.new()
	portrait.setup(stats, data)
	var owner_player := stats.get_parent() as Player
	if owner_player and owner_player.abilities:
		portrait.bind_abilities(owner_player.abilities)
	portrait.portrait_clicked.connect(_on_portrait_clicked)
	portrait.portrait_ctrl_clicked.connect(_on_portrait_ctrl_clicked)
	portrait.portrait_right_clicked.connect(open_hero_sheet)
	portraits.add_child(portrait)
	_portraits[stats.hero_id] = portrait
	_refresh_selection()
	_refresh_groups()
	return portrait


## Left click: select only that hero; on the sole selected one, open its sheet
## (single-hero play: always the sheet, as before session 12).
func _on_portrait_clicked(portrait: HeroPortrait) -> void:
	var selection := ManagerLocator.get_selection_manager()
	if selection and portrait.stats and not selection.is_only(portrait.stats.hero_id):
		hide_simple_tooltip()
		selection.select_only(portrait.stats.hero_id)
	else:
		open_hero_sheet(portrait)


## Ctrl + left click: add/remove that hero.
func _on_portrait_ctrl_clicked(portrait: HeroPortrait) -> void:
	var selection := ManagerLocator.get_selection_manager()
	if selection and portrait.stats:
		selection.toggle(portrait.stats.hero_id)


## CharacterPopup for this portrait's hero (not necessarily the selected one).
func open_hero_sheet(portrait: HeroPortrait) -> void:
	hide_simple_tooltip()
	character_popup.open_for(portrait.stats, portrait.character_data)


func _refresh_selection(_selected_ids: Array[String] = []) -> void:
	var selection := ManagerLocator.get_selection_manager()
	for hero_id: String in _portraits:
		(_portraits[hero_id] as HeroPortrait).set_selected(selection != null and selection.is_selected(hero_id))


func _refresh_groups() -> void:
	var selection := ManagerLocator.get_selection_manager()
	for hero_id: String in _portraits:
		(_portraits[hero_id] as HeroPortrait).set_groups(selection.group_of(hero_id) if selection else [])


func _on_resource_changed(key: String, amount: int, _delta: int) -> void:
	if stat_panel:
		stat_panel.update_resource(key, amount)


func _refresh_gains() -> void:
	var rm := ManagerLocator.get_resource_manager()
	if rm == null or stat_panel == null:
		return
	for key in rm.KEYS:
		stat_panel.update_gain(key, rm.get_turn_yield(key))


# ---------------- BUILDING MENU ----------------

## Armed-mode slot pick (RoomManager.slot_clicked); a no-op unless a module is armed.
func _on_slot_clicked(_zone_id: String, slot: BuildingSlot) -> void:
	if slot.is_empty():
		open_building_menu(slot)


func open_building_menu(slot: BuildingSlot) -> void:
	if building_menu == null:
		QuestLogger.warn(QuestLogger.Category.UI, "HUD: BuildingMenu node missing.")
		return
	building_menu.open_menu(slot)


# ---------------- INVASION ALERT ----------------

func _on_invasion_triggered(_spawn_rooms: Array[RoomZone], _enemy_count: int) -> void:
	trigger_invasion_alert()


## Emergency-light pulse: red overlay alpha 0 -> 0.3 -> 0.
func trigger_invasion_alert() -> void:
	if invasion_flash == null:
		return
	if _invasion_tween and _invasion_tween.is_valid():
		_invasion_tween.kill()
	invasion_flash.color.a = 0.0
	_invasion_tween = create_tween()
	_invasion_tween.tween_property(invasion_flash, "color:a", INVASION_FLASH_ALPHA, INVASION_FLASH_HALF_TIME)
	_invasion_tween.tween_property(invasion_flash, "color:a", 0.0, INVASION_FLASH_HALF_TIME)


# ---------------- CHIP TOOLTIPS ----------------

func _wire_chip_tooltip(chip: Control, text: String) -> void:
	if chip == null:
		return
	chip.mouse_entered.connect(_on_chip_hovered.bind(chip, text))
	chip.mouse_exited.connect(hide_simple_tooltip)


## Resource bar sits at the bottom → tooltip grows up above the chip.
func _on_chip_hovered(chip: Control, text: String) -> void:
	var chip_rect := chip.get_global_rect()
	show_simple_tooltip(text, chip_rect.position - Vector2(0.0, TOOLTIP_GAP), true)


# ---------------- TOOLTIP ----------------

## `global_pos` is the anchor point the tooltip grows from. When `grow_up` is
## true (bottom HUD bar), the tooltip's bottom edge sits at that point instead
## of its top-left, and the panel is clamped to stay fully on-screen.
func show_simple_tooltip(text: String, global_pos: Variant = null, grow_up: bool = false) -> void:
	if stat_tooltip == null or stat_tooltip_label == null:
		return

	stat_tooltip_label.text = text
	stat_tooltip.visible = true

	if global_pos != null:
		_tooltip_anchor = global_pos
	else:
		var panel_rect := stats_hud_panel.get_global_rect() if stats_hud_panel else stat_panel.get_global_rect()
		_tooltip_anchor = panel_rect.position + Vector2(panel_rect.size.x + 12.0, 0.0)

	_tooltip_grow_up = grow_up
	stat_tooltip.grow_vertical = Control.GROW_DIRECTION_BEGIN if grow_up else Control.GROW_DIRECTION_END
	stat_tooltip.reset_size()
	_reposition_tooltip()


func hide_simple_tooltip() -> void:
	if stat_tooltip:
		stat_tooltip.visible = false


func _reposition_tooltip() -> void:
	if stat_tooltip == null or not stat_tooltip.visible:
		return

	var size := stat_tooltip.size
	var vp := stat_tooltip.get_viewport_rect().size
	var pos := _tooltip_anchor

	if _tooltip_grow_up:
		pos.y -= size.y

	pos.x = clampf(pos.x, TOOLTIP_SCREEN_PADDING, maxf(TOOLTIP_SCREEN_PADDING, vp.x - size.x - TOOLTIP_SCREEN_PADDING))
	pos.y = clampf(pos.y, TOOLTIP_SCREEN_PADDING, maxf(TOOLTIP_SCREEN_PADDING, vp.y - size.y - TOOLTIP_SCREEN_PADDING))

	stat_tooltip.global_position = pos

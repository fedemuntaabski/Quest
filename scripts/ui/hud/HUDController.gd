extends CanvasLayer
class_name HUDController

const TOOLTIP_HP := "Puntos de resistencia del héroe. Si llega a 0, la incursión fracasa."
const TOOLTIP_INDUSTRY := "Industria: Se utiliza para construir módulos de apoyo y defensas en las salas."
const TOOLTIP_FOOD := "Comida: Se utiliza para curar al héroe, subirlo de nivel y reclutar aliados."
const TOOLTIP_SCIENCE := "Ciencia: Se utiliza para investigar nuevos módulos y tecnologías."
const TOOLTIP_DUST := "Polvo: Se utiliza para iluminar salas oscuras y evitar la aparición de enemigos."

const _STAT_BAR_PATH := "Control/StatBarAnchor/StatBarCenter/StatBarPanel/MarginContainer/StatPanelUI"

@onready var stat_panel: StatPanelUI = get_node(_STAT_BAR_PATH)
@onready var stats_hud_panel: PanelContainer = $Control/StatBarAnchor/StatBarCenter/StatBarPanel

@onready var stat_tooltip: PanelContainer = get_node_or_null("Control/StatTooltip")
@onready var stat_tooltip_label: Label = get_node_or_null("Control/StatTooltip/Label")

@onready var icon_hp: Control = get_node_or_null(_STAT_BAR_PATH + "/ChipHP/IconHP")

@onready var chip_hp: Control = get_node_or_null(_STAT_BAR_PATH + "/ChipHP")
@onready var chip_industry: Control = get_node_or_null(_STAT_BAR_PATH + "/ChipIndustry")
@onready var chip_food: Control = get_node_or_null(_STAT_BAR_PATH + "/ChipFood")
@onready var chip_science: Control = get_node_or_null(_STAT_BAR_PATH + "/ChipScience")
@onready var chip_dust: Control = get_node_or_null(_STAT_BAR_PATH + "/ChipDust")

@onready var invasion_flash: ColorRect = get_node_or_null("Control/InvasionFlash")

const INVASION_FLASH_ALPHA := 0.3
const INVASION_FLASH_HALF_TIME := 0.25

const TOOLTIP_GAP := 12.0
const TOOLTIP_SCREEN_PADDING := 8.0

var _bound_stats: CharacterStats
var _bound_player_stats: PlayerStats

var _tooltip_anchor: Vector2 = Vector2.ZERO
var _tooltip_grow_up: bool = false
var _invasion_tween: Tween


func _ready() -> void:
	add_to_group("hud")

	_wire_chip_tooltip(chip_hp, TOOLTIP_HP)
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
		for key in rm.KEYS:
			_on_resource_changed(key, rm.get_resource(key), 0)

	var em := ManagerLocator.get_enemy_manager()
	if em:
		if not em.invasion_triggered.is_connected(_on_invasion_triggered):
			em.invasion_triggered.connect(_on_invasion_triggered)
	else:
		QuestLogger.warn(QuestLogger.Category.UI, "HUD: EnemyManager not found; invasion alert disabled.")


# ---------------- PLAYER STATS BINDING ----------------

func _bind_player_stats(ps: PlayerStats) -> void:
	if ps == null:
		return

	if _bound_player_stats and _bound_player_stats.stats_changed.is_connected(_on_player_stats_changed):
		_bound_player_stats.stats_changed.disconnect(_on_player_stats_changed)

	_bound_player_stats = ps

	if not ps.stats_changed.is_connected(_on_player_stats_changed):
		ps.stats_changed.connect(_on_player_stats_changed)

	if ps.stats:
		_on_player_stats_changed(ps.stats)


func _on_player_stats_changed(stats: CharacterStats) -> void:
	if stats == null:
		return

	if _bound_stats != stats:
		if _bound_stats:
			if _bound_stats.hp_changed.is_connected(_on_hp_changed):
				_bound_stats.hp_changed.disconnect(_on_hp_changed)

		_bound_stats = stats

		if not stats.hp_changed.is_connected(_on_hp_changed):
			stats.hp_changed.connect(_on_hp_changed)

	if stat_panel:
		stat_panel.update_stats(stats)


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if stat_panel:
		stat_panel.update_hp(current_hp, max_hp)


func _on_resource_changed(key: String, amount: int, _delta: int) -> void:
	if stat_panel:
		stat_panel.update_resource(key, amount)


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


func _on_chip_hovered(chip: Control, text: String) -> void:
	var chip_rect := chip.get_global_rect()
	var target_pos := chip_rect.position - Vector2(0.0, TOOLTIP_GAP)
	show_simple_tooltip(text, target_pos, true)


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

extends CanvasLayer
class_name HUDController

@onready var stat_panel: StatPanelUI = $Control/StatsHUD/MarginContainer/StatPanelUI
@onready var stats_hud_panel: PanelContainer = $Control/StatsHUD

@onready var turn_button: Button = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowAP/EndTurnButton")

@onready var stat_tooltip: PanelContainer = get_node_or_null("Control/StatTooltip")
@onready var stat_tooltip_label: Label = get_node_or_null("Control/StatTooltip/Label")

@onready var icon_hp: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowHP/IconHP")

var _turn_button_controller: TurnButtonController

var _bound_stats: CharacterStats
var _bound_player_stats: PlayerStats


func _ready() -> void:
	add_to_group("hud")

	_init_turn_button_controller()

	var ps := ManagerLocator.get_player_stats()
	if ps:
		_bind_player_stats(ps)


# ---------------- TURN BUTTON ----------------

func _init_turn_button_controller() -> void:
	if _turn_button_controller != null:
		return

	_turn_button_controller = TurnButtonController.new()
	add_child(_turn_button_controller)
	_turn_button_controller.setup(turn_button)


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
			if _bound_stats.ap_changed.is_connected(_on_ap_changed):
				_bound_stats.ap_changed.disconnect(_on_ap_changed)

		_bound_stats = stats

		if not stats.hp_changed.is_connected(_on_hp_changed):
			stats.hp_changed.connect(_on_hp_changed)
		if not stats.ap_changed.is_connected(_on_ap_changed):
			stats.ap_changed.connect(_on_ap_changed)

	stat_panel.update_stats(stats)


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if stat_panel:
		stat_panel.update_hp(current_hp, max_hp)


func _on_ap_changed(current_ap: int, max_ap: int) -> void:
	if stat_panel:
		stat_panel.update_ap(current_ap, max_ap)

	if _turn_button_controller:
		_turn_button_controller.refresh()


# ---------------- TOOLTIP ----------------

func show_simple_tooltip(text: String, global_pos: Variant = null) -> void:
	if stat_tooltip == null or stat_tooltip_label == null:
		return

	stat_tooltip_label.text = text
	stat_tooltip.visible = true

	var target_pos: Vector2

	if global_pos != null:
		target_pos = global_pos
	else:
		var panel_rect := stats_hud_panel.get_global_rect() if stats_hud_panel else stat_panel.get_global_rect()
		target_pos = panel_rect.position + Vector2(panel_rect.size.x + 12.0, 0.0)

	stat_tooltip.global_position = target_pos


func hide_simple_tooltip() -> void:
	if stat_tooltip:
		stat_tooltip.visible = false

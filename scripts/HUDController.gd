extends CanvasLayer
class_name HUDController

@onready var stat_panel: StatPanelUI = $Control/StatPanelUI
@onready var upgrade_panel: UpgradePanelUI = $Control/UpgradePanelUI
@onready var timer_ui: TimerUI = $Control/TimerUI

var player_stats: CharacterStats
var base_stats := {}

func _ready() -> void:
	_setup_input()

	var ps = get_node_or_null("/root/PlayerStats")
	if ps:
		ps.stats_changed.connect(_on_stats_changed)

		base_stats = {
			"hp": ps.base_hp,
			"strength": ps.base_str,
			"magic": ps.base_mag,
			"dexterity": ps.base_dex
		}

		if ps.stats:
			_on_stats_changed(ps.stats)

func _setup_input() -> void:
	if not InputMap.has_action("tab"):
		InputMap.add_action("tab")
		var ev := InputEventKey.new()
		ev.keycode = KEY_TAB
		InputMap.action_add_event("tab", ev)

func _process(_delta: float) -> void:
	$Control/TabUIPanel.visible = Input.is_action_pressed("tab")

func _on_stats_changed(stats: CharacterStats) -> void:
	player_stats = stats
	stat_panel.update_stats(stats, base_stats)

	var ps = get_node("/root/PlayerStats")
	upgrade_panel.refresh(ps.active_upgrades)

func update_room_timer(time_left: float, _total: float, color: Color) -> void:
	timer_ui.set_time(time_left, color)

func update_current_room(id: int) -> void:
	pass

func update_enemies_remaining(_count: int) -> void:
	pass

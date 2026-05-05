extends CanvasLayer
class_name HUDController

@onready var stat_panel: StatPanelUI = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/HBoxContainer/VBoxContainer
@onready var upgrade_panel: UpgradePanelUI = $Control/UpgradePanelUI
@onready var timer_ui: TimerUI = $Control/TimerUI

@onready var tab_panel: Control = $Control/TabUIPanel
@onready var current_room_label: Label = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/TopInfoRow/CurrentRoomLabel
@onready var enemies_label: Label = $Control/TabUIPanel/MarginContainer/VBoxContainer_Main/TopInfoRow/EnemiesLabel

var player_stats: CharacterStats
var base_stats := {}

func _ready() -> void:
	_setup_input()

	var ps = get_node_or_null("/root/PlayerStats")
	if ps and ps.stats:
		var stats: CharacterStats = ps.stats

		stats.stats_changed.connect(_on_stats_changed)
		stats.hp_changed.connect(_on_hp_changed)

		_on_stats_changed(stats)
		ps.upgrades_changed.connect(_on_upgrades_changed)

		base_stats = {
			"hp": ps.base_hp,
			"strength": ps.base_str,
			"magic": ps.base_mag,
			"dexterity": ps.base_dex
		}

		if ps.stats:
			_on_stats_changed(ps.stats)

		if ps.active_upgrades:
			upgrade_panel.refresh(ps.active_upgrades)

func _setup_input() -> void:
	if not InputMap.has_action("tab"):
		InputMap.add_action("tab")
		var ev := InputEventKey.new()
		ev.keycode = KEY_TAB
		InputMap.action_add_event("tab", ev)

func _process(_delta: float) -> void:
	tab_panel.visible = Input.is_action_pressed("tab")

func _on_stats_changed(stats: CharacterStats) -> void:
	player_stats = stats
	stat_panel.update_stats(stats, base_stats)

func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if stat_panel:
		stat_panel.update_hp(current_hp, max_hp)

func _on_upgrades_changed(upgrades: Array) -> void:
	upgrade_panel.refresh(upgrades)

func update_room_timer(time_left: float, _total: float, color: Color) -> void:
	if timer_ui:
		timer_ui.set_time(time_left, color)

func update_current_room(id: int) -> void:
	if current_room_label:
		current_room_label.text = "Room: %d" % id

func update_enemies_remaining(count: int) -> void:
	if enemies_label:
		enemies_label.text = "Enemies: %d" % count

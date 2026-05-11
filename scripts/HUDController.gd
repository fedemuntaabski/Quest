extends CanvasLayer
class_name HUDController

signal hotbar_slot_pressed(index: int)

@onready var stat_panel: StatPanelUI = $Control/TabUIPanel/MarginContainer/StatPanelUI
@onready var upgrade_panel: UpgradePanelUI = $Control/UpgradePanelUI
@onready var timer_ui: TimerUI = $Control/TimerUI
@onready var hotbar_bar: HBoxContainer = $Control/HotbarBar
@onready var card_tooltip: CardTooltip = $CardTooltip

@onready var tab_panel: Control = $Control/TabUIPanel
@onready var current_room_label: Label = $Control/TabUIPanel/MarginContainer/StatPanelUI/TopInfoRow/CurrentRoomLabel
@onready var enemies_label: Label = $Control/TabUIPanel/MarginContainer/StatPanelUI/TopInfoRow/EnemiesLabel

var player_stats: CharacterStats
var base_stats := {}
var hotbar_slots: Array = []

func _ready() -> void:
	add_to_group("hud")
	_setup_input()
	_setup_hotbar()

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

func _setup_hotbar() -> void:
	if hotbar_bar == null:
		return

	hotbar_slots.clear()
	for child in hotbar_bar.get_children():
		if child is HotbarSlot:
			hotbar_slots.append(child)
			child.set_tooltip_host(self)
			if not child.slot_pressed.is_connected(_on_hotbar_slot_pressed):
				child.slot_pressed.connect(_on_hotbar_slot_pressed)

func _on_hotbar_slot_pressed(index: int) -> void:
	hotbar_slot_pressed.emit(index)

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

func update_hotbar(cards: Array, active_index: int) -> void:
	if hotbar_slots.is_empty():
		return

	for i in range(hotbar_slots.size()):
		var slot: HotbarSlot = hotbar_slots[i]
		if i < cards.size():
			slot.set_card(cards[i])
		else:
			slot.set_card({})
			slot.set_cooldown(0)

		slot.set_selected(i == active_index)

func show_card_tooltip(data: Dictionary, global_pos: Vector2) -> void:
	if card_tooltip == null:
		return
	card_tooltip.set_card(data)
	card_tooltip.global_position = global_pos + Vector2(12, 12)

func hide_card_tooltip() -> void:
	if card_tooltip:
		card_tooltip.visible = false

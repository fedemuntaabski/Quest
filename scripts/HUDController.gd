extends CanvasLayer
class_name HUDController

signal hotbar_slot_pressed(index: int)
signal reward_card_selected(card: CardData)

@onready var stat_panel: StatPanelUI = $Control/TabUIPanel/MarginContainer/VBoxContainer/ContentPanel/StatPanelUI
@onready var upgrade_panel: UpgradePanelUI = $Control/UpgradePanelUI if has_node("Control/UpgradePanelUI") else null
@onready var card_panel: CardPanelUI = $Control/TabUIPanel/MarginContainer/VBoxContainer/ContentPanel/CardPanelUI if has_node("Control/TabUIPanel/MarginContainer/VBoxContainer/ContentPanel/CardPanelUI") else null
@onready var timer_ui: TimerUI = $Control/TimerUI
@onready var hotbar_bar: HBoxContainer = $Control/HotbarBar
@onready var card_tooltip: CardTooltip = $CardTooltip
@onready var card_reward_ui: CardRewardUI = $CardRewardUI if has_node("CardRewardUI") else null

@onready var tab_panel: Control = $Control/TabUIPanel
@onready var current_room_label: Label = $Control/TabUIPanel/MarginContainer/VBoxContainer/ContentPanel/StatPanelUI/TopInfoRow/CurrentRoomLabel
@onready var enemies_label: Label = $Control/TabUIPanel/MarginContainer/VBoxContainer/ContentPanel/StatPanelUI/TopInfoRow/EnemiesLabel
@onready var tab_bar: TabBar = $Control/TabUIPanel/MarginContainer/VBoxContainer/TabBar if has_node("Control/TabUIPanel/MarginContainer/VBoxContainer/TabBar") else null

var player_stats: CharacterStats
var base_stats := {}
var hotbar_slots: Array = []
var _bound_card_manager: CardManager = null

func _ready() -> void:
	add_to_group("hud")
	_setup_input()
	_setup_hotbar()
	_setup_tab_switching()
	_setup_reward_ui()

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
			if upgrade_panel:
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

func _setup_reward_ui() -> void:
	if card_reward_ui == null:
		return
	if not card_reward_ui.card_selected.is_connected(_on_reward_card_selected):
		card_reward_ui.card_selected.connect(_on_reward_card_selected)

func _on_hotbar_slot_pressed(index: int) -> void:
	hotbar_slot_pressed.emit(index)

func _on_reward_card_selected(card: CardData) -> void:
	reward_card_selected.emit(card)

func _setup_tab_switching() -> void:
	if tab_bar == null:
		return
	if not tab_bar.tab_changed.is_connected(_on_tab_changed):
		tab_bar.tab_changed.connect(_on_tab_changed)
	# Initialize to first tab
	_on_tab_changed(0)

func _on_tab_changed(tab_index: int) -> void:
	if stat_panel:
		stat_panel.visible = (tab_index == 0)
	if card_panel:
		card_panel.visible = (tab_index == 1)

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
	if upgrade_panel:
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
	if not hotbar_slots.is_empty():
		for i in range(hotbar_slots.size()):
			var slot: HotbarSlot = hotbar_slots[i]
			if i < cards.size():
				var card_data = cards[i]
				slot.set_card(card_data)
				var cd_remaining: int = card_data.get("cooldown_remaining", 0) if card_data is Dictionary else 0
				slot.set_cooldown(cd_remaining)
				var is_usable: bool = card_data.get("is_usable", cd_remaining <= 0) if card_data is Dictionary else true
				var state_label: String = card_data.get("state", "available") if card_data is Dictionary else "available"
				slot.set_usable(is_usable)
				slot.set_state_label(state_label)
			else:
				slot.set_card({})
				slot.set_cooldown(0)
				slot.set_usable(false)
				slot.set_state_label("blocked")

			slot.set_selected(i == active_index)
	
	# Also update the Cards panel in TAB menu
	update_cards_panel(cards)

func update_cards_panel(cards: Array) -> void:
	if card_panel:
		var normalized_cards: Array = []
		for card in cards:
			normalized_cards.append(card if card is Dictionary else {})
		card_panel.refresh(normalized_cards)

func show_card_tooltip(data: Dictionary, global_pos: Vector2) -> void:
	if card_tooltip == null:
		return
	card_tooltip.set_card(data)
	card_tooltip.global_position = global_pos + Vector2(12, 12)

func hide_card_tooltip() -> void:
	if card_tooltip:
		card_tooltip.visible = false

func bind_card_manager(card_manager: CardManager) -> void:
	if card_manager == null:
		return

	if _bound_card_manager and _bound_card_manager != card_manager:
		if _bound_card_manager.ui_state_changed.is_connected(_on_card_ui_state_changed):
			_bound_card_manager.ui_state_changed.disconnect(_on_card_ui_state_changed)

	_bound_card_manager = card_manager
	if not _bound_card_manager.ui_state_changed.is_connected(_on_card_ui_state_changed):
		_bound_card_manager.ui_state_changed.connect(_on_card_ui_state_changed)

	_on_card_ui_state_changed(_bound_card_manager.get_equipped_payload(), _bound_card_manager.active_index)

func _on_card_ui_state_changed(cards_payload: Array, active_index: int) -> void:
	update_hotbar(cards_payload, active_index)

func show_reward_selection(cards: Array) -> void:
	if card_reward_ui:
		card_reward_ui.show_reward(cards)

func hide_reward_selection() -> void:
	if card_reward_ui:
		card_reward_ui.hide_reward()

extends CanvasLayer
class_name HUDController

signal hotbar_slot_pressed(index: int)
signal reward_card_selected(card: CardData)
signal reward_skipped
signal reward_card_replace_selected(card: CardData, slot_index: int)

@onready var stat_panel: StatPanelUI = $Control/StatsHUD/MarginContainer/StatPanelUI
@onready var upgrade_panel: UpgradePanelUI = $Control/UpgradePanelUI if has_node("Control/UpgradePanelUI") else null
@onready var card_panel: CardPanelUI = get_node_or_null("Control/CardPanelUI") as CardPanelUI
@onready var timer_ui: TimerUI = $Control/TimerUI
@onready var hotbar_bar: HBoxContainer = $Control/HotbarBar
@onready var card_tooltip: CardTooltip = $CardTooltip
@onready var card_reward_ui: CardRewardUI = $CardRewardUI if has_node("CardRewardUI") else null
@onready var roll_label: Label = $Control/RollLabel if has_node("Control/RollLabel") else null

@onready var current_room_label: Label = get_node_or_null("Control/CurrentRoomLabel") as Label
@onready var enemies_label: Label = get_node_or_null("Control/EnemiesLabel") as Label

var player_stats: CharacterStats
var base_stats := {}
var hotbar_slots: Array = []
var _bound_card_manager: CardManager = null
var _roll_label_tween: Tween = null

func _ready() -> void:
	add_to_group("hud")
	_setup_hotbar()
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
	if not card_reward_ui.reward_skipped.is_connected(_on_reward_skipped):
		card_reward_ui.reward_skipped.connect(_on_reward_skipped)
	if not card_reward_ui.card_replace_selected.is_connected(_on_reward_card_replace_selected):
		card_reward_ui.card_replace_selected.connect(_on_reward_card_replace_selected)

func _on_hotbar_slot_pressed(index: int) -> void:
	hotbar_slot_pressed.emit(index)

func _on_reward_card_selected(card: CardData) -> void:
	reward_card_selected.emit(card)

func _on_reward_skipped() -> void:
	reward_skipped.emit()

func _on_reward_card_replace_selected(card: CardData, slot_index: int) -> void:
	reward_card_replace_selected.emit(card, slot_index)

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
	
	# Also update the Cards panel if present
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

func set_roll_label_from_result(result: Dictionary) -> void:
	if roll_label == null or result == null:
		return
	if not result.has("dice_roll"):
		return
	var roll: int = int(result.get("dice_roll", 0))
	var multiplier: float = float(result.get("damage_multiplier", 1.0))
	roll_label.text = "Tirada: %d - %s (x%.2f)" % [roll, _roll_label_name(roll), multiplier]
	roll_label.visible = true
	roll_label.modulate.a = 1.0

	if _roll_label_tween:
		_roll_label_tween.kill()
	_roll_label_tween = create_tween()
	_roll_label_tween.tween_interval(2.0)
	_roll_label_tween.tween_property(roll_label, "modulate:a", 0.0, 0.35)
	_roll_label_tween.tween_callback(func():
		roll_label.visible = false
		roll_label.text = ""
	)

func _roll_label_name(roll: int) -> String:
	match roll:
		6:
			return "Critico"
		5:
			return "Golpe fuerte"
		4, 3:
			return "Normal"
		2:
			return "Golpe debil"
		1:
			return "Golpe rasante"
		_:
			return "Normal"

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

func show_reward_selection(cards: Array, requires_replace: bool = false, equipped_slots: Array = []) -> void:
	if card_reward_ui:
		card_reward_ui.show_reward(cards, requires_replace, equipped_slots)

func hide_reward_selection() -> void:
	if card_reward_ui:
		card_reward_ui.hide_reward()

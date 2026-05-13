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
@onready var potion_button: Button = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowPotion/PotionButton") as Button
@onready var potion_count_label: Label = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowPotion/PotionCount") as Label
@onready var potion_icon: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowPotion/IconPotion") as Control

@onready var stat_tooltip: PanelContainer = get_node_or_null("Control/StatTooltip") as PanelContainer
@onready var stat_tooltip_label: Label = get_node_or_null("Control/StatTooltip/Label") as Label

@onready var icon_hp: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowHP/IconHP") as Control
@onready var icon_strength: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowStrength/IconStrength") as Control
@onready var icon_magic: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowMagic/IconMagic") as Control
@onready var icon_dexterity: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowDexterity/IconDexterity") as Control

@onready var current_room_label: Label = get_node_or_null("Control/CurrentRoomLabel") as Label
@onready var enemies_label: Label = get_node_or_null("Control/EnemiesLabel") as Label

var player_stats: CharacterStats
var base_stats := {}
var hotbar_slots: Array = []
var _bound_card_manager: CardManager = null
var _roll_label_tween: Tween = null
var _game_state_manager: GameStateManager = null
var _potion_used: bool = false
var _bound_stats: CharacterStats = null

const POTION_HEAL_RATIO: float = 0.5

func _ready() -> void:
	add_to_group("hud")
	_setup_hotbar()
	_setup_reward_ui()
	_setup_potion()
	_setup_stat_tooltips()

	var ps = get_node_or_null("/root/PlayerStats")
	if ps:
		_bind_player_stats(ps)

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

func _bind_player_stats(ps: PlayerStats) -> void:
	if ps == null:
		return
	if not ps.stats_changed.is_connected(_on_player_stats_changed):
		ps.stats_changed.connect(_on_player_stats_changed)
	if not ps.upgrades_changed.is_connected(_on_upgrades_changed):
		ps.upgrades_changed.connect(_on_upgrades_changed)

	base_stats = {
		"hp": ps.base_hp,
		"strength": ps.base_str,
		"magic": ps.base_mag,
		"dexterity": ps.base_dex
	}

	if ps.stats:
		_on_player_stats_changed(ps.stats)

	if ps.active_upgrades and upgrade_panel:
		upgrade_panel.refresh(ps.active_upgrades)

func _on_player_stats_changed(stats: CharacterStats) -> void:
	if stats == null:
		return
	if _bound_stats != stats:
		if _bound_stats and _bound_stats.hp_changed.is_connected(_on_hp_changed):
			_bound_stats.hp_changed.disconnect(_on_hp_changed)
		_bound_stats = stats
		if not stats.hp_changed.is_connected(_on_hp_changed):
			stats.hp_changed.connect(_on_hp_changed)

	_on_stats_changed(stats)

func _on_stats_changed(stats: CharacterStats) -> void:
	player_stats = stats
	stat_panel.update_stats(stats, base_stats)

func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if stat_panel:
		stat_panel.update_hp(current_hp, max_hp)
	_refresh_potion_ui()

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
				slot.set_usable(is_usable)
			else:
				slot.set_card({})
				slot.set_cooldown(0)
				slot.set_usable(false)

			slot.set_selected(i == active_index)
	
	# Also update the Cards panel if present
	update_cards_panel(cards)

func update_cards_panel(cards: Array) -> void:
	if card_panel:
		var normalized_cards: Array = []
		for card in cards:
			normalized_cards.append(card if card is Dictionary else {})
		card_panel.refresh(normalized_cards)

func show_card_tooltip(data: Dictionary) -> void:
	if card_tooltip == null:
		return
	card_tooltip.set_card(data)

func hide_card_tooltip() -> void:
	if card_tooltip:
		card_tooltip.visible = false

func _setup_potion() -> void:
	if potion_button and not potion_button.pressed.is_connected(_on_potion_pressed):
		potion_button.pressed.connect(_on_potion_pressed)
	_bind_game_state()
	_refresh_potion_ui()

func _bind_game_state() -> void:
	_game_state_manager = get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if _game_state_manager and not _game_state_manager.state_changed.is_connected(_on_game_state_changed):
		_game_state_manager.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(_new_state: GameStateManager.State, _old_state: GameStateManager.State) -> void:
	_refresh_potion_ui()

func _on_potion_pressed() -> void:
	if _potion_used:
		return
	if not _can_use_potion_now():
		return
	var ps = get_node_or_null("/root/PlayerStats")
	if ps == null or ps.stats == null:
		return
	var stats: CharacterStats = ps.stats
	var heal_amount: int = int(ceil(float(stats.max_hp) * POTION_HEAL_RATIO))
	if heal_amount <= 0:
		return
	stats.heal(heal_amount)
	_potion_used = true
	_refresh_potion_ui()

func _can_use_potion_now() -> bool:
	if _potion_used:
		return false
	if _game_state_manager and not _game_state_manager.is_active():
		return false
	var ps = get_node_or_null("/root/PlayerStats")
	if ps == null or ps.stats == null:
		return false
	var stats: CharacterStats = ps.stats
	return stats.current_hp < stats.max_hp

func _refresh_potion_ui() -> void:
	if potion_button:
		potion_button.disabled = not _can_use_potion_now()
		potion_button.text = "Usar" if not _potion_used else "Usada"
	if potion_count_label:
		potion_count_label.text = "x0" if _potion_used else "x1"
	if potion_icon:
		potion_icon.modulate = Color(1, 1, 1, 1) if not _potion_used else Color(0.5, 0.5, 0.5, 0.8)
	if stat_tooltip:
		stat_tooltip.visible = false

func _setup_stat_tooltips() -> void:
	if stat_tooltip:
		stat_tooltip.visible = false

	var tooltip_map: Dictionary = {
		icon_hp: "HP: Vida actual y máxima; determina la supervivencia.",
		icon_strength: "Fuerza: aumenta el daño físico de cartas y ataques.",
		icon_magic: "Magia: aumenta el daño de cartas y habilidades.",
		icon_dexterity: "Destreza: aumenta la probabilidad de esquivar ataques (2.5% en 1 → 25% en 10).",
		potion_icon: "Poción: restaura una porción de la vida máxima al usarla."
	}

	for icon in tooltip_map.keys():
		if icon == null:
			continue
		var text: String = tooltip_map[icon]
		var enter_cb := _on_stat_icon_entered.bind(text, icon)
		if not icon.mouse_entered.is_connected(enter_cb):
			icon.mouse_entered.connect(enter_cb)
		if not icon.mouse_exited.is_connected(_on_stat_icon_exited):
			icon.mouse_exited.connect(_on_stat_icon_exited)

func _on_stat_icon_entered(text: String, icon: Control) -> void:
	if stat_tooltip == null or stat_tooltip_label == null:
		return
	# Populate and show tooltip
	stat_tooltip_label.text = text
	stat_tooltip.visible = true
	# Position to the right of the stats panel by default
	var panel_rect := stat_panel.get_global_rect()
	var preferred_pos := panel_rect.position + Vector2(panel_rect.size.x + 12.0, 0.0)
	stat_tooltip.global_position = preferred_pos
	# If tooltip intersects the timer UI, flip to the left side of the panel
	if timer_ui:
		var tooltip_rect := stat_tooltip.get_global_rect()
		var timer_rect := timer_ui.get_global_rect()
		if tooltip_rect.intersects(timer_rect):
			var left_pos := panel_rect.position + Vector2(-stat_tooltip.rect_size.x - 12.0, 0.0)
			stat_tooltip.global_position = left_pos

func _on_stat_icon_exited() -> void:
	if stat_tooltip:
		stat_tooltip.visible = false

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
